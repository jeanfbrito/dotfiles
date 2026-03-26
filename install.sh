#!/bin/bash
# Install dotfiles via stow (preferred) or manual symlinks (fallback)

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(zsh p10k ghostty)

if command -v stow &>/dev/null; then
  echo "Using GNU Stow..."
  for pkg in "${PACKAGES[@]}"; do
    echo "  Stowing $pkg"
    stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
  done
else
  echo "Stow not found, using manual symlinks..."
  ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  ln -sf "$DOTFILES_DIR/p10k/.p10k.zsh" "$HOME/.p10k.zsh"
  mkdir -p "$HOME/.config/ghostty"
  ln -sf "$DOTFILES_DIR/ghostty/.config/ghostty/config" "$HOME/.config/ghostty/config"
fi

echo "Done!"
