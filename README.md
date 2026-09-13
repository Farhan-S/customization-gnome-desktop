# dotfiles

Tracked configs, restored via symlink so edits in place are automatically
version-controlled.

## Restore on a fresh machine

```sh
git clone <this-repo-url> ~/.dotfiles   # or copy the folder back
~/.dotfiles/config/fonts/install.sh   # fonts referenced by name below - see config/fonts/install.sh
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

Fonts referenced by name in these configs (MesloLGS NF, Fira Code iScript,
FiraCode/JetBrainsMono Nerd Font, Comfortaa) are installed by
`config/fonts/install.sh` above - referencing a font by name doesn't install
it, and GNOME/Ptyxis/VS Code all silently fall back to a default font
instead of erroring when it's missing.

CLI tools (eza/bat/zoxide/fzf/fastfetch/btop) are still not tracked here
since they're binary/package installs, not config files — see the setup
notes from 2026-08-24 for the install commands.
