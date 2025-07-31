#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="gh_mcc:MadCrabCyder/dotfiles.git"
DOTFILES_DIR="$HOME/.dots"
BACKUP_DIR="$HOME/dotfiles-backup"

function dots {
    /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

echo "📦 Cloning dotfiles from $DOTFILES_REPO..."

# Clone as a bare repo
git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"

echo "📁 Backing up conflicting files..."
mkdir -p "$BACKUP_DIR"

conflicts=$(dots checkout 2>&1 | grep -E "^\s+" || true)
if [[ -n "$conflicts" ]]; then
    echo "$conflicts" | while read -r line; do
        file=$(echo "$line" | awk '{print $1}')
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        mv "$HOME/$file" "$BACKUP_DIR/$file"
        echo "Backed up $HOME/$file -> $BACKUP_DIR/$file"
    done

    echo "♻️ Retrying checkout..."
    dots checkout
fi

dots config --local status.showUntrackedFiles no

# Set HEAD and update master to origin/master

echo "🔧 Configuring tracking..."
dots fetch origin "+refs/heads/*:refs/remotes/origin/*"
dots update-ref refs/heads/master $(dots rev-parse origin/master)
dots symbolic-ref HEAD refs/heads/master
dots config branch.master.remote origin
dots config branch.master.merge refs/remotes/origin/master

echo "✅ Dotfiles installed and tracking origin/master"

echo "🌀 Installing Atuin..."
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh | sh -s -- --no-modify-path
