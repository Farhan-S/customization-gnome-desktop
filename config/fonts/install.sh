#!/usr/bin/env bash
# Installs the fonts referenced by name in this repo's configs but never
# tracked here (binary files, not config). Referencing a font by name in
# dconf/settings.json doesn't install it - GNOME, Ptyxis and VS Code all
# silently fall back to a default font when the named one is missing, so
# this has gone unnoticed before (see git history for the Fira Code
# iScript case). Safe to re-run: each font is skipped if already present.
set -euo pipefail

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

have_font() { fc-list | grep -qi "$1"; }

# GNOME's default UI font - config/gnome/interface.dconf font-name
if ! dpkg -s fonts-comfortaa >/dev/null 2>&1; then
  echo "Installing Comfortaa (apt)..."
  sudo apt update
  sudo apt install -y fonts-comfortaa
fi

# Ptyxis terminal font - config/gnome/ptyxis.dconf font-name
if ! have_font "MesloLGS NF"; then
  echo "Installing MesloLGS NF..."
  base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  for variant in Regular Bold Italic "Bold%20Italic"; do
    name="${variant/\%20/ }"
    curl -fLo "$FONT_DIR/MesloLGS NF $name.ttf" "$base/MesloLGS%20NF%20$variant.ttf"
  done
fi

# GNOME's monospace font and VS Code's editor font - config/gnome/interface.dconf
# monospace-font-name, config/Code/User/settings.json editor.fontFamily
if ! have_font "Fira Code iScript"; then
  echo "Installing Fira Code iScript..."
  base="https://raw.githubusercontent.com/kencrocken/FiraCodeiScript/master"
  for style in Regular Bold Italic; do
    curl -fLo "$FONT_DIR/FiraCodeiScript-$style.ttf" "$base/FiraCodeiScript-$style.ttf"
  done
fi

# Ptyxis/VS Code fallback fonts - config/gnome/ptyxis.dconf and
# config/Code/User/settings.json fontFamily lists
install_nerd_font() {
  local family="$1" zip="$2"
  have_font "$family" && return
  echo "Installing $family (Nerd Fonts)..."
  if ! command -v unzip >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y unzip
  fi
  local version tmp
  version=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    | grep -Po '"tag_name":\s*"\K[^"]+')
  tmp=$(mktemp -d)
  curl -fLo "$tmp/$zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/$version/$zip"
  unzip -oq "$tmp/$zip" -d "$FONT_DIR" '*Mono*.ttf'
  rm -rf "$tmp"
}
install_nerd_font "FiraCode Nerd Font Mono" "FiraCode.zip"
install_nerd_font "JetBrainsMono Nerd Font" "JetBrainsMono.zip"

fc-cache -f "$FONT_DIR" >/dev/null
echo "Done. Fonts installed to $FONT_DIR"
