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
```

Terminal font (MesloLGS NF) and CLI tools (eza/bat/zoxide/fzf/fastfetch/btop)
are not tracked here since they're binary/package installs, not config files —
see the setup notes from 2026-08-24 for the install commands.
