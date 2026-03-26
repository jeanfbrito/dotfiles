#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# --- Symlinks ---

echo "Linking dotfiles..."

# Only stow packages that make sense for this OS
PACKAGES=(zsh p10k)

# Ghostty only on macOS (desktop terminal)
if [ "$(uname)" = "Darwin" ]; then
  PACKAGES+=(ghostty)
fi

if command -v stow &>/dev/null; then
  for pkg in "${PACKAGES[@]}"; do
    echo "  Stowing $pkg"
    stow -d "$DOTFILES_DIR" -t "$HOME" --adopt "$pkg"
  done
  # Restore our versions after --adopt
  git -C "$DOTFILES_DIR" checkout .
else
  ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  ln -sf "$DOTFILES_DIR/p10k/.p10k.zsh" "$HOME/.p10k.zsh"
  if [ "$(uname)" = "Darwin" ]; then
    mkdir -p "$HOME/.config/ghostty"
    ln -sf "$DOTFILES_DIR/ghostty/.config/ghostty/config" "$HOME/.config/ghostty/config"
  fi
fi

install_ghostty_terminfo

# Set zsh as default shell if it isn't already
if [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
fi

echo "Done! Open a new terminal to see the changes."
