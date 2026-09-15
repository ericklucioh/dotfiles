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

### Vocalinux

O bootstrap instala o Vocalinux `v0.16.2` usando o engine local `whisper.cpp`.
No Fedora, o grupo de pacotes declara o driver NVIDIA via RPM Fusion, toolkit
CUDA e GCC 15 para compilar o backend da RTX sem substituir o compilador padrão
do sistema. Após a primeira instalação do driver, reinicie o sistema para o
módulo `akmod-nvidia` ser carregado. O script baixa o
instalador oficial e o modelo `large-v3-turbo-q5_0` com SHA-256 fixado; os
binários e modelos ficam em `~/.local/share/vocalinux`, nunca no repositório.

Após `./bootstrap.sh`, o app fica configurado para:

- reconhecer português (`pt`);
- usar `large-v3-turbo-q5_0`;
- alternar gravação com dois toques no Ctrl esquerdo;
- iniciar minimizado no login;
- preservar configurações locais de áudio ao reaplicar Chezmoi.

Para aplicar somente a parte do Vocalinux depois de uma atualização:

```bash
bash scripts/install-vocalinux.sh
chezmoi apply
```

Verificações sem gravar áudio:

```bash
vocalinux --version
cat ~/.config/vocalinux/config.json | jq '{speech_recognition, shortcuts, general}'
nvidia-smi
```

O processo do Vocalinux deve aparecer em `nvidia-smi` usando memória da GPU.
Se `large-v3-turbo-q5_0` ficar lento, troque `model_size` e
`whisper_cpp_model_size` para `medium-q5_0` em
`scripts/vocalinux-config.defaults.json` e rode o script novamente.

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

## Persistent AI Memory

AI Memory is intentionally isolated from development containers: its
persistent service runs under rootless Podman, while Docker remains available
for development. The reproducible runtime, migration, backup, rollback, and
OpenCode 2 integration are documented in
[`docs/ai-memory-podman.md`](docs/ai-memory-podman.md).

Applying the dotfiles only installs the declarative runtime files. It does not
start AI Memory, enable user lingering, migrate data, or change OpenCode. Run
the explicit operations from `scripts/ai-memory/` when the host is ready:

```bash
scripts/ai-memory/install-wrapper.sh
scripts/ai-memory/setup.sh
scripts/ai-memory/install-opencode2.sh
```

See [`scripts/ai-memory/README.md`](scripts/ai-memory/README.md) for backup,
restore, migration, health, status, and rollback procedures.

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
