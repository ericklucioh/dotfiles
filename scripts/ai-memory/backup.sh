#!/usr/bin/env bash
set -euo pipefail
umask 077

# Create a consistent archive of a stopped Podman volume. The archive and both
# checksums stay outside the repository by default.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

BACKUP_VOLUME="${AI_MEMORY_BACKUP_VOLUME:-$AI_MEMORY_VOLUME_NAME}"
BACKUP_DIR="${AI_MEMORY_BACKUP_DIR:-$HOME/Backups/ai-memory}"

usage() {
    cat <<'EOF'
Usage: backup.sh [--volume NAME] [--output-dir DIR]

The service must be stopped so SQLite WAL data is captured consistently.
EOF
}

while (($#)); do
    case "$1" in
        --volume)
            (($# >= 2)) || ai_memory_die '--volume requires a value'
            BACKUP_VOLUME="$2"
            shift 2
            ;;
        --output-dir)
            (($# >= 2)) || ai_memory_die '--output-dir requires a value'
            BACKUP_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            ai_memory_die "unknown argument: $1"
            ;;
    esac
done

ai_memory_require_commands podman systemctl gzip tar sha256sum
podman volume inspect "$BACKUP_VOLUME" >/dev/null ||
    ai_memory_die "Podman volume does not exist: $BACKUP_VOLUME"

if systemctl --user is-active --quiet "$AI_MEMORY_SERVICE_NAME" 2>/dev/null; then
    ai_memory_die "stop $AI_MEMORY_SERVICE_NAME before creating a consistent backup"
fi

mkdir -p "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$BACKUP_DIR/ai-memory-podman-${timestamp}.tar.gz"
checksum="$archive.sha256"
manifest="$archive.manifest.sha256"

printf 'Exporting Podman volume %s to %s\n' "$BACKUP_VOLUME" "$archive"
podman volume export "$BACKUP_VOLUME" | gzip -n >"$archive"
[[ -s "$archive" ]]
gzip -t "$archive"
tar -tzf "$archive" | grep -E '(^|/)db/memory\.sqlite$' >/dev/null ||
    ai_memory_die 'backup does not contain db/memory.sqlite'

tar -tzf "$archive" | LC_ALL=C sort | sha256sum | awk '{print $1}' >"$manifest"
sha256sum "$archive" >"$checksum"

printf 'Archive: %s\nChecksum: %s\nManifest: %s\n' \
    "$archive" "$checksum" "$manifest"
