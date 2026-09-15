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
dot_config/ai-memory/env.example
dot_bashrc.local
dot_local/bin/executable_ai-memory-engine
scripts/install-ai-memory-wrapper.sh
scripts/migrate-ai-memory-to-podman.sh
docs/ai-memory-podman.md
```

The generated OpenCode 2 plugin and MCP registration are installed by an
idempotent script using the upstream AI Memory installer. Their generated
runtime copies remain local; the installer command, endpoint, and ownership
are documented here so they can be recreated without committing generated
state or credentials.

## Migration safety

The Docker volume is the source of truth until all Podman checks pass. The
migration must create a backup, copy into a separate Podman volume, compare
the expected data layout, and only then start the Podman service. Removing the
Docker container or volume is deliberately excluded from the initial cutover.

Rollback means stopping the Podman service and restoring the original Docker
deployment against its unchanged `ai-memory-data` volume. The backup archive
must remain available until rollback is no longer required.

## Rebuild order

1. Apply this repository with chezmoi.
2. Install the checksum-verified AI Memory wrapper and create the local env
   file from `env.example` if it does not exist.
3. Create the rootless Podman volume and restore the verified backup.
4. Reload and start the generated Quadlet user service.
5. Verify the loopback endpoint, health, volume persistence, and restart.
6. Generate the OpenCode 2 MCP and plugin integration against port 49375.
7. Restart OpenCode 2 and verify a real hook observation and MCP recall.

## Host prerequisites

The Fedora package group declares `podman` explicitly. Rootless operation uses
cgroups v2 and SELinux labeling. Quadlet files live under
`~/.config/containers/systemd/`, and the generated user service is attached to
`default.target`. Enabling user lingering is a host-level prerequisite when
the service must start and remain available without an active login session.

## Sources

- [AI Memory installation guide](https://github.com/akitaonrails/ai-memory/blob/main/docs/install.md)
- [AI Memory OpenCode 2 integration](https://github.com/akitaonrails/ai-memory/blob/main/docs/install.md#opencode-2-beta)
- [AI Memory support matrix](https://github.com/akitaonrails/ai-memory/blob/main/docs/support-matrix.md)
- [Podman Quadlet documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
