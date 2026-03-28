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

DOTS_PROMPT_STATUS=""

function dots_current_upstream {
    dots rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null
}

# Check for uncommitted local changes in dotfiles
function dots_check_local_status {
    if dots diff --quiet && dots diff --cached --quiet; then
        echo "✅ Your dotfiles are clean."
    else
        echo "🔧 You have uncommitted changes in your dotfiles."
    fi
}

# Check if the local branch is ahead/behind/diverged from upstream
function dots_check_remote_status {
    local refresh=0
    local upstream
    local ahead
    local behind
    local freshness_note=" (based on last fetch)"

    if [[ "${1:-}" == "--refresh" ]]; then
        refresh=1
        freshness_note=""
        shift
    fi

    if [[ $# -gt 0 ]]; then
        echo "Usage: dots_check_remote_status [--refresh]"
        return 2
    fi

    upstream="$(dots_current_upstream)" || {
        echo "⚠️ No upstream configured for the current dotfiles branch."
        return 1
    }

    if (( refresh )) && ! dots fetch --quiet; then
        echo "⚠️ Failed to refresh dotfiles from $upstream."
        return 1
    fi

    if ! read -r ahead behind < <(dots rev-list --left-right --count HEAD...@{upstream}); then
        echo "⚠️ Unable to compare your dotfiles branch to $upstream."
        return 1
    fi

    if (( ahead == 0 && behind == 0 )); then
        echo "✅ Your dotfiles are up to date with $upstream$freshness_note."
    elif (( ahead == 0 )); then
        echo "⬇️ Your dotfiles are behind $upstream$freshness_note. Run 'dots pull'."
    elif (( behind == 0 )); then
        echo "⬆️ Your dotfiles are ahead of $upstream$freshness_note. Run 'dots push'."
    else
        echo "⚠️ Your dotfiles have diverged from $upstream$freshness_note."
    fi
}

# Check for local and remote changes in dotfiles
function dots_check {
    if [[ "${1:-}" == "--refresh" ]]; then
        dots_check_local_status
        dots_check_remote_status --refresh
        return $?
    fi

    if [[ $# -gt 0 ]]; then
        echo "Usage: dots_check [--refresh]"
        return 2
    fi

    dots_check_local_status
    dots_check_remote_status
}

function dots_update_prompt_status {
    local status_output
    local line
    local dirty=0
    local has_upstream=0
    local ahead=0
    local behind=0
    local summary=""

    status_output="$(dots status --porcelain=v2 --branch 2>/dev/null)" || {
        DOTS_PROMPT_STATUS=""
        return 0
    }

    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ branch\.upstream\  ]]; then
            has_upstream=1
        elif [[ "$line" =~ ^#\ branch\.ab\ \+([0-9]+)\ -([0-9]+)$ ]]; then
            ahead="${BASH_REMATCH[1]}"
            behind="${BASH_REMATCH[2]}"
        elif [[ "$line" != \#* ]]; then
            dirty=1
        fi
    done <<< "$status_output"

    if (( dirty )); then
        summary+="!"
    fi

    if (( ! has_upstream )); then
        summary+="?"
    elif (( ahead > 0 && behind > 0 )); then
        summary+="↕"
    elif (( ahead > 0 )); then
        summary+="↑"
    elif (( behind > 0 )); then
        summary+="↓"
    fi

    if [[ -n "$summary" ]]; then
        DOTS_PROMPT_STATUS="[dots:${summary}] "
    else
        DOTS_PROMPT_STATUS=""
    fi
}

# Keep the dotfiles status visible in the prompt without printing during shell init.
if declare -p precmd_functions >/dev/null 2>&1; then
    case " ${precmd_functions[*]} " in
        *" dots_update_prompt_status "*) ;;
        *) precmd_functions+=(dots_update_prompt_status) ;;
    esac
fi

dots_update_prompt_status
