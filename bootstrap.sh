#!/usr/bin/env bash
set -euo pipefail

# Bootstrap the tools required to apply this repository. This script is safe to
# run more than once, but it intentionally does not run `metapac clean`.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
export PATH="$LOCAL_BIN:$HOME/.cargo/bin:$PATH"

mkdir -p "$LOCAL_BIN"

if ! command -v chezmoi >/dev/null 2>&1; then
    curl -fsSL https://get.chezmoi.io | sh -s -- -b "$LOCAL_BIN"
fi

if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# rustup writes its environment setup to this file.
source "$HOME/.cargo/env"

if ! command -v metapac >/dev/null 2>&1; then
    cargo install metapac --locked
fi

chezmoi --source "$REPO_DIR" init --guess-repo-url=false
chezmoi --source "$REPO_DIR" apply

# Packages are declared by chezmoi before they are synchronized.
metapac sync
