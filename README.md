# dotfiles

Personal configs: zsh, tmux, neovim.

## Setup

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` symlinks the tracked files into their expected locations. Any existing files at those paths are moved to `~/.dotfiles-backup/<timestamp>/` first.
