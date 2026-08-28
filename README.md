# dotfiles

Tracked configs, restored via symlink so edits in place are automatically
version-controlled.

## Restore on a fresh machine

```sh
git clone <this-repo-url> ~/.dotfiles   # or copy the folder back
ln -sf ~/.dotfiles/zshrc              ~/.zshrc
ln -sf ~/.dotfiles/zshenv             ~/.zshenv
ln -sf ~/.dotfiles/p10k.zsh           ~/.p10k.zsh
mkdir -p ~/.config/Code/User
ln -sf ~/.dotfiles/config/Code/User/settings.json    ~/.config/Code/User/settings.json
ln -sf ~/.dotfiles/config/Code/User/keybindings.json ~/.config/Code/User/keybindings.json
mkdir -p ~/.config/gtk-4.0 ~/.config/gtk-3.0
ln -sf ~/.dotfiles/config/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk.css
ln -sf ~/.dotfiles/config/gtk-3.0/gtk.css ~/.config/gtk-3.0/gtk.css
```

GTK/GNOME theming (themes, cursors, icons, GTK4 stylesheet) is documented
separately in `config/gnome/README.md`.

Terminal font (MesloLGS NF) and CLI tools (eza/bat/zoxide/fzf/fastfetch/btop)
are not tracked here since they're binary/package installs, not config files —
see the setup notes from 2026-08-24 for the install commands.
