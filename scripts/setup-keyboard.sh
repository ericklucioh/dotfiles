#!/usr/bin/env bash
set -euo pipefail

localectl set-keymap us-intl
localectl set-x11-keymap us pc105 intl

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl')]"
    gsettings set org.gnome.desktop.input-sources current 0
fi

printf '%s\n' 'Keyboard configured. Log out and back in to load XCompose.'
