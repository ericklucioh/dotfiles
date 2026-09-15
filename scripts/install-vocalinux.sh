#!/usr/bin/env bash
set -euo pipefail

# Install a pinned Vocalinux release and its verified Portuguese model.
# This script is intentionally separate from metapac: the application installer
# builds pywhispercpp against the locally installed CUDA toolkit.

readonly VOCALINUX_TAG="v0.16.2"
readonly INSTALLER_URL="https://raw.githubusercontent.com/VocaHQ/vocalinux/${VOCALINUX_TAG}/install.sh"
readonly INSTALLER_SHA256="91f3f883b05e0555cf045f40873e107c6825d17c2af4649465e4e742fa467dd9"
readonly MODEL_REVISION="5359861c739e955e79d9a303bcbc70fb988958b1"
readonly MODEL_NAME="large-v3-turbo-q5_0"
readonly MODEL_SHA256="394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2"
readonly MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/${MODEL_REVISION}/ggml-${MODEL_NAME}.bin"
readonly PYWHISPERCPP_VERSION="1.5.0"
readonly CUDA_ROOT="/usr/local/cuda"
readonly CUDA_ARCHITECTURE="86-real"

readonly DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vocalinux"
readonly MODEL_DIR="${DATA_DIR}/models/whispercpp"
readonly MODEL_FILE="${MODEL_DIR}/ggml-${MODEL_NAME}.bin"
readonly CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/vocalinux/config.json"
readonly DEFAULTS_FILE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/vocalinux-config.defaults.json"

export PATH="/usr/local/cuda/bin:$PATH"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing command '$1'; run ./bootstrap.sh first"
}

venv_python() {
    printf '%s\n' "$HOME/.local/share/vocalinux/venv/bin/python"
}

cuda_backend_installed() {
    local site_packages
    [[ -x "$(venv_python)" ]] || return 1
    site_packages=$("$(venv_python)" -c 'import sysconfig; print(sysconfig.get_path("platlib"))')
    find "$site_packages" -maxdepth 3 -type f -name 'libggml-cuda.so*' -print -quit 2>/dev/null | grep -q .
}

validate_cuda_toolkit() {
    require_command nvidia-smi
    require_command nvcc
    local smi_output
    smi_output=$(nvidia-smi 2>&1) || die "NVIDIA driver is installed but nvidia-smi cannot access the GPU"
    grep -q 'ERR!' <<<"$smi_output" \
        && die "NVIDIA driver reports a GPU error; reboot before building the CUDA backend"
    [[ -x "$CUDA_ROOT/bin/nvcc" ]] || die "CUDA compiler is missing at $CUDA_ROOT/bin/nvcc"
    [[ -f "$CUDA_ROOT/targets/x86_64-linux/include/cuda_runtime.h" ]] \
        || die "CUDA headers are missing under $CUDA_ROOT"
    compgen -G "$CUDA_ROOT/targets/x86_64-linux/lib/libcudart.so*" >/dev/null \
        || die "CUDA runtime library is missing under $CUDA_ROOT"
}

verify_file() {
    local expected="$1"
    local file="$2"
    printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status - \
        || die "checksum verification failed for $file"
}

install_vocalinux() {
    local installed_version=""
    if [[ -x "$HOME/.local/share/vocalinux/venv/bin/vocalinux" ]]; then
        installed_version=$("$HOME/.local/share/vocalinux/venv/bin/vocalinux" --version 2>/dev/null || true)
    fi
    if [[ "$installed_version" == "$VOCALINUX_TAG" || "$installed_version" == "${VOCALINUX_TAG#v}" ]]; then
        printf 'Vocalinux %s is already installed; keeping the application and repairing only its CUDA backend.\n' \
            "$VOCALINUX_TAG"
        return
    fi

    [[ -f /etc/fedora-release ]] || die "this integration currently supports Fedora only"
    require_command curl
    require_command sha256sum
    require_command gcc-15
    require_command g++-15
    validate_cuda_toolkit

    local installer
    installer=$(mktemp /tmp/vocalinux-install.XXXXXX.sh)
    curl --fail --location --retry 3 --silent --show-error "$INSTALLER_URL" -o "$installer"
    verify_file "$INSTALLER_SHA256" "$installer"

    PATH="/usr/local/cuda/bin:$PATH" \
        CC=/usr/bin/gcc-15 \
        CXX=/usr/bin/g++-15 \
        CUDAHOSTCXX=/usr/bin/g++-15 \
        CUDAToolkit_ROOT="$CUDA_ROOT" \
        bash "$installer" --auto --engine=whisper_cpp --rebuild-whispercpp \
            --skip-system-deps --tag="$VOCALINUX_TAG"
    rm -f -- "$installer"
}

install_cuda_backend() {
    validate_cuda_toolkit
    if cuda_backend_installed; then
        printf 'CUDA backend is already present in pywhispercpp; reusing it.\n'
        return
    fi
    local python build_root source_archive source_root
    python=$(venv_python)
    [[ -x "$python" ]] || die "Vocalinux virtual environment is missing: $python"
    build_root=$(mktemp -d /tmp/pywhispercpp-cuda.XXXXXX)
    "$python" -m pip download --no-binary=pywhispercpp --no-deps \
        "pywhispercpp==${PYWHISPERCPP_VERSION}" --dest "$build_root" >/dev/null
    source_archive=$(find "$build_root" -maxdepth 1 -type f -name 'pywhispercpp-*' -print -quit)
    [[ -n "$source_archive" ]] || die "pywhispercpp source archive was not downloaded"
    tar -xf "$source_archive" -C "$build_root"
    source_root=$(find "$build_root" -mindepth 1 -maxdepth 1 -type d -name 'pywhispercpp-*' -print -quit)
    [[ -n "$source_root" ]] || die "pywhispercpp source directory was not extracted"

    # Backport ggml's iterator compatibility fix and include the CUDA iterator API.
    (
        cd "$source_root"
        argsort=whisper.cpp/ggml/src/ggml-cuda/argsort.cu
        if ! grep -q 'STRIDED_ITERATOR_AVAILABLE' "$argsort"; then
            perl -0pi -e 's/(#    include <cub\/cub\.cuh>\n)/$1#    if (CCCL_MAJOR_VERSION >= 3 \&\& CCCL_MINOR_VERSION >= 1)\n#        define STRIDED_ITERATOR_AVAILABLE\n#    endif\n/' "$argsort"
            perl -0pi -e 's/(static __global__ void init_indices\b.*?\n\})\n\n(#ifdef GGML_CUDA_USE_CUB)/$1\n\n#ifndef STRIDED_ITERATOR_AVAILABLE\nstatic __global__ void init_offsets(int * offsets, const int ncols, const int nrows) {\n    const int idx = blockIdx.x * blockDim.x + threadIdx.x;\n    if (idx <= nrows) {\n        offsets[idx] = idx * ncols;\n    }\n}\n#endif  \/\/ STRIDED_ITERATOR_AVAILABLE\n\n$2/s' "$argsort"
            perl -0pi -e 's/\n    auto offset_iterator = cuda::make_strided_iterator\(cuda::make_counting_iterator\(0\), ncols\);\n/\n#    ifdef STRIDED_ITERATOR_AVAILABLE\n    auto offset_iterator = cuda::make_strided_iterator(cuda::make_counting_iterator(0), ncols);\n#    else\n    ggml_cuda_pool_alloc<int> offsets_alloc(pool, nrows + 1);\n    int *                     offset_iterator = offsets_alloc.get();\n    const dim3                offset_grid((nrows + block_size - 1) \/ block_size);\n    init_offsets<<<offset_grid, block_size, 0, stream>>>(offset_iterator, ncols, nrows);\n#    endif\n/' "$argsort"
        fi
        if grep -q 'STRIDED_ITERATOR_AVAILABLE' "$argsort" \
            && ! grep -q '#        include <cuda/iterator>' "$argsort"; then
            perl -0pi -e 's/(#        define STRIDED_ITERATOR_AVAILABLE\n)/$1#        include <cuda\/iterator>\n/' "$argsort"
        fi
        grep -q 'STRIDED_ITERATOR_AVAILABLE' "$argsort" || exit 1
        grep -q '#        include <cuda/iterator>' "$argsort" || exit 1

        topk=whisper.cpp/ggml/src/ggml-cuda/top-k.cu
        if grep -q 'cuda::make_' "$topk" \
            && ! grep -q '#        include <cuda/iterator>' "$topk"; then
            perl -0pi -e 's/(#    include <cub\/cub\.cuh>\n)/$1#        include <cuda\/iterator>\n/' "$topk"
        fi
        grep -q '#        include <cuda/iterator>' "$topk" || exit 1
    ) || die "failed to patch pywhispercpp ggml CUDA source"

    printf 'Building pywhispercpp %s with CUDA architecture %s.\n' \
        "$PYWHISPERCPP_VERSION" "$CUDA_ARCHITECTURE"
    PYTHONNOUSERSITE=1 \
        CC=/usr/bin/gcc-15 \
        CXX=/usr/bin/g++-15 \
        CUDAHOSTCXX=/usr/bin/g++-15 \
        CMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-15 \
        CUDAToolkit_ROOT="$CUDA_ROOT" \
        CMAKE_ARGS="-DGGML_CUDA=ON -DCUDAToolkit_ROOT=$CUDA_ROOT -DCMAKE_CUDA_COMPILER=$CUDA_ROOT/bin/nvcc -DCMAKE_CUDA_ARCHITECTURES=$CUDA_ARCHITECTURE -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-15" \
        GGML_CUDA=1 \
        NO_REPAIR=1 \
        "$python" -m pip install --force-reinstall --no-cache-dir \
            "$source_root" \
            --verbose

    rm -rf -- "$build_root"

    cuda_backend_installed \
        || die "pywhispercpp build completed without libggml-cuda.so; refusing CPU fallback"
    printf 'CUDA backend verified in pywhispercpp.\n'
}

install_model() {
    require_command curl
    require_command sha256sum
    mkdir -p "$MODEL_DIR"

    if [[ -f "$MODEL_FILE" ]]; then
        if printf '%s  %s\n' "$MODEL_SHA256" "$MODEL_FILE" | sha256sum --check --status -; then
            printf 'Model %s is already present and verified.\n' "$MODEL_NAME"
            return
        fi
        mv -- "$MODEL_FILE" "${MODEL_FILE}.invalid.$(date +%s)"
    fi

    local temporary_model
    temporary_model=$(mktemp "${MODEL_DIR}/.${MODEL_NAME}.XXXXXX")
    curl --fail --location --retry 3 --silent --show-error "$MODEL_URL" -o "$temporary_model"
    verify_file "$MODEL_SHA256" "$temporary_model"
    chmod 0644 "$temporary_model"
    mv -- "$temporary_model" "$MODEL_FILE"
    printf 'Installed and verified model %s.\n' "$MODEL_NAME"
}

apply_config_defaults() {
    require_command jq
    [[ -f "$DEFAULTS_FILE" ]] || die "missing managed defaults file: $DEFAULTS_FILE"
    jq empty "$DEFAULTS_FILE" || die "invalid managed Vocalinux defaults"

    local config_dir temporary_config
    config_dir=$(dirname -- "$CONFIG_FILE")
    mkdir -p "$config_dir"
    if [[ -f "$CONFIG_FILE" ]]; then
        jq empty "$CONFIG_FILE" || die "existing Vocalinux config is invalid: $CONFIG_FILE"
    else
        printf '{}\n' >"$CONFIG_FILE"
    fi

    temporary_config=$(mktemp "${config_dir}/.config.json.XXXXXX")
    jq -s '
        .[0] as $existing | .[1] as $defaults |
        $existing
        | .speech_recognition = ((.speech_recognition // {}) * $defaults.speech_recognition)
        | .shortcuts = ((.shortcuts // {}) * $defaults.shortcuts)
        | .ui = ((.ui // {}) * $defaults.ui)
        | .general = ((.general // {}) * $defaults.general)
    ' "$CONFIG_FILE" "$DEFAULTS_FILE" >"$temporary_config"
    chmod 0600 "$temporary_config"
    mv -- "$temporary_config" "$CONFIG_FILE"
}

main() {
    install_vocalinux
    install_cuda_backend
    install_model
    apply_config_defaults
    printf 'Vocalinux %s is installed for Portuguese with %s and double Left Ctrl toggle.\n' \
        "$VOCALINUX_TAG" "$MODEL_NAME"
}

main "$@"
