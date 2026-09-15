#!/usr/bin/env bash

# Shared paths and safety checks for the explicit AI Memory operations.

AI_MEMORY_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_MEMORY_REPO_DIR="$(cd -- "$AI_MEMORY_SCRIPT_DIR/../.." && pwd)"
AI_MEMORY_SERVER_URL="${AI_MEMORY_SERVER_URL:-http://127.0.0.1:49375}"
AI_MEMORY_SERVICE_NAME="${AI_MEMORY_SERVICE_NAME:-ai-memory.service}"
AI_MEMORY_TARGET_NAME="${AI_MEMORY_TARGET_NAME:-ai-memory-podman.target}"
AI_MEMORY_CONTAINER_NAME="${AI_MEMORY_CONTAINER_NAME:-ai-memory}"
AI_MEMORY_VOLUME_NAME="${AI_MEMORY_VOLUME_NAME:-ai-memory-data}"
AI_MEMORY_ENV_FILE="${AI_MEMORY_ENV_FILE:-$HOME/.config/ai-memory/env}"
AI_MEMORY_QUADLET_DIR="${AI_MEMORY_QUADLET_DIR:-$HOME/.config/containers/systemd}"

ai_memory_die() {
    printf 'ai-memory: %s\n' "$*" >&2
    exit 1
}

ai_memory_require_commands() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 ||
            ai_memory_die "required command not found: $command_name"
    done
}

ai_memory_require_local_endpoint() {
    [[ "$AI_MEMORY_SERVER_URL" == 'http://127.0.0.1:49375' ]] ||
        ai_memory_die "refusing non-local AI Memory endpoint: $AI_MEMORY_SERVER_URL"
}

ai_memory_require_rootless_podman() {
    local rootless
    rootless="$(podman info --format '{{.Host.Security.Rootless}}')" ||
        ai_memory_die 'unable to inspect Podman'
    [[ "$rootless" == 'true' ]] ||
        ai_memory_die 'Podman is not running rootless; refusing to manage the service'
}

ai_memory_require_quadlet_files() {
    [[ -f "$AI_MEMORY_QUADLET_DIR/ai-memory.container" ]] ||
        ai_memory_die "missing $AI_MEMORY_QUADLET_DIR/ai-memory.container; apply dotfiles first"
    [[ -f "$AI_MEMORY_QUADLET_DIR/ai-memory-data.volume" ]] ||
        ai_memory_die "missing $AI_MEMORY_QUADLET_DIR/ai-memory-data.volume; apply dotfiles first"
    [[ -f "$HOME/.config/systemd/user/$AI_MEMORY_TARGET_NAME" ]] ||
        ai_memory_die "missing ~/.config/systemd/user/$AI_MEMORY_TARGET_NAME; apply dotfiles first"
}

ai_memory_ensure_env_file() {
    local template="$AI_MEMORY_REPO_DIR/dot_config/ai-memory/env.example"
    if [[ ! -e "$AI_MEMORY_ENV_FILE" ]]; then
        [[ -f "$template" ]] || ai_memory_die "missing environment template: $template"
        install -D -m 0600 "$template" "$AI_MEMORY_ENV_FILE"
        printf 'Created %s\n' "$AI_MEMORY_ENV_FILE"
    else
        chmod 0600 "$AI_MEMORY_ENV_FILE"
    fi
}

ai_memory_wait_for_healthy() {
    local attempt health http_code
    for attempt in $(seq 1 60); do
        if systemctl --user is-active --quiet "$AI_MEMORY_SERVICE_NAME"; then
            health="$(podman inspect "$AI_MEMORY_CONTAINER_NAME" \
                --format '{{.State.Health.Status}}' 2>/dev/null || true)"
            http_code="$(curl -sS -o /dev/null -w '%{http_code}' \
                --max-time 3 "$AI_MEMORY_SERVER_URL/mcp" 2>/dev/null || true)"
            if [[ "$health" == 'healthy' && "$http_code" == '405' ]]; then
                return 0
            fi
        fi
        sleep 1
    done

    systemctl --user --no-pager --full status "$AI_MEMORY_SERVICE_NAME" >&2 || true
    podman logs --tail 40 "$AI_MEMORY_CONTAINER_NAME" >&2 || true
    ai_memory_die "service did not become healthy at $AI_MEMORY_SERVER_URL"
}
