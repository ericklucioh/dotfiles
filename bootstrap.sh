#!/usr/bin/env bash
set -euo pipefail

# Bootstrap the tools required to apply this repository. This script is safe to
# run more than once, but it intentionally does not run `metapac clean`.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
export PATH="$LOCAL_BIN:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

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

# Enable RPM Fusion before synchronizing Fedora packages.
sudo dnf install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Add Flathub before synchronizing Flatpak applications.
sudo flatpak remote-add --system --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Packages are declared by chezmoi before they are synchronized.
metapac sync

# metapac has no Go backend; TTT is installed using its official Go package.
bash "$REPO_DIR/scripts/install-go-tools.sh"
