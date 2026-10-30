# Login shells do not read .zshrc unless they are interactive.
# Keep user-installed commands available to SSH login commands.
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH
