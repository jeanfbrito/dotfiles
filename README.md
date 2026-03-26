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

The install script uses GNU Stow if available, otherwise falls back to manual symlinks.

## Dependencies

```bash
# macOS
brew install stow fzf
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions
```
