# GNOME / Ptyxis restore

Snapshot of desktop settings, taken 2026-08-24. To restore on a fresh install:

1. Install the extensions listed in `enabled-extensions.txt` from
   https://extensions.gnome.org (search by name) or via their UUIDs.
2. Import the terminal palette:
   `ptyxis --import-palette Pixegami.palette`
3. Load the saved settings:
   ```
   dconf load /org/gnome/shell/extensions/ < extensions-settings.dconf
   dconf load /org/gnome/Ptyxis/ < ptyxis.dconf
   dconf load /org/gnome/desktop/interface/ < interface.dconf
   ```
4. Set the font/palette on the Ptyxis profile if `ptyxis.dconf` doesn't
   already carry it (font: FiraCode Nerd Font Mono 10).
5. Enable the extensions:
   `gsettings set org.gnome.shell enabled-extensions "$(cat enabled-extensions.txt | head -1)"`
6. Install the custom cursor theme (built from ful1e5/Bibata_Cursor source,
   not available anywhere else): `cp -r cursors/Bibata-Modern-Pixegami ~/.icons/`
   `interface.dconf` already sets `cursor-theme='Bibata-Modern-Pixegami'`.
7. Install the recolored + repaired Dracula GTK theme:
   `cp -r themes/Dracula ~/.themes/Dracula`
   `interface.dconf` already sets `gtk-theme='Dracula'`. GTK4 apps additionally
   need `~/.config/environment.d/gtk-theme.conf` (`GTK_THEME=Dracula`) - see
   `environment.d/` in this backup.

## Dracula theme repair notes

The Dracula GTK theme's original install on this system was **missing its
entire top-level `assets/` folder** (window-control buttons, checkboxes,
radio buttons, switches - all silently invisible-but-functional as a result,
since the theme sets `color: transparent` and relies on a background-image
that didn't exist). This was NOT caused by our recoloring - the theme's own
legacy asset-render script (`gtk-4.0/assets/render-gtk3-assets.py`) uses
Inkscape's old interactive-shell protocol, removed in Inkscape 1.0+, so it
silently failed whenever it was originally run.

Fixed by downloading the official pre-built release
(https://github.com/dracula/gtk/releases - `Dracula.tar.xz`) and copying its
`assets/` folder in wholesale, rather than trying to resurrect the broken
render script. The backed-up `themes/Dracula/` folder here already has this
fix applied, plus our `$purple` -> Pixegami mint recolor and the window
control button CSS cleanup (removed the dead image references there,
replaced with icon-based rendering tinted to the accent color).

Also required: the active icon theme (Papirus-Dark, inheriting from
breeze-dark/hicolor) never shipped `window-{close,minimize,maximize}-symbolic.svg`
at all, independent of the GTK theme itself. Fixed by copying those 3 icons
(originally from Adwaita) into the user-level hicolor theme, which merges
with and supplements the system icon theme without touching any system
files. To restore: `cp icons/hicolor-additions/*.svg ~/.local/share/icons/hicolor/scalable/actions/`
then `gtk4-update-icon-cache -f -t ~/.local/share/icons/hicolor`.

## Bibata-Modern-Pixegami cursor theme

Built from https://github.com/ful1e5/Bibata_Cursor source SVGs using their
3-color placeholder system (fill/outline/secondary):

```json
{
  "Bibata-Modern-Pixegami": {
    "dir": "svg/modern",
    "out": "bitmaps/Bibata-Modern-Pixegami",
    "colors": [
      { "match": "#00FF00", "replace": "#86FFAF" },
      { "match": "#0000FF", "replace": "#0C1C25" },
      { "match": "#FF0000", "replace": "#0C1C25" }
    ]
  }
}
```

To rebuild from scratch: clone the repo, save the above as
`render-pixegami.json`, run `npx cbmp render-pixegami.json`, then
`ctgen configs/normal/x.build.toml -p x11 -d bitmaps/Bibata-Modern-Pixegami -o themes -n Bibata-Modern-Pixegami`
(requires Node.js and `pip install clickgen`).
