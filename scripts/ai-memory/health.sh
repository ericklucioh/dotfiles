#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ai_memory_require_commands podman systemctl curl
ai_memory_require_local_endpoint
ai_memory_wait_for_healthy

health="$(podman inspect "$AI_MEMORY_CONTAINER_NAME" \
    --format '{{.State.Health.Status}}')"
printf 'service: active\ncontainer: %s\nendpoint: %s\n' \
    "$health" "$AI_MEMORY_SERVER_URL"
