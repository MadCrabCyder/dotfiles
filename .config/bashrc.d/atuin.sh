# boot strap for atuin - magical shell history
# https://github.com/atuinsh/atuin

# add binaries to PATH if they aren't added yet
# affix colons on either side of $PATH to simplify matching
case ":${PATH}:" in
    *:"$HOME/.atuin/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed binary needs to be overridden
        export PATH="$HOME/.atuin/bin:$PATH"
        ;;
esac

eval "$(atuin init bash)"

