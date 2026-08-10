# dotfiles

Declarative Fedora configuration using `chezmoi`, `metapac`, and Bash.

## Bootstrap

The script has not been executed yet. After reviewing the package groups:

```bash
./bootstrap.sh
```

It installs `chezmoi`, Rust through `rustup`, and `metapac` through Cargo,
applies this repository's files, and runs `metapac sync`. It never runs
`metapac clean`.

## Organization

- `dot_config/metapac/`: metapac configuration and package groups.
- `dot_*`: files managed by chezmoi in the home directory.
- `scripts/`: helper scripts that must be run explicitly.
- `.chezmoidata.toml`: values used by machine-specific templates.

The `fedora.toml` group configures Microsoft's official repository through a
hook before installing the `code` RPM package. It also assumes that RPM Fusion
is already configured. The NVIDIA driver is excluded from the initial sync to
avoid installing a machine-specific module without review.

The `ffmpeg-libs` package is not included because it conflicts with
`libswscale-free` on Fedora 44. A complete replacement with RPM Fusion's FFmpeg
should be performed separately with `dnf swap` and `--allowerasing`, after
reviewing the transaction.

VS Code extensions are managed through the GitHub account and are not declared
here. Add Flatpak applications to `desktop.toml` using the official IDs from
the relevant catalog.
