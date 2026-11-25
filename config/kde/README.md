# KDE Plasma 6

## Dolphin: Pixegami look (Dolphin only)

- `Kvantum/Slot-Pixegami/`: Slot Dark Kvantum (https://store.kde.org/p/2234799)
  recolored to the Pixegami palette (navy `#0C1C25`, mint `#86FFAF`), solid
  window, dark-teal selection, mint usage bars.
- `Kvantum/kvantum.kvconfig`: default Kvantum theme stays Orchis; only
  `dolphin` gets `Slot-Pixegami` via `[Applications]`.
- `applications/org.kde.dolphin.desktop`: launcher with `-style kvantum`.
- `systemd/plasma-dolphin-kvantum.conf`: same for the background Dolphin
  service other apps use to "open folder".
- `color-schemes/Pixegami.colors`: Plasma color scheme in the same palette.
- Icons: Slot Dark Icons (https://store.kde.org/p/2234790) plus a generated
  `Slot-Pixegami-Icons` add-on that uses the colorful icons in the sidebar.

Set up on a new machine: `sudo dnf install kvantum`, extract Slot-Dark-Icons to
`~/.local/share/icons/`, then run `./setup-dolphin.sh`.

## snapshot-2026-11-25/

Copies of the Plasma panel, KWin, global and Dolphin config as they were on
2026-11-25, before the dock was changed. To restore the old panel:

```sh
cp snapshot-2026-11-25/plasma-org.kde.plasma.desktop-appletsrc snapshot-2026-11-25/plasmashellrc ~/.config/
systemctl --user restart plasma-plasmashell.service
```

## Pixegami Dock (`plasmoids/com.pixegami.dock`)

A Plasma 6 widget written in QML: a macOS-style dock with zoom on hover, in the
Pixegami palette. It sits in the bottom panel (panel 209), which is 140px tall,
auto-hides, and has its background hidden by the widget so only the dock bar
shows; the empty space above the bar is room for the zoomed icons.

- Left click: open / focus / minimize; on an app with several windows, cycles them.
- Middle click: new window. Right click: New Window, Pin/Unpin, Close.
- Settings in `contents/config/main.xml`: `iconSize` (48), `maxZoom` (1.8).

Install: `ln -sfn ~/.dotfiles/config/kde/plasmoids/com.pixegami.dock ~/.local/share/plasma/plasmoids/`
then add "Pixegami Dock" to a bottom panel. After editing the QML, run
`systemctl --user restart plasma-plasmashell.service` to reload it.
