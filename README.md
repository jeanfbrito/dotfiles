# dotfiles

My terminal setup: zsh, Powerlevel10k, Ghostty — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

| Package | Files |
|---------|-------|
| `zsh` | `.zshrc` — Oh My Zsh, fzf, autosuggestions, syntax-highlighting |
| `p10k` | `.p10k.zsh` — Powerlevel10k rainbow prompt, transient prompt, node_version |
| `ghostty` | `.config/ghostty/config` — colors, Hack Nerd Font Mono 13 (macOS only) |
| `claude` | `.claude/statusline-command.sh` — Claude Code status line styled like the p10k prompt, with git and PR status |

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

## Claude Code status line

`claude/.claude/statusline-command.sh` renders the Claude Code status line with
the same palette and glyphs as the p10k prompt: directory and git branch on the
left, model and context usage on the right. It needs `jq` (installed by the
script) and a Nerd Font in the terminal.

The install script links only that one file into `~/.claude/` (`--no-folding`),
because the rest of `~/.claude` is per-machine state that must stay out of git.
Claude Code still has to be told to use it, once per machine, in
`~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
```

### PR segment

When `gh` is installed and authenticated, a segment after the git branch shows
the pull request being worked on: `#3485 ✓8 …1` (checks passed, `✗` failed,
`…` pending; `✔` approved, `✎` changes requested). Green when all checks pass,
yellow while any run, red on a failure, grey with a `draft` prefix for drafts.

Which PR it shows, in order:

1. `~/.cache/claude-statusline/session-<session_id>.pr` or
   `~/.cache/claude-statusline/current.pr`, each a single line
   `owner/repo#number`. Pins the segment to a PR regardless of the current
   directory, useful when the work lives in a git worktree. Delete the file to
   unpin.
2. Otherwise the open PR for the current directory's branch.

The render never calls GitHub directly. It reads a cache under
`~/.cache/claude-statusline/` and refreshes it in a detached background job
(one `gh pr view` per PR per interval) when the cache is older than:

- `CLAUDE_STATUSLINE_PR_TTL` (default 60 s) while checks are still running,
  or while a pushed branch has no PR yet;
- `CLAUDE_STATUSLINE_PR_TTL_SETTLED` (default 600 s) once every check has
  finished.

A branch with no `origin/<branch>` counterpart cannot have a PR, so nothing
is polled for it at all.

Two events bypass the interval: a new commit on the current branch (the
branch head is part of the cache key), and a hint file newer than the cache
(rewriting or `touch`ing `current.pr` forces a refresh). Cache files older
than seven days are pruned during refreshes. `CLAUDE_STATUSLINE_PR=0`
disables the segment. Without `gh`, or without `gh auth login`, the segment
is simply omitted.

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
