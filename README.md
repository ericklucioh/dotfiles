# dotfiles

Declarative Fedora configuration using `chezmoi`, `metapac`, and Bash.

## Bootstrap

The script has already been executed on this machine (RPM Fusion, Flathub,
and Docker are configured). To reproduce the setup on a new machine:

```bash
./bootstrap.sh
```

Depois da instalação inicial, para aplicar alterações:

```bash
chezmoi apply
metapac sync
```

It installs `chezmoi`, Rust through `rustup`, and `metapac` through Cargo,
applies this repository's files, and runs `metapac sync`. It never runs
`metapac clean`.

## Organization

- `dot_config/metapac/`: metapac configuration and package groups.
- `dot_*`: files managed by chezmoi in the home directory.
- `scripts/`: helper scripts that must be run explicitly.
- `.chezmoidata.toml`: values used by machine-specific templates.

The `opencode` and `codex` CLI tools are installed through npm. TTT is
installed through Go because metapac does not currently provide a Go backend.

The `fedora.toml` group configures Microsoft's official repository through a
hook before installing the `code` RPM package. It also assumes that RPM Fusion
is already configured. The NVIDIA driver is excluded from the initial sync to
avoid installing a machine-specific module without review.

The same group configures Docker's official Fedora repository and installs
Docker Engine, Buildx, and Compose. Its `after_install` hook enables and starts
the Docker service. To run Docker without `sudo`, add the current user to the
Docker group and start a new login session:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker run hello-world
docker compose version
```

The Fedora group also installs PostgreSQL and MySQL, but neither database
service is enabled or started automatically.

## Links

- Metapac oficial: <https://github.com/ripytide/metapac>
- Meu fork: <https://github.com/ericklucioh/dotfiles>
- Repositório oficial do Docker para Fedora: <https://download.docker.com/linux/fedora/docker-ce.repo>
- Documentação oficial de instalação do Docker: <https://docs.docker.com/engine/install/fedora/>

The `ffmpeg-libs` package is not included because it conflicts with
`libswscale-free` on Fedora 44. A complete replacement with RPM Fusion's FFmpeg
should be performed separately with `dnf swap` and `--allowerasing`, after
reviewing the transaction.

VS Code extensions are managed through the GitHub account and are not declared
here. Add Flatpak applications to `desktop.toml` using the official IDs from
the relevant catalog.
