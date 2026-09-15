#!/usr/bin/env bash
set -euo pipefail
umask 077

# Export the Docker source volume through the published image, then import the
# archive into a separate rootless Podman volume. The source is never removed.

readonly SOURCE_VOLUME="${AI_MEMORY_DOCKER_VOLUME:-ai-memory-data}"
readonly TARGET_VOLUME="${AI_MEMORY_PODMAN_VOLUME:-ai-memory-data}"
readonly IMAGE="${AI_MEMORY_IMAGE:-docker.io/akitaonrails/ai-memory:latest}"
readonly BACKUP_DIR="${AI_MEMORY_BACKUP_DIR:-${HOME}/Backups/ai-memory}"
readonly TEMP_ROOT="${TMPDIR:-/tmp/opencode}"

command -v docker >/dev/null 2>&1 || { printf 'docker is required for the source export\n' >&2; exit 1; }
command -v podman >/dev/null 2>&1 || { printf 'podman is required for the target import\n' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { printf 'sha256sum is required\n' >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { printf 'tar is required\n' >&2; exit 1; }

docker volume inspect "$SOURCE_VOLUME" >/dev/null
if [[ -n "$(docker ps --filter 'name=^/ai-memory$' --format '{{.Names}}')" ]]; then
    printf 'The Docker ai-memory container is running; stop it before exporting for consistency.\n' >&2
    exit 1
fi

if podman volume exists "$TARGET_VOLUME"; then
    printf 'Refusing to overwrite existing Podman volume: %s\n' "$TARGET_VOLUME" >&2
    printf 'Choose another AI_MEMORY_PODMAN_VOLUME or remove it only after inspection.\n' >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR" "$TEMP_ROOT"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="${BACKUP_DIR}/ai-memory-docker-${timestamp}.tar.gz"
manifest="${archive}.manifest.sha256"
checksum="${archive}.sha256"

printf 'Exporting Docker volume %s to %s\n' "$SOURCE_VOLUME" "$archive"
docker run --rm \
    --entrypoint /bin/sh \
    --volume "${SOURCE_VOLUME}:/data:ro" \
    "$IMAGE" \
    -c 'tar -C /data -czf - .' >"$archive"

[[ -s "$archive" ]]
gzip -t "$archive"
if ! tar -tzf "$archive" | grep -Eq '(^|/)db/memory\.sqlite$'; then
    printf 'Backup does not contain db/memory.sqlite; refusing import.\n' >&2
    exit 1
fi

tar -tzf "$archive" | LC_ALL=C sort | sha256sum | awk '{print $1}' >"$manifest"
sha256sum "$archive" >"$checksum"

podman volume create "$TARGET_VOLUME" >/dev/null
printf 'Importing backup into rootless Podman volume %s\n' "$TARGET_VOLUME"
podman volume import "$TARGET_VOLUME" "$archive"

target_manifest="$({
    podman run --rm \
        --entrypoint /bin/sh \
        --volume "${TARGET_VOLUME}:/data:ro" \
        "$IMAGE" \
        -c 'tar -C /data -czf - .' \
        | tar -tzf - \
        | LC_ALL=C sort \
        | sha256sum \
        | awk '{print $1}';
})"
source_manifest="$(cat "$manifest")"
if [[ "$target_manifest" != "$source_manifest" ]]; then
    printf 'Manifest mismatch after import; source volume remains untouched.\n' >&2
    printf 'Source: %s\nTarget: %s\n' "$source_manifest" "$target_manifest" >&2
    exit 1
fi

podman run --rm \
    --entrypoint /bin/sh \
    --volume "${TARGET_VOLUME}:/data:ro" \
    "$IMAGE" \
    -c 'test -d /data/wiki && test -d /data/db && test -f /data/db/memory.sqlite && test -d /data/logs'

printf 'Migration verified.\n'
printf 'Archive: %s\n' "$archive"
printf 'Archive checksum: %s\n' "$checksum"
printf 'Manifest checksum: %s\n' "$manifest"
printf 'Podman volume: %s\n' "$TARGET_VOLUME"
printf 'The Docker source volume was not changed or removed.\n'
