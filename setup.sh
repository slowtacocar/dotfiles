#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date -u +%Y%m%dT%H%M%SZ)"

link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        local current
        current="$(readlink "$dst")"
        if [ "$current" = "$src" ]; then
            echo "ok    $dst -> $src"
            return
        fi
        rm "$dst"
    elif [ -e "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        echo "backup $dst -> $BACKUP_DIR/"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "link  $dst -> $src"
}

link "$REPO_DIR/zshrc"     "$HOME/.zshrc"
link "$REPO_DIR/tmux.conf" "$HOME/.tmux.conf"
link "$REPO_DIR/nvim"      "$HOME/.config/nvim"
