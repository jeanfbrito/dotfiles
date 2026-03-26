# Add deno completions to search path
if [[ ":$FPATH:" != *":$HOME/completions:"* ]]; then export FPATH="$HOME/completions:$FPATH"; fi

# Ghostty uses TERM=xterm-ghostty, but many servers don't ship that terminfo.
# When connecting over SSH, fall back to a widely available entry to avoid zle/prompt redraw glitches.
if [[ -n "$SSH_CONNECTION" ]] && [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty >/dev/null 2>&1; then
  export TERM="xterm-256color"
fi

# Agent detection - only activate minimal mode for actual agents  
if [[ -n "$npm_config_yes" ]] || [[ -n "$CI" ]] || [[ "$-" != *i* ]]; then
  export AGENT_MODE=true
else
  export AGENT_MODE=false
fi

if [[ "$AGENT_MODE" == "true" ]]; then
  POWERLEVEL9K_INSTANT_PROMPT=off
  # Disable complex prompt features for AI agents
  POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
  POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
  # Ensure non-interactive mode
  export DEBIAN_FRONTEND=noninteractive
  export NONINTERACTIVE=1
fi

# Enable Powerlevel10k instant prompt only when not in agent mode
if [[ "$AGENT_MODE" != "true" ]] && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Theme - disable for agents
if [[ "$AGENT_MODE" == "true" ]]; then
  ZSH_THEME=""  # Disable Powerlevel10k for agents
else
  ZSH_THEME="powerlevel10k/powerlevel10k"
fi


plugins=(git history zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf)
source $ZSH/oh-my-zsh.sh

# Prompt - minimal for agents, p10k for interactive
if [[ "$AGENT_MODE" == "true" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
  unsetopt CORRECT
  unsetopt CORRECT_ALL
  setopt NO_BEEP
  setopt NO_HIST_BEEP  
  setopt NO_LIST_BEEP
  
else
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

alias python="python3"
alias pip="pip3"
export EDITOR="code --wait"

# Rancher Desktop
export PATH="$HOME/.rd/bin:$PATH"
export PATH="$HOME/.meteor:$PATH"

# pipx
export PATH="$PATH:$HOME/.local/bin"

# rbenv
FPATH=~/.rbenv/completions:"$FPATH"
export PATH="$HOME/.rbenv/bin:$PATH"
autoload -U compinit
compinit
eval "$(rbenv init - --no-rehash zsh)"

eval "$(direnv hook zsh)"

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

alias daredevil="CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 claude --dangerously-skip-permissions --chrome"
alias download='aria2c -x 16 -s 16 -k 1M -c --file-allocation=none --max-tries=3 --retry-wait=5'

# Google Cloud SDK
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'; fi
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'; fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Volta - Node version manager (must be last to take priority)
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"

# Bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# LM Studio
export PATH="$PATH:$HOME/.cache/lm-studio/bin"

alias pinchtab-headed='BRIDGE_HEADLESS=false BRIDGE_PROFILE="$HOME/.pinchtab/manual-profile" pinchtab'
