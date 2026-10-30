# Add local completions when installed.
[[ -d "$HOME/completions" ]] && fpath=("$HOME/completions" $fpath)

# Some SSH servers do not have the Ghostty terminal definition.
if [[ -n "$SSH_CONNECTION" && "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty >/dev/null 2>&1; then
  export TERM="xterm-256color"
fi

if [[ -n "$npm_config_yes" || -n "$CI" || "$-" != *i* ]]; then
  export AGENT_MODE=true
else
  export AGENT_MODE=false
fi

export ZSH="$HOME/.oh-my-zsh"
if [[ "$AGENT_MODE" == true ]]; then
  POWERLEVEL9K_INSTANT_PROMPT=off
  POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
  POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
  export DEBIAN_FRONTEND=noninteractive
  export NONINTERACTIVE=1
  ZSH_THEME=""
else
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
  ZSH_THEME="powerlevel10k/powerlevel10k"
fi

plugins=(git history zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

if [[ "$AGENT_MODE" == true ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
  unsetopt CORRECT CORRECT_ALL
  setopt NO_BEEP NO_HIST_BEEP NO_LIST_BEEP
else
  [[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
fi

alias python="python3"
alias pip="pip3"
if command -v code >/dev/null 2>&1; then
  export EDITOR="code --wait"
else
  export EDITOR="${EDITOR:-vi}"
fi

# Keep only installed tool directories on PATH.
typeset -U path
path=("$HOME/.local/bin" $path)
for tool_dir in "$HOME/.rd/bin" "$HOME/.meteor" "$HOME/.rbenv/bin" \
                "$HOME/.opencode/bin" "$HOME/.cache/lm-studio/bin" "$HOME/.grok/bin"; do
  [[ -d "$tool_dir" ]] && path=("$tool_dir" $path)
done
[[ -d "$HOME/.rbenv/completions" ]] && fpath=("$HOME/.rbenv/completions" $fpath)
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - --no-rehash zsh)"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Desktop paths and permission-bypass aliases stay on the Mac.
if [[ "$OSTYPE" == darwin* ]]; then
  [[ -d "$HOME/Library/Android/sdk" ]] && export ANDROID_HOME="$HOME/Library/Android/sdk"
  [[ -d /opt/homebrew/opt/openjdk@17/bin ]] && path=(/opt/homebrew/opt/openjdk@17/bin $path)
  [[ -r /opt/homebrew/share/google-cloud-sdk/path.zsh.inc ]] && source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
  if [[ "$AGENT_MODE" != true && -r /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc ]]; then
    source /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc
  fi
  export SHARP_IGNORE_GLOBAL_LIBVIPS=1
  alias daredevil="claude --dangerously-skip-permissions --chrome"
fi
if [[ -n "$ANDROID_HOME" && -d "$ANDROID_HOME" ]]; then
  path=("$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/platform-tools" $path)
fi
alias download='aria2c -x 16 -s 16 -k 1M -c --file-allocation=none --max-tries=3 --retry-wait=5'

export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL/bin" ]] && path=("$BUN_INSTALL/bin" $path)
if [[ "$AGENT_MODE" != true && -r "$BUN_INSTALL/_bun" ]]; then
  source "$BUN_INSTALL/_bun"
fi
alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
alias pinchtab-headed='BRIDGE_HEADLESS=false BRIDGE_PROFILE="$HOME/.pinchtab/manual-profile" pinchtab'

# Restore terminal modes after an interactive program exits.
_reset_term_modes() {
  printf '\e[<u\e[?1004l\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
}
if [[ "$AGENT_MODE" != true ]]; then
  precmd_functions+=(_reset_term_modes)
fi

[[ -r "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
export VOLTA_HOME="$HOME/.volta"
[[ -d "$VOLTA_HOME/bin" ]] && path=("$VOLTA_HOME/bin" $path)
export AGENT_BROWSER_ARGS="--user-data-dir=/tmp/chrome-copy-profile"
if [[ "$AGENT_MODE" != true && -d "$HOME/.grok/completions/zsh" ]]; then
  fpath=("$HOME/.grok/completions/zsh" $fpath)
  autoload -Uz compinit && compinit -C
fi

# Private settings stay outside this repository.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
true
