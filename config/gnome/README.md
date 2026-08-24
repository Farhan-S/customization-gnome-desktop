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
