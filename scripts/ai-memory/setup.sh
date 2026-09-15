#!/usr/bin/env bash
set -euo pipefail

# Explicitly configure and start the already-declared rootless Podman service.
# This script is intentionally not called by bootstrap.sh or chezmoi hooks.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ai_memory_require_commands podman systemctl loginctl curl install
ai_memory_require_local_endpoint
ai_memory_require_rootless_podman
ai_memory_require_quadlet_files
ai_memory_ensure_env_file

loginctl enable-linger "${USER:?USER must be set for rootless service setup}"
systemctl --user daemon-reload
systemctl --user enable --now "$AI_MEMORY_TARGET_NAME"
ai_memory_wait_for_healthy

printf 'AI Memory is running through rootless Podman at %s\n' "$AI_MEMORY_SERVER_URL"
