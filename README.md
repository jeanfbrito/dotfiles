# dotfiles

My terminal setup: zsh, Powerlevel10k, Ghostty, and a Claude Code status line.
The installer links individual files and preserves existing files in private backups.

## What's included

| Package | Files |
|---------|-------|
| `zsh` | `.zshrc` — Oh My Zsh, fzf, autosuggestions, syntax-highlighting. `.zprofile` adds user commands to the login-shell PATH. |
| `p10k` | `.p10k.zsh` — Powerlevel10k rainbow prompt, transient prompt, node_version |
| `ghostty` | `.config/ghostty/config` — colors, Hack Nerd Font Mono 13 (macOS only) |
| `claude` | `.claude/statusline-command.sh` — p10k-style status line with Git and PR status. `.claude/hooks/pin-pr.sh` pins the current PR. |

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
5. Links individual files after saving existing files under `~/.local/state/dotfiles/backup.*`
6. Sets zsh as your default shell
7. Ghostty config is only linked on macOS
8. Installs bundled `xterm-ghostty` terminfo when missing (useful on SSH servers)

The script keeps links that already point to this clone. It does not reset the repository.
Use `./install.sh --link-only` to omit dependency installation and the default-shell change.
This mode installs files only. It does not prove that zsh or its plugins are available.

Keep private settings in `~/.zshrc.local`, outside this repository.
Do not put tokens or passwords in the shared `.zshrc`.
Mac-specific paths and the existing permission-bypass alias apply only on macOS.

## Claude Code status line

`claude/.claude/statusline-command.sh` uses the p10k palette and glyphs.
It shows the directory and Git branch on the left.
It shows the model and context usage on the right. It needs `jq` (installed by the
script) and a Nerd Font in the terminal.

The install script links only the status line and hook files into `~/.claude/`.
Settings, credentials, plugins, and session history stay outside this repository.
Claude Code still has to be told to use it, once per machine, in
`~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
```

### PR segment

With `gh` installed and authenticated, a segment after the Git branch shows the current pull request.
For example, `#3485 ✓8 …1` shows eight passed checks and one pending check.
The segment also shows these indicators:

- `✗` for failed checks and `…` for pending checks.
- `⚡` for a merge conflict and `✉2` for two unresolved review threads.
- `✔` for approval or `✎` for requested changes.
 Green when all checks
pass, yellow while any run, red on a failure, grey with a `draft` prefix for
drafts. A merged PR shows `#3485 merged` in magenta, a closed one `#3485
closed` in grey. A trailing `~` means GitHub could not be reached and the
numbers are the last known ones.

Which PR it shows, in order:

1. `~/.cache/claude-statusline/session-<session_id>.pr` or
   `~/.cache/claude-statusline/current.pr`, each a single line
   `owner/repo#number`. Pins the segment to a PR regardless of the current
   directory, useful when the work lives in a git worktree. Remove the file to unpin.
   A merged or closed PR pin expires after `CLAUDE_STATUSLINE_PR_UNPIN` seconds (default 600).
2. Otherwise the open PR for the current directory's branch.

`hooks/pin-pr.sh` writes those hint files after Claude Code runs a matching `gh pr` command.
Examples include `gh pr create`, `gh pr view`, and `gh pr checks`.
The PR in the command output becomes the pinned PR.
Configure it once per machine as a `PostToolUse` hook on `Bash` in `~/.claude/settings.json`:

```json
{ "type": "command", "command": "bash ~/.claude/hooks/pin-pr.sh", "timeout": 5 }
```

The render never calls GitHub directly. It reads a cache under
`~/.cache/claude-statusline/` and refreshes it in a detached background job
(one `gh pr view` per PR per interval) when the cache is older than:

- `CLAUDE_STATUSLINE_PR_TTL` (default 60 s) while checks still run or a pushed branch has no PR yet.
- `CLAUDE_STATUSLINE_PR_TTL_SETTLED` (default 600 s) once every check has
  finished.

A branch with no `origin/<branch>` counterpart cannot have a PR, so nothing
is polled for it at all.

The status line does not poll merged PRs again.
When GitHub is unavailable, each failure doubles the interval, up to 30 minutes.
The last known numbers stay on screen with a `~`.

Two events bypass the interval:

- A push changes the PR branch's remote-tracking ref, including pushes from another worktree.
- A hint file is newer than the cache. Rewrite or touch `current.pr` to force a refresh.

Refresh jobs remove cache files older than seven days.
`CLAUDE_STATUSLINE_PR=0` disables the segment. Without `gh`, or without
`gh auth login`, the segment is simply omitted.

The render uses Git and jq to read local state.
Only detached refresh jobs contact GitHub.

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
