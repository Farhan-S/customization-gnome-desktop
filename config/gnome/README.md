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
