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
   `interface.dconf` already sets `gtk-theme='Dracula'`, which is all GTK3
   apps need. Do **not** set `GTK_THEME=Dracula` - see "GTK4 / libadwaita" below.
8. Link the GTK stylesheets:
   ```
   mkdir -p ~/.config/gtk-4.0 ~/.config/gtk-3.0
   ln -sf ~/.dotfiles/config/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk.css
   ln -sf ~/.dotfiles/config/gtk-3.0/gtk.css ~/.config/gtk-3.0/gtk.css
   ```

## GTK4 / libadwaita theming

GTK4 apps (Files, Settings, and most of GNOME now) are libadwaita apps, and
libadwaita does **not** read `~/.themes/<name>/gtk-4.0/` for its colors. Two
consequences, both learned the hard way on 2026-08-28:

* `GTK_THEME=Dracula` in `environment.d/` *did* force Dracula's GTK4 sheet onto
  libadwaita apps - but it also makes libadwaita **ignore color overrides from
  `~/.config/gtk-4.0/gtk.css`**. Named colors (`window_bg_color`,
  `headerbar_bg_color`, `card_bg_color`, ...) silently fall back to stock
  Adwaita values. Verified by rendering the same window with and without the
  variable: with it, the window background came out `#353535`; without it,
  `#282a36` as intended. The variable is now removed.
* Dracula's own `gtk-4.0/gtk.css` is a 2.1 MB single-line web-CSS port. It
  defines none of libadwaita's named colors and does not parse - it uses
  `filter: brightness()`, which is not a GTK property. It is parked here as
  `themes/Dracula/gtk-4.0.disabled` so GTK4 falls back to Adwaita, which
  `config/gtk-4.0/gtk.css` then restyles properly.

`config/gtk-4.0/gtk.css` is the real GTK4 theme: full Dracula palette mapped
onto libadwaita's named colors (written both as `@define-color` and as `:root`
custom properties so it survives the deprecation), 14px window radius, and
roomier metrics throughout. Note that libadwaita resolves the *accent* at
runtime from `org.gnome.desktop.interface accent-color`, which beats the CSS
variables - so accent-driven widgets (switches, checks, level bars) pin
`#86ffaf` explicitly.

Window-control buttons deliberately have **no** size override. They expand to
the header bar's height, so a `min-height` + `border-radius: 999px` there
produced an oversized disc on hover; libadwaita already sizes them correctly.

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
