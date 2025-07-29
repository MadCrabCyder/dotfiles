# Description:
#   Defines a shell function `dots` that acts as a wrapper around Git to manage dotfiles.
#   It uses a bare Git repository located at ~/.dots and treats $HOME as the working tree.
#
#   Example usage:
#     dots status           # Show changes in tracked dotfiles
#     dots add .bashrc      # Add a file to the dotfiles repo
#     dots commit -m "msg"  # Commit changes
#     dots push             # Push to remote


function dots {
    /usr/bin/git --git-dir="$HOME/.dots/" --work-tree="$HOME" "$@"
}

# Check for uncommitted local changes in dotfiles
function dots_check_local_status {
    if dots status --porcelain | grep -q .; then
        echo "🔧 You have uncommitted changes in your dotfiles."
    else
        echo "✅ Your dotfiles are clean."
    fi
}

# Check if the local branch is ahead/behind/diverged from upstream
function dots_check_remote_status {
    # Ensure upstream is configured
    if ! dots rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        echo "⚠️ No upstream configured for your current dotfiles branch."
        return
    fi

    # Fetch remote updates quietly
    dots fetch >/dev/null 2>&1

    # Get commit hashes
    local_local=$(dots rev-parse @)
    remote_upstream=$(dots rev-parse @{u})
    base_commit=$(dots merge-base @ @{u})

    # Compare and print sync status
    if [ "$local_local" = "$remote_upstream" ]; then
        echo "✅ Your dotfiles are up to date with upstream."
    elif [ "$local_local" = "$base_commit" ]; then
        echo "⬇️ Your dotfiles are behind upstream. Run 'dots pull'."
    elif [ "$remote_upstream" = "$base_commit" ]; then
        echo "⬆️ Your dotfiles are ahead of upstream. Run 'dots push'."
    else
        echo "⚠️ Your dotfiles have diverged from upstream."
    fi
}

# Check for local and remote changes in dotfiles
function dots_check {
    dots_check_local_status
    dots_check_remote_status
}

# Add Nag on new shell - local check only as remote is slower
dots_check_local_status
