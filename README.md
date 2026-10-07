# dotfiles

Personal configs: zsh (+ powerlevel10k), tmux, neovim, git.

## Setup

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` symlinks the tracked files into their expected locations. Any existing files at those paths are moved to `~/.dotfiles-backup/<timestamp>/` first.

## tmux

The status bar uses tmux's built-in formatting to match Neovim's Modus Vivendi
statusline: flat charcoal sections, light text, soft blue accents, and plain `|` separators. It shows
session and window names, hostname, and date/time. No plugin or special font is
needed.

After editing `tmux.conf`, apply changes to running sessions with:

```sh
tmux source-file ~/.tmux.conf
```
