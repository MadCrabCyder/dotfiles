# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Exit early if not an interactive shell
[[ $- != *i* ]] && return

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

if [ -d "$HOME/.config/bashrc.d" ]; then
    for rc in "$HOME/.config/bashrc.d/"*; do
        [ -r "$rc" ] && . "$rc"
    done
    unset file
fi

