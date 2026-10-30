#!/bin/bash
# Auto-pin hook for the statusline's PR segment (~/.claude/statusline-command.sh).
#
# Wired as a Claude Code PostToolUse hook (matcher "Bash") in
# ~/.claude/settings.json — this file does NOT edit settings.json itself.
# Every time a `gh pr ...` command runs in an agent session, this hook extracts
# the PR it just touched and writes it to the statusline's hint files so the
# segment tracks that PR instead of (or in addition to) the cwd's branch:
#   ~/.cache/claude-statusline/session-<session_id>.pr   (this session only)
#   ~/.cache/claude-statusline/current.pr                (global fallback)
# Writing either file bumps its mtime, which the status line already treats as
# a forced refresh (see step E/hint-mtime invalidation in the main script) —
# so the segment picks up the new pin on the very next render, not after a TTL.
#
# To remove a pin: delete the relevant file, e.g.
#   rm ~/.cache/claude-statusline/current.pr
#   rm ~/.cache/claude-statusline/session-<id>.pr
#
# Contract: a PostToolUse hook receives JSON on stdin with (at least)
# session_id, tool_name, tool_input.command, and tool_response — the exact key
# holding the command's stdout inside tool_response is undocumented across
# Claude Code versions, so this never assumes a key name; it stringifies the
# whole tool_response and greps it. This hook must NEVER fail the tool call it
# observes: the entire body runs inside a subshell so any error still exits 0
# with no output.
(
  input=$(cat)

  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  [ "$tool_name" = "Bash" ] || exit 0

  command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  case "$command" in
    *gh\ pr\ create*|*gh\ pr\ view*|*gh\ pr\ edit*|*gh\ pr\ checks*|*gh\ pr\ ready*|*gh\ pr\ merge*|*gh\ pr\ comment*|*gh\ pr\ review*) ;;
    *) exit 0 ;;
  esac

  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

  if [ "${CLAUDE_PIN_PR_DEBUG:-0}" = "1" ]; then
    mkdir -p "$HOME/.cache/claude-statusline" 2>/dev/null
    printf '%s\n' "$input" >> "$HOME/.cache/claude-statusline/pin-pr.debug.log" 2>/dev/null
  fi

  # Prefer a PR URL straight out of the tool's own output — it names the exact
  # owner/repo/number without any local git state. tool_response's shape is
  # undocumented, so stringify the whole thing and grep rather than trust a key.
  response_text=$(printf '%s' "$input" | jq -r '.tool_response | tostring' 2>/dev/null)
  pin=""
  url=$(printf '%s' "$response_text" | grep -oE 'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+' | tail -1)
  if [ -n "$url" ]; then
    rest="${url#https://github.com/}"
    owner="${rest%%/*}"
    rest="${rest#*/}"
    name="${rest%%/*}"
    number="${rest##*/}"
    pin="${owner}/${name}#${number}"
  else
    # Fall back to composing from an explicit -R owner/repo plus the first bare
    # number after the gh-pr subcommand in the command string.
    owner_repo=$(printf '%s' "$command" | grep -oE -- '-R[[:space:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' | head -1 | sed -E 's/^-R[[:space:]]+//')
    number=$(printf '%s' "$command" | grep -oE 'gh pr [a-z]+.*' | grep -oE '[0-9]+' | head -1)
    if [ -n "$owner_repo" ] && [ -n "$number" ]; then
      pin="${owner_repo}#${number}"
    fi
  fi

  [ -z "$pin" ] && exit 0

  mkdir -p "$HOME/.cache/claude-statusline" 2>/dev/null
  if [ -n "$session_id" ]; then
    printf '%s' "$pin" > "$HOME/.cache/claude-statusline/session-${session_id}.pr" 2>/dev/null
  fi
  printf '%s' "$pin" > "$HOME/.cache/claude-statusline/current.pr" 2>/dev/null

  exit 0
) 2>/dev/null
exit 0
