#!/usr/bin/env bash
set -euo pipefail

# Dedicated entry point for the explicit OpenCode 2 MCP/plugin installation.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../install-ai-memory-opencode2.sh" "$@"
