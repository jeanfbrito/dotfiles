#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LINK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --link-only) LINK_ONLY=1 ;;
    --help|-h)
      printf 'Usage: install.sh [--link-only]\n'
      printf '  --link-only  Link files without package installation or a shell change.\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

install_ghostty_terminfo() {
  local source_file="$DOTFILES_DIR/terminfo/xterm-ghostty.src"

  if [ ! -f "$source_file" ]; then
    return
  fi

  if command -v infocmp &>/dev/null && infocmp xterm-ghostty &>/dev/null; then
    echo "Ghostty terminfo already available"
    return
  fi

  if ! command -v tic &>/dev/null; then
    echo "Skipping Ghostty terminfo install: 'tic' not found"
    return
  fi

  echo "Installing Ghostty terminfo..."
  mkdir -p "$HOME/.terminfo"
  tic -x -o "$HOME/.terminfo" "$source_file"
}

if [ "$LINK_ONLY" -eq 0 ]; then
# Detect package manager
if command -v brew &>/dev/null; then
  PKG="brew"
elif command -v apt-get &>/dev/null; then
  PKG="apt"
else
  echo "No supported package manager found (brew or apt)"
  exit 1
fi

# Update package index on apt-based systems
if [ "$PKG" = "apt" ]; then
  echo "Updating package index..."
  sudo apt-get update -y
fi

install_pkg() {
  if command -v "$1" &>/dev/null; then return; fi
  echo "Installing $1..."
  if [ "$PKG" = "brew" ]; then
    brew install "$1"
  else
    sudo apt-get install -y "$1"
  fi
}

# --- Dependencies ---

install_pkg curl
install_pkg git
install_pkg zsh
install_pkg stow
install_pkg fzf
install_pkg jq   # Claude Code status line parses its JSON payload with jq

if [ "$PKG" = "apt" ] && ! command -v tic &>/dev/null; then
  echo "Installing ncurses-bin..."
  sudo apt-get install -y ncurses-bin
fi

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Plugins
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
  if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
    echo "Installing $plugin..."
    git clone --depth=1 "https://github.com/zsh-users/$plugin.git" "$ZSH_CUSTOM/plugins/$plugin"
  fi
done

fi

# --- Symlinks ---

echo "Linking dotfiles..."

# Never adopt files into the repository or reset a working tree.
# Keep existing files in a private backup before linking individual files.
BACKUP_DIR=""
link_file() {
  local src="$1" dst="$2" relative="$3"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -z "$BACKUP_DIR" ]; then
      mkdir -p "$HOME/.local/state/dotfiles"
      BACKUP_DIR=$(mktemp -d "$HOME/.local/state/dotfiles/backup.XXXXXX")
      chmod 700 "$BACKUP_DIR"
    fi
    mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
    mv "$dst" "$BACKUP_DIR/$relative"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

PACKAGES=(zsh p10k)

# Ghostty only on macOS (desktop terminal)
if [ "$(uname)" = "Darwin" ]; then
  PACKAGES+=(ghostty)
fi

# Link files only. Claude settings, credentials, and history stay outside Git.
PACKAGES+=(claude)
for pkg in "${PACKAGES[@]}"; do
  while IFS= read -r -d '' src; do
    relative="${src#"$DOTFILES_DIR/$pkg/"}"
    link_file "$src" "$HOME/$relative" "$relative"
  done < <(find "$DOTFILES_DIR/$pkg" -type f ! -name '._*' ! -name '.DS_Store' -print0)
done
if [ -n "$BACKUP_DIR" ]; then
  echo "Existing files saved in: $BACKUP_DIR"
fi

install_ghostty_terminfo

# Set zsh as default shell if it isn't already
if [ "$LINK_ONLY" -eq 0 ] && [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
fi

echo "Done! Open a new terminal to see the changes."
