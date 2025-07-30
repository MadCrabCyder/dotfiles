# Description:
# This script ensures an SSH agent is available and that all private keys from
# ~/.ssh (e.g., id_rsa, id_ed25519, id_ecdsa) are loaded automatically.
#
# Behavior:
# - If SSH agent forwarding is detected (via ssh -A), it uses the forwarded agent.
# - Otherwise, it tries to reuse a persistent local agent via ~/.ssh/agent.env.
# - If the agent is missing or stale, a new one is started and saved.
# - Only private keys (not *.pub) are added, and duplicates are skipped

# If SSH agent is already forwarded (via ssh -A), do nothing
if [[ -n "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" == /tmp/ssh-* ]]; then
    # Likely an agent-forwarded session (or existing socket)
    if ssh-add -l >/dev/null 2>&1; then
        echo "🔐 Using forwarded SSH agent"
        return
    fi
fi

# Fallback: use local ssh-agent environment file
SSH_ENV="$HOME/.ssh/agent.env"

start_ssh_agent() {
    echo "🔑 Starting new ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null
    {
    printf 'export SSH_AUTH_SOCK=%q\n' "$SSH_AUTH_SOCK"
    printf 'export SSH_AGENT_PID=%q\n'  "$SSH_AGENT_PID"
    } > "$SSH_ENV"
    chmod 600 "$SSH_ENV"
}


if [ -f "$SSH_ENV" ]; then
    source "$SSH_ENV" >/dev/null
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null || [ ! -S "$SSH_AUTH_SOCK" ]; then
        start_ssh_agent
    else 
        echo "🔑 ssh-agent already running"
    fi
else
    start_ssh_agent
fi

export SSH_AUTH_SOCK SSH_AGENT_PID


# Only if agent is up and socket exists
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  shopt -s nullglob
  for key in "$HOME/.ssh"/id_{rsa,ed25519,ecdsa}*; do
    
    # Skip if the file is a public key or not a regular file
    [[ "$key" == *.pub || ! -f "$key" ]] && continue

    # Get the fingerprint of the private key using ssh-keygen
    # This uniquely identifies the key regardless of filename or comment    
    fp=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}') || continue

    # Check if the fingerprint is already listed in the ssh-agent
    if ! ssh-add -l 2>/dev/null | awk '{print $2}' | grep -qx "$fp"; then

        # Key is not loaded, attempt to add it to the agent
        if ssh-add "$key" > /dev/null 2>&1; then
            echo "✅ Added key: $key"
        else
            echo "❌ Failed to add key: $key"
        fi
    else
        # Fingerprint found: key is already loaded
        echo "🔒 Key already loaded: $key"
    fi
  done
  shopt -u nullglob
fi