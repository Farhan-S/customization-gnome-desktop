#!/usr/bin/env bash
# Applies the dconf/gsettings steps from README.md (palette import, saved
# settings, enabled extensions). Run from this directory after installing
# the extensions listed in enabled-extensions.txt.
set -euo pipefail
cd "$(dirname "$0")"

# ptyxis.dconf pins the Ptyxis profile's custom-command to 'zsh'. Loading it
# before zsh is installed leaves Ptyxis unable to open at all - and with no
# other terminal around, that's a lockout. Install zsh first, every time.
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh not found - installing (ptyxis.dconf requires it to be present before it's loaded)..."
  sudo apt update
  sudo apt install -y zsh
fi

ptyxis --import-palette Pixegami.palette

dconf load /org/gnome/shell/extensions/ < extensions-settings.dconf
dconf load /org/gnome/Ptyxis/ < ptyxis.dconf
dconf load /org/gnome/desktop/interface/ < interface.dconf

gsettings set org.gnome.shell enabled-extensions "$(head -1 enabled-extensions.txt)"

echo "Done. Remaining manual steps: cursor theme, GTK theme, and stylesheet symlinks (see README.md)."
