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

A Plasma 6 widget written in QML: a macOS / Latte-style dock in the Pixegami
palette. It sits in the bottom panel (panel 209): 140px tall, hides when a
window covers it ("dodge windows"), panel background hidden by the widget so
only the semi-transparent dock bar shows. The empty space above the bar is
room for the zoomed icons.

- Smooth parabolic zoom (eased pointer, GPU-scaled icons), app name labels.
- Borderless semi-transparent bar with real KWin blur behind it: the widget
  resizes the panel's (invisible) background frame to the bar, so Plasma asks
  KWin to blur only that rounded area.
- First icon opens the Application Dashboard: a stock `kickerdash` widget lives
  hidden in the same panel (global shortcut Ctrl+Alt+Meta+D), and the icon
  triggers it through kglobalaccel.
- Live window previews on hover (click to focus, middle-click or ✕ to close).
- Left click: open / focus / minimize; with several windows, shows them all
  side by side (KWin Window View). Scroll on an icon cycles its windows.
- Middle click: new window. Right click: New Window, Show All Windows,
  Pin/Unpin, Minimize/Restore, Close.
- Drag icons left/right to reorder (order is saved to the pinned list). Drop files on an app to open them with it; hovering
  a drag over a running app raises its window. Drop a .desktop file on the
  dock to pin it.
- Indicators: dot per window (up to 3), mint pill + glow for the focused app,
  amber + hop when an app wants attention, bounce while an app starts.
- Trash at the end: full/empty icon, click to open, drop files to trash.
- Genie minimize: KWin's Magic Lamp effect is on (`kwinrc` [Plugins]
  magiclampEnabled=true, squashEnabled=false) and the dock tells KWin where
  each icon is, so windows minimize into their icon.
- Settings: right-click the dock > Configure (icon size, zoom, zoom reach,
  background opacity, labels, previews, Trash, launch bounce).

Install: `ln -sfn ~/.dotfiles/config/kde/plasmoids/com.pixegami.dock ~/.local/share/plasma/plasmoids/`
then add "Pixegami Dock" to a bottom panel. After editing the QML, run
`systemctl --user restart plasma-plasmashell.service` to reload it.

## Pixegami Bar (`plasmoids/com.pixegami.topbar`)

The top bar is three floating "islands". Each is its own top panel with a
fixed length so that together they cover the screen (1920px: left 830,
centre 260, right 830), and a Pixegami Bar widget that styles it:

- while floating, the background (navy glass tint + KWin blur shape) hugs the
  panel's widgets as a rounded pill, so you see three separate islands;
- when a window touches the bar, Plasma animates the panel's floatingness to
  0; the widget uses that to grow each pill to its full panel width, so the
  islands merge smoothly into one flat full-width bar (and split again);
- the panel content is pinned, so widgets never move while the background
  grows; spacers keep each island's widgets at their side.

| Island | Panel | Order |
|---|---|---|
| left | 242 | logo button (showLogo=true), Global Menu, spacer |
| centre | 245 | spacer, Digital Clock ("Wed 25 Nov  10:53 PM"), spacer, styler |
| right | 185 | spacer, Color Picker, System Tray, styler |

The logo opens the user menu, drawn in Pixegami navy: profile picture
(`/var/lib/AccountsService/icons/$USER`) in a mint ring, real name,
user@host, uptime; then Applications (Meta), Search (KRunner), System
Settings, Account, About This System, Lock Screen, Sleep, Restart, Shut Down,
Log Out.

"Applications" and the Meta key open the Application Dashboard through its
global-shortcut action (`activate widget 238`); Plasma's activateLauncherMenu
doesn't reach the hidden dashboard. Meta is set in `kwinrc`:
`[ModifierOnlyShortcuts] Meta=org.kde.kglobalaccel,/component/plasmashell,org.kde.kglobalaccel.Component,invokeShortcut,activate widget 238`
(update the id if the dashboard widget is ever re-created).

The menu also shows live stats (CPU % and temperature, memory, swap, disk,
battery, Wi-Fi name + down/up speed + signal),
polled every 1.5 s only while it is open; clicking them opens System Monitor.
Shortcuts are shown as key caps ("Win" = the Windows/Super key, KDE's Meta).

Power shortcuts (global, stored in `~/.config/kglobalshortcutsrc`):
Lock Win+L and Log Out Ctrl+Alt+Del are KDE defaults; added:
Sleep Win+Alt+S, Restart Win+Alt+R, Shut Down Win+Alt+Q. To re-create them,
use System Settings > Shortcuts (Power Management > Suspend; Session
Management > Reboot / Shut Down), or the kglobalaccel D-Bus call
`setForeignShortcutKeys` as done on 2026-11-25.

Settings in `contents/config/main.xml`: `showLogo` (false = invisible styler
only), `bgOpacity` (0.72), `stylePanel`.

Widget order is saved by Plasma on shutdown, so to reorder by hand stop
plasmashell first, edit `AppletOrder` in `plasma-org.kde.plasma.desktop-appletsrc`,
then start it again.
