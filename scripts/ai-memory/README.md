# AI Memory operations

These commands intentionally live outside `bootstrap.sh`. Applying the
dotfiles installs the declarative Quadlet files; an operator explicitly starts
or changes the AI Memory runtime with these scripts.

## Setup and inspection

From the dotfiles repository:

```bash
scripts/ai-memory/setup.sh
scripts/ai-memory/health.sh
scripts/ai-memory/status.sh
```

`setup.sh` is idempotent. It verifies rootless Podman, creates the ignored
`~/.config/ai-memory/env` file when absent, enables user lingering, reloads
Quadlet, and enables/starts `ai-memory.service`. It only accepts the local
endpoint `http://127.0.0.1:49375`.

Data-moving operations and OpenCode 2 integration have separate entry points:

```bash
scripts/ai-memory/backup.sh
scripts/ai-memory/migrate-from-docker.sh
scripts/ai-memory/restore.sh --archive /path/to/backup.tar.gz
scripts/ai-memory/install-wrapper.sh
scripts/ai-memory/install-opencode2.sh
```

Migration, restore, and integration scripts are explicit and are never called
by `bootstrap.sh`, `chezmoi apply`, or `setup.sh`.
