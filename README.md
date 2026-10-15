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

## Neovim performance profiling

Run `:LspProfileStart` and reproduce the slowdown for 30 seconds. The capture
stops automatically; `:LspProfileStart 60` records longer, and `:LspProfileStop`
stops early. In an editor opened before these commands were added, first run
`:lua require("config.profile").setup()`.

Results are saved under `~/.local/state/nvim/profiles/<timestamp>-<pid>/`:
`traffic.json` contains LSP request counts, cancellations, response times,
outstanding requests, and event-loop delays; `lua-profile.txt` contains LuaJIT
stack samples. Buffer text and protocol payloads are not recorded. A useful
capture includes active typing and a few seconds waiting for suggestions.
