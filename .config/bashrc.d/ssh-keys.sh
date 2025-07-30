# Description:
#   This script automatically adds private SSH keys to the ssh-agent at shell startup.
#   It scans for commonly named private key files in ~/.ssh (id_rsa_*, id_ed25519_*, id_ecdsa_*)
#   and adds them only if they are not already loaded in the agent.


# Enable nullglob so that unmatched globs return nothing instead of literal pattern
shopt -s nullglob

# Create an array of SSH private key files matching common naming patterns
# This will match files like id_rsa_work, id_ed25519_github, id_ecdsa_personal (excluding *.pub)
keys=( "$HOME/.ssh"/id_rsa_* "$HOME/.ssh"/id_ed25519_* "$HOME/.ssh"/id_ecdsa_* )

# Disable nullglob again to avoid affecting other shell behavior later
shopt -u nullglob

# Loop through each private key file
for key in "${keys[@]}"; do
    # Skip if the file is a public key or not a regular file
    [[ "$key" == *.pub || ! -f "$key" ]] && continue

    # Get the fingerprint of the private key using ssh-keygen
    # This uniquely identifies the key regardless of filename or comment
    fp=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}') || continue

    # Check if the fingerprint is already listed in the ssh-agent
    if ssh-add -l 2>/dev/null | awk '{print $2}' | grep -qx "$fp"; then
        # Fingerprint found: key is already loaded
        echo "🔒 Key already loaded: $key"
    else
        # Key is not loaded, attempt to add it to the agent
        if ssh-add "$key" > /dev/null 2>&1; then
            echo "✅ Added key: $key"
        else
            echo "❌ Failed to add key: $key"
        fi
    fi
done

