# AI Memory on rootless Podman

AI Memory is a persistent local service, not a development container. This
repository manages its declarative runtime with rootless Podman while Docker
remains available for ordinary development workloads.

## Runtime contract

- Container engine: rootless Podman, managed by the user's systemd/Quadlet
  units.
- Server image: `docker.io/akitaonrails/ai-memory:latest`.
- Persistent data: Podman volume `ai-memory-data`, mounted at `/data`.
- Container listen address: `0.0.0.0:49374` inside the container.
- Host endpoint: `127.0.0.1:49375`.
- OpenCode 2 endpoint: `http://127.0.0.1:49375/mcp`.
- The host port is 49375 because OpenCode 2 owns 49374. The container port
  remains AI Memory's documented default.
- Runtime data, generated logs, wiki content, raw transcripts, databases,
  tokens, and local environment files are never stored in this repository.

## Managed files

The final setup will use these repository paths through chezmoi:

```text
dot_config/containers/systemd/ai-memory.container
dot_config/containers/systemd/ai-memory-data.volume
dot_config/systemd/user/ai-memory-podman.target
dot_config/ai-memory/env.example
dot_bashrc.local
dot_local/bin/executable_ai-memory-engine
scripts/ai-memory/install-wrapper.sh
scripts/ai-memory/migrate-from-docker.sh
scripts/ai-memory/install-opencode2.sh
scripts/ai-memory/backup.sh
scripts/ai-memory/restore.sh
scripts/ai-memory/setup.sh
docs/ai-memory-podman.md
```

The generated OpenCode 2 plugin and MCP registration are installed by an
idempotent script using the upstream AI Memory installer. Their generated
runtime copies remain local; the installer command, endpoint, and ownership
are documented here so they can be recreated without committing generated
state or credentials.

## Operational workflow

`bootstrap.sh` and `chezmoi apply` install files only. They do not start the
service, enable lingering, move data, install the upstream wrapper, or modify
OpenCode. Run these operations explicitly from the repository:

### New host without existing data

```bash
chezmoi apply
scripts/ai-memory/install-wrapper.sh
scripts/ai-memory/setup.sh
scripts/ai-memory/install-opencode2.sh
opencode2 service restart
```

### Host with an existing Docker deployment

Stop the Docker AI Memory container first, leave its volume untouched, and run
the guarded migration. The target Podman volume must not already exist:

```bash
chezmoi apply
scripts/ai-memory/install-wrapper.sh
scripts/ai-memory/migrate-from-docker.sh
scripts/ai-memory/setup.sh
scripts/ai-memory/install-opencode2.sh
opencode2 service restart
```

### Routine operations

```bash
scripts/ai-memory/health.sh
scripts/ai-memory/status.sh
systemctl --user restart ai-memory.service
```

`setup.sh` may be run again after applying Quadlet changes. It is idempotent
and re-establishes the user target, linger, service, and health checks.

## Migration and data safety

The Docker volume is the source of truth until all Podman checks pass. The
migration must create a backup, copy into a separate Podman volume, compare
the expected data layout, and only then start the Podman service. Removing the
Docker container or volume is deliberately excluded from the initial cutover.

Rollback means stopping the Podman service and restoring the original Docker
deployment against its unchanged `ai-memory-data` volume. The backup archive
must remain available until rollback is no longer required.

### Backup

Backups require the service to be stopped so SQLite WAL data is consistent:

```bash
systemctl --user stop ai-memory.service
scripts/ai-memory/backup.sh
scripts/ai-memory/setup.sh
```

The command writes a `.tar.gz` archive plus adjacent archive and file-list
checksums under `~/Backups/ai-memory/` by default.

### Restore

Restore always targets a new volume and refuses to overwrite an existing one:

```bash
scripts/ai-memory/restore.sh \
  --archive ~/Backups/ai-memory/ai-memory-podman-YYYYMMDDTHHMMSSZ.tar.gz \
  --volume ai-memory-restore-review
```

The restored volume is validated but is not silently swapped into production.
Switching production data requires a deliberate service stop, volume review,
and an operator-approved rollback point.

### Rollback to Docker

If the Podman service must be abandoned, stop it and start the preserved Docker
deployment against its original `ai-memory-data` volume. Do not remove the
Podman volume or Docker volume while diagnosing the rollback. After the issue
is resolved, stop Docker and run `scripts/ai-memory/setup.sh` to return to the
Podman service.

## Rebuild order

1. Apply this repository with chezmoi.
2. Install the checksum-verified AI Memory wrapper with
   `scripts/ai-memory/install-wrapper.sh`.
3. Create the rootless Podman volume and restore the verified backup, or run
   the explicit Docker migration command on an existing Docker installation.
4. Run `scripts/ai-memory/setup.sh` to reload and start the Quadlet runtime.
5. Verify the loopback endpoint, health, volume persistence, and restart.
6. Run `scripts/ai-memory/install-opencode2.sh` to generate the OpenCode 2 MCP
   and plugin integration against port 49375.
7. Restart OpenCode 2 and verify a real hook observation and MCP recall.

The repeatable OpenCode 2 wiring command is
`scripts/ai-memory/install-opencode2.sh`. It uses the upstream idempotent
installer, which keeps the V1 and V2 MCP entries compatible and regenerates
`~/.config/opencode/plugins/ai-memory-opencode2.ts` without committing the
generated plugin or any credentials.

## Host prerequisites

The Fedora package group declares `podman` explicitly. Rootless operation uses
cgroups v2 and SELinux labeling. Quadlet files live under
`~/.config/containers/systemd/`. A native user target attaches the generated
service to `default.target`; this avoids trying to enable a generated Quadlet
unit directly. Enabling user lingering is a host-level prerequisite when the
service must start and remain available without an active login session.

## Sources

- [AI Memory installation guide](https://github.com/akitaonrails/ai-memory/blob/main/docs/install.md)
- [AI Memory OpenCode 2 integration](https://github.com/akitaonrails/ai-memory/blob/main/docs/install.md#opencode-2-beta)
- [AI Memory support matrix](https://github.com/akitaonrails/ai-memory/blob/main/docs/support-matrix.md)
- [Podman Quadlet documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
