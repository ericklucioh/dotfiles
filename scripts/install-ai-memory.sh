#!/usr/bin/env bash
set -euo pipefail

# Install the upstream checksum-verified wrapper and prepare the local,
# ignored environment file. The server itself is managed by the Quadlet unit.

readonly LOCAL_BIN="${HOME}/.local/bin"
readonly CONFIG_DIR="${HOME}/.config/ai-memory"
readonly WRAPPER_BASE="https://github.com/akitaonrails/ai-memory/releases/latest/download/ai-memory-wrapper"
readonly TEMP_ROOT="${TMPDIR:-/tmp/opencode}"

command -v curl >/dev/null 2>&1 || { printf 'curl is required\n' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { printf 'sha256sum is required\n' >&2; exit 1; }

mkdir -p "$LOCAL_BIN" "$CONFIG_DIR" "$TEMP_ROOT"
work_dir="$(mktemp -d "${TEMP_ROOT}/ai-memory-install.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

curl -fsSL "$WRAPPER_BASE" -o "$work_dir/ai-memory"
curl -fsSL "$WRAPPER_BASE.sha256" -o "$work_dir/ai-memory.sha256"
(cd "$work_dir" && sha256sum -c ai-memory.sha256)
install -m 0755 "$work_dir/ai-memory" "$LOCAL_BIN/ai-memory"

if [[ ! -e "$CONFIG_DIR/env" ]]; then
    install -m 0600 "$CONFIG_DIR/env.example" "$CONFIG_DIR/env"
fi

printf 'Installed checksum-verified AI Memory wrapper at %s\n' "$LOCAL_BIN/ai-memory"
printf 'Prepared local environment at %s\n' "$CONFIG_DIR/env"
printf 'Podman engine selection is provided by %s\n' "$HOME/.local/bin/ai-memory-engine"
