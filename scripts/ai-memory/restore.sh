#!/usr/bin/env bash
set -euo pipefail
umask 077

# Restore a verified archive into a new Podman volume. Existing volumes are
# never overwritten by this command.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ARCHIVE=''
RESTORE_VOLUME="${AI_MEMORY_RESTORE_VOLUME:-$AI_MEMORY_VOLUME_NAME-restore}"

usage() {
    cat <<'EOF'
Usage: restore.sh --archive FILE [--volume NAME]

The archive must have adjacent .sha256 and .manifest.sha256 sidecars created
by the backup or migration scripts. The target volume must not already exist.
EOF
}

while (($#)); do
    case "$1" in
        --archive)
            (($# >= 2)) || ai_memory_die '--archive requires a value'
            ARCHIVE="$2"
            shift 2
            ;;
        --volume)
            (($# >= 2)) || ai_memory_die '--volume requires a value'
            RESTORE_VOLUME="$2"
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

[[ -n "$ARCHIVE" ]] || { usage >&2; exit 2; }
[[ -f "$ARCHIVE" ]] || ai_memory_die "archive does not exist: $ARCHIVE"
[[ -f "$ARCHIVE.sha256" ]] ||
    ai_memory_die "missing archive checksum: $ARCHIVE.sha256"
[[ -f "$ARCHIVE.manifest.sha256" ]] ||
    ai_memory_die "missing archive manifest: $ARCHIVE.manifest.sha256"

ai_memory_require_commands podman gzip sha256sum tar
podman volume exists "$RESTORE_VOLUME" &&
    ai_memory_die "refusing to overwrite existing volume: $RESTORE_VOLUME"

(cd -- "$(dirname -- "$ARCHIVE")" && sha256sum -c "$(basename -- "$ARCHIVE.sha256")")
gzip -t "$ARCHIVE"
tar -tzf "$ARCHIVE" | grep -E '(^|/)db/memory\.sqlite$' >/dev/null ||
    ai_memory_die 'archive does not contain db/memory.sqlite'

created=0
cleanup_on_error() {
    if ((created)); then
        podman volume rm "$RESTORE_VOLUME" >/dev/null 2>&1 || true
    fi
}
trap cleanup_on_error ERR

podman volume create "$RESTORE_VOLUME" >/dev/null
created=1
printf 'Importing %s into Podman volume %s\n' "$ARCHIVE" "$RESTORE_VOLUME"
podman volume import "$RESTORE_VOLUME" "$ARCHIVE"

target_manifest="$(podman volume export "$RESTORE_VOLUME" \
    | tar -tf - \
    | LC_ALL=C sort \
    | sha256sum \
    | awk '{print $1}')"
source_manifest="$(cat "$ARCHIVE.manifest.sha256")"
if [[ "$target_manifest" != "$source_manifest" ]]; then
    printf 'manifest mismatch after restore\nsource: %s\ntarget: %s\n' \
        "$source_manifest" "$target_manifest" >&2
    exit 1
fi

tar -tzf "$ARCHIVE" | grep -E '(^|/)wiki/' >/dev/null ||
    ai_memory_die 'archive does not contain wiki data'
trap - ERR

printf 'Restore verified in Podman volume %s\n' "$RESTORE_VOLUME"
