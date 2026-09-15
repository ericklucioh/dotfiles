#!/usr/bin/env bash
set -euo pipefail

# Dedicated entry point for installing/updating the upstream AI Memory CLI.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../install-ai-memory.sh" "$@"
