GIT_PROMPT_STATUS=""

git_update_prompt_status() {
    local status_output
    local line
    local branch=""
    local oid=""
    local dirty=0
    local has_upstream=0
    local ahead=0
    local behind=0
    local summary=""

    status_output="$(git status --porcelain=v2 --branch 2>/dev/null)" || {
        GIT_PROMPT_STATUS=""
        return 0
    }

    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ branch\.head\ (.+)$ ]]; then
            branch="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#\ branch\.oid\ ([0-9a-f]+)$ ]]; then
            oid="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#\ branch\.upstream\  ]]; then
            has_upstream=1
        elif [[ "$line" =~ ^#\ branch\.ab\ \+([0-9]+)\ -([0-9]+)$ ]]; then
            ahead="${BASH_REMATCH[1]}"
            behind="${BASH_REMATCH[2]}"
        elif [[ "$line" != \#* ]]; then
            dirty=1
        fi
    done <<< "$status_output"

    case "$branch" in
        "")
            GIT_PROMPT_STATUS=""
            return 0
            ;;
        "(detached)")
            branch="${oid:0:7}"
            [[ -n "$branch" ]] || branch="detached"
            ;;
    esac

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

    GIT_PROMPT_STATUS="${branch}${summary}"
}

if declare -p precmd_functions >/dev/null 2>&1; then
    case " ${precmd_functions[*]} " in
        *" git_update_prompt_status "*) ;;
        *) precmd_functions+=(git_update_prompt_status) ;;
    esac
fi

git_update_prompt_status

PS1='\e[32m\]${DOTS_PROMPT_STATUS}\e[0m\]\u@\h:\w${GIT_PROMPT_STATUS:+ (\[\e[32m\]${GIT_PROMPT_STATUS}\[\e[0m\])}\$ '
