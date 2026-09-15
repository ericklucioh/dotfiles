#!/usr/bin/env bash
set -euo pipefail

# Recreate the OpenCode 2 MCP entry and generated plugin against the local
# Podman-backed AI Memory service. The upstream installer preserves unrelated
# OpenCode configuration and creates timestamped backups.

readonly SERVER_URL="${AI_MEMORY_SERVER_URL:-http://127.0.0.1:49375}"

command -v ai-memory >/dev/null 2>&1 || {
    printf 'ai-memory is not on PATH; run scripts/install-ai-memory.sh first\n' >&2
    exit 1
}

export AI_MEMORY_SERVER_URL="${SERVER_URL%/}"
export AI_MEMORY_DOCKER="${AI_MEMORY_DOCKER:-$HOME/.local/bin/ai-memory-engine}"
export AI_MEMORY_NO_VERSION_CHECK=1

ai-memory install-mcp \
    --client opencode2 \
    --server-url "${AI_MEMORY_SERVER_URL}/mcp" \
    --apply

ai-memory install-hooks \
    --agent opencode2 \
    --server-url "$AI_MEMORY_SERVER_URL" \
    --apply

printf 'OpenCode 2 AI Memory integration installed for %s\n' "$AI_MEMORY_SERVER_URL"
printf 'Restart opencode2 to load the generated plugin.\n'
