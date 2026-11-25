#!/usr/bin/env bash
# Re-create the Dolphin-only Pixegami look on a fresh KDE Plasma 6 machine.
# Needs: sudo dnf install kvantum
# Needs the Slot-Dark-Icons pack (https://store.kde.org/p/2234790) extracted to
# ~/.local/share/icons/Slot-Dark-Icons.
set -euo pipefail
D="$HOME/.dotfiles/config/kde"

# Kvantum: Slot-Pixegami theme, applied to Dolphin only (see [Applications])
mkdir -p ~/.config/Kvantum
ln -sfn "$D/Kvantum/Slot-Pixegami" ~/.config/Kvantum/Slot-Pixegami
ln -sfn "$D/Kvantum/kvantum.kvconfig" ~/.config/Kvantum/kvantum.kvconfig
cp -rn "$D/Kvantum/Slot-Dark-Kvantum" ~/.config/Kvantum/ || true

mkdir -p ~/.local/share/color-schemes
ln -sf "$D/color-schemes/Pixegami.colors" ~/.local/share/color-schemes/Pixegami.colors

# Launch Dolphin with the Kvantum style (menu launcher + D-Bus background service)
mkdir -p ~/.local/share/applications ~/.config/systemd/user/plasma-dolphin.service.d
cp "$D/applications/org.kde.dolphin.desktop" ~/.local/share/applications/
cp "$D/systemd/plasma-dolphin-kvantum.conf" ~/.config/systemd/user/plasma-dolphin.service.d/kvantum.conf
systemctl --user daemon-reload

# Icon add-on: colorful Slot icons at sidebar sizes (16/22/24)
SRC="$HOME/.local/share/icons/Slot-Dark-Icons"
O="$HOME/.local/share/icons/Slot-Pixegami-Icons"
if [ -d "$SRC" ]; then
  for sz in 16 22 24; do
    mkdir -p "$O/places/$sz" "$O/devices/$sz"
    for f in "$SRC"/places/32/*.svg "$SRC"/devices/64/*.svg; do
      cat=$(basename "$(dirname "$(dirname "$f")")")
      b=$(basename "$f" .svg); t=$(readlink -f "$f")
      ln -sf "$t" "$O/$cat/$sz/$b.svg"
      case $b in *-symbolic) ;; *) ln -sf "$t" "$O/$cat/$sz/$b-symbolic.svg" ;; esac
    done
    for n in drive-symbolic drive-harddisk-root-symbolic; do
      ln -sf "$(readlink -f "$SRC/devices/64/drive-harddisk-root.svg")" "$O/devices/$sz/$n.svg"
    done
  done
  {
    echo "[Icon Theme]"
    echo "Name=Slot-Pixegami-Icons"
    echo "Comment=Slot Dark with colorful small places icons"
    echo "Inherits=Slot-Dark-Icons,breeze-dark,hicolor"
    echo "Directories=places/16,places/22,places/24,devices/16,devices/22,devices/24"
    echo
    for c in places devices; do for s in 16 22 24; do
      ctx=Places; [ "$c" = devices ] && ctx=Devices
      printf "[%s/%s]\nSize=%s\nContext=%s\nType=Fixed\n\n" "$c" "$s" "$s" "$ctx"
    done; done
  } > "$O/index.theme"
else
  echo "Slot-Dark-Icons not found; skipping icon add-on" >&2
fi

# Dolphin-only settings
kwriteconfig6 --file dolphinrc --group Icons --key Theme Slot-Pixegami-Icons
kwriteconfig6 --file dolphinrc --group PreviewSettings --key Plugins \
  "audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,svgthumbnail,ffmpegthumbs,gsthumbnail"

rm -f ~/.cache/icon-cache.kcache
echo "Done. Restart Dolphin: pkill -x dolphin; systemctl --user restart plasma-dolphin.service"
