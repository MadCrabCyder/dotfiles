# Description:
# Ensure an SSH agent is available for interactive shells and load common
# private keys from ~/.ssh into the selected local agent.
#
# Behavior:
# - Reuse an already-working SSH agent from the current environment.
# - If no live agent is present, try to restore one from ~/.ssh/agent.env.
# - If the restored agent is stale, start a new local agent and persist it.
# - Skip local key loading when the shell is running inside an SSH session with
#   an existing agent.
# - Stay quiet by default; set SSH_AGENT_VERBOSE=1 to print status messages.

command -v ssh-agent >/dev/null 2>&1 || return 0
command -v ssh-add >/dev/null 2>&1 || return 0
command -v ssh-keygen >/dev/null 2>&1 || return 0

SSH_AGENT_ENV_FILE="$HOME/.ssh/agent.env"

ssh_agent_log() {
    [[ -n "${SSH_AGENT_VERBOSE:-}" ]] || return 0
    printf '%s\n' "$*"
}

ssh_agent_is_live() {
    local status

    [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK:-}" ]] || return 1

    command ssh-add -l >/dev/null 2>&1
    status=$?

    [[ $status -eq 0 || $status -eq 1 ]]
}

ssh_agent_write_env() {
    mkdir -p "$HOME/.ssh"
    {
        printf 'export SSH_AUTH_SOCK=%q\n' "$SSH_AUTH_SOCK"
        printf 'export SSH_AGENT_PID=%q\n' "${SSH_AGENT_PID:-}"
    } > "$SSH_AGENT_ENV_FILE"
    chmod 600 "$SSH_AGENT_ENV_FILE"
}

ssh_agent_start() {
    ssh_agent_log "Starting local ssh-agent"
    eval "$(command ssh-agent -s)" >/dev/null
    ssh_agent_write_env
    export SSH_AUTH_SOCK SSH_AGENT_PID
}

ssh_agent_restore() {
    [[ -f "$SSH_AGENT_ENV_FILE" ]] || return 1

    # shellcheck disable=SC1090
    source "$SSH_AGENT_ENV_FILE" >/dev/null
    export SSH_AUTH_SOCK SSH_AGENT_PID

    ssh_agent_is_live
}

ssh_agent_loaded_fingerprints() {
    local output
    local status

    output="$(command ssh-add -l 2>/dev/null)"
    status=$?

    case $status in
        0)
            awk 'NF >= 2 { print $2 }' <<< "$output"
            ;;
        1)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ssh_agent_load_keys() {
    local had_nullglob=0
    local key
    local fingerprint
    local loaded_fingerprints

    ssh_agent_is_live || return 0

    loaded_fingerprints="$(ssh_agent_loaded_fingerprints || true)"

    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob

    for key in "$HOME/.ssh"/id_{rsa,ed25519,ecdsa}{,_*}; do
        [[ -f "$key" ]] || continue
        [[ "$key" == *.pub || "$key" == *-cert.pub ]] && continue

        fingerprint="$(command ssh-keygen -lf "$key" 2>/dev/null | awk 'NF >= 2 { print $2 }')" || continue
        [[ -n "$fingerprint" ]] || continue

        if grep -qxF "$fingerprint" <<< "$loaded_fingerprints"; then
            continue
        fi

        if command ssh-add "$key" >/dev/null 2>&1; then
            ssh_agent_log "Added SSH key: $key"
            loaded_fingerprints+="${loaded_fingerprints:+$'\n'}$fingerprint"
        else
            printf 'ssh-agent: failed to add key %s\n' "$key" >&2
        fi
    done

    if (( ! had_nullglob )); then
        shopt -u nullglob
    fi
}

if ssh_agent_is_live; then
    export SSH_AUTH_SOCK SSH_AGENT_PID

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        ssh_agent_log "Using existing SSH agent from SSH session"
        return 0
    fi

    ssh_agent_log "Using existing SSH agent"
elif ssh_agent_restore; then
    ssh_agent_log "Reusing persisted local ssh-agent"
else
    ssh_agent_start
fi

ssh_agent_load_keys
