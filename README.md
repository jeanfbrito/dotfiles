# dotfiles

My terminal setup: zsh, Powerlevel10k, Ghostty — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

| Package | Files |
|---------|-------|
| `zsh` | `.zshrc` — Oh My Zsh, fzf, autosuggestions, syntax-highlighting |
| `p10k` | `.p10k.zsh` — Powerlevel10k rainbow prompt, transient prompt, node_version |
| `ghostty` | `.config/ghostty/config` — colors, Hack Nerd Font Mono 13 |

## Quick start

```bash
git clone https://github.com/jeanfbrito/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script automatically installs all dependencies (zsh, stow, fzf, Oh My Zsh, Powerlevel10k, plugins) and creates the symlinks. Works on macOS (Homebrew) and Ubuntu/Debian (apt). Ghostty config is only linked on macOS.
