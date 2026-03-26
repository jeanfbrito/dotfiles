# dotfiles

My terminal setup: zsh, Powerlevel10k, Ghostty — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

| Package | Files |
|---------|-------|
| `zsh` | `.zshrc` — Oh My Zsh, fzf, autosuggestions, syntax-highlighting |
| `p10k` | `.p10k.zsh` — Powerlevel10k rainbow prompt, transient prompt, node_version |
| `ghostty` | `.config/ghostty/config` — colors, Hack Nerd Font Mono 13 (macOS only) |

## Quick start

### macOS

```bash
git clone https://github.com/jeanfbrito/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Ubuntu/Debian server

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/jeanfbrito/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## What the install script does

1. Detects your package manager (Homebrew or apt)
2. Runs `apt-get update` on Debian-based systems
3. Installs curl, git, zsh, stow, and fzf
4. Installs Oh My Zsh, Powerlevel10k, and plugins (autosuggestions, syntax-highlighting, completions)
5. Creates symlinks via GNU Stow (falls back to `ln -sf` if stow is unavailable)
6. Sets zsh as your default shell
7. Ghostty config is only linked on macOS
8. Installs bundled `xterm-ghostty` terminfo when missing (useful on SSH servers)

The script is idempotent — safe to run multiple times. It skips anything already installed.

## Updating

Config changes are picked up automatically since files are symlinked:

```bash
cd ~/dotfiles
git pull
```

If new packages were added to the repo, run the install script again:

```bash
cd ~/dotfiles
git pull
./install.sh
```
