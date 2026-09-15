#!/usr/bin/env bash
set -euo pipefail

# Compatibility-preserving entry point for the explicit Docker-to-Podman
# migration. The implementation remains in the original top-level script.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../migrate-ai-memory-to-podman.sh" "$@"
