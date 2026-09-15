#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ai_memory_require_commands podman systemctl

printf '%s\n' '--- systemd ---'
systemctl --user --no-pager --full status "$AI_MEMORY_SERVICE_NAME" || true
printf '\n%s\n' '--- container ---'
podman inspect "$AI_MEMORY_CONTAINER_NAME" \
    --format 'name={{.Name}} status={{.State.Status}} health={{.State.Health.Status}}' \
    2>/dev/null || printf 'container is not present\n'

if command -v ai-memory >/dev/null 2>&1; then
    printf '\n%s\n' '--- AI Memory ---'
    AI_MEMORY_DOCKER="${AI_MEMORY_DOCKER:-$HOME/.local/bin/ai-memory-engine}" \
        AI_MEMORY_SERVER_URL="$AI_MEMORY_SERVER_URL" \
        AI_MEMORY_NO_VERSION_CHECK=1 \
        ai-memory status
fi
