#!/bin/bash
# Claude Code status line, styled to match this machine's Powerlevel10k prompt.
#
# Palette and glyphs are lifted from ~/.p10k.zsh (-> Github/dotfiles/p10k/.p10k.zsh)
# so this reads as the same prompt rather than a lookalike:
#
#   POWERLEVEL9K_DIR_BACKGROUND=4                        dir block, blue
#   POWERLEVEL9K_DIR_FOREGROUND=254                      dir text
#   POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=255, ANCHOR_BOLD  last component
#   POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2                  git block, green when clean
#   POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3               yellow when dirty
#   POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=2, UNTRACKED_ICON='?'
#   POWERLEVEL9K_VCS_BRANCH_ICON=U+F126
#   POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=U+E0B0    (left prompt, points right)
#   POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=U+E0B2   (right prompt, points left)
#   POWERLEVEL9K_MODE=nerdfont-complete   (so E0B0 / E0B2 / F126 actually render)
#
# Layout mirrors p10k's two-sided prompt: dir + vcs on the left, context window on
# the right, padded apart to the terminal width. p10k's own left prompt is
# dir + vcs + prompt_char with no user@host, so this drops the user@host the plain
# AGENT_MODE zsh PROMPT had — keeping it would not look like p10k.
#
# The context block has no p10k counterpart, so it borrows the VCS colour
# convention: grey normally, yellow past 60%, red past 85% — the same
# clean/modified/warning idiom already in use above.
#
# Written for bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile.

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd=$(pwd)
# The tilde replacement has to come from a VARIABLE, and both obvious spellings are
# wrong in one shell or the other — verified in both:
#   ${cwd/#$HOME/~}   bash 5 tilde-expands it back to $HOME, so the path is
#                     substituted with itself and the collapse silently does nothing
#   ${cwd/#$HOME/\~}  bash 3.2 (/bin/bash on macOS) keeps the backslash literally
#                     and prints \~/Github/...
# settings.json invokes plain `bash`, so which one runs is PATH-dependent and this
# must be correct under both.
tilde="~"
dir="${cwd/#$HOME/$tilde}"

ESC=$(printf '\033')
SEP=$(printf '\xee\x82\xb0')    # U+E0B0 points right, for the left side
RSEP=$(printf '\xee\x82\xb2')   # U+E0B2 points left, for the right side
GIT=$(printf '\xef\x84\xa6')    # U+F126 nerd-font git branch

fg() { printf '%s[38;5;%sm' "$ESC" "$1"; }
bg() { printf '%s[48;5;%sm' "$ESC" "$1"; }
bold() { printf '%s[1m' "$ESC"; }
reset() { printf '%s[0m' "$ESC"; }

# Columns each nerd-font glyph occupies. All three (E0B0, E0B2, F126) are Private
# Use Area with east_asian_width=Ambiguous, which Ghostty — like most terminals —
# renders DOUBLE width. Counting them as 1 made the computed line ~4 columns
# narrower than reality (2 left separators + branch glyph + 1 right separator), the
# line overflowed, and Claude Code truncated it: "ctx 4…". Over-counting is the safe
# direction — if a font renders them single width the right block just sits a few
# columns inside the edge instead of being cut off.
GW=${CLAUDE_STATUSLINE_GLYPH_W:-2}
# Extra columns held back from the right edge. Raise this if the right block still
# gets clipped; the cost of a larger value is only a slightly bigger right margin.
MARGIN=${CLAUDE_STATUSLINE_MARGIN:-2}

# Segment tables. Widths are tracked EXPLICITLY as integers rather than measured
# from the strings: the text carries ANSI escapes (invisible) and multibyte
# nerd-font glyphs, and ${#s} is unreliable for those under bash 3.2. Each width
# below counts visible columns only, with glyphs at $GW.
l_bg=(); l_tx=(); l_w=()
r_bg=(); r_tx=(); r_w=()
add_l() { l_bg[${#l_bg[@]}]="$1"; l_tx[${#l_tx[@]}]="$2"; l_w[${#l_w[@]}]="$3"; }
add_r() { r_bg[${#r_bg[@]}]="$1"; r_tx[${#r_tx[@]}]="$2"; r_w[${#r_w[@]}]="$3"; }

# ---- left: dir (parent in 254, last component bold 255, per DIR_ANCHOR_BOLD)
if [ "$dir" = "/" ] || [ "$dir" = "~" ]; then
  dir_txt="$(bold)$(fg 255)${dir}"
else
  parent="${dir%/*}"
  leaf="${dir##*/}"
  dir_txt="$(fg 254)${parent}/$(bold)$(fg 255)${leaf}"
fi
add_l 4 "$dir_txt" ${#dir}

# ---- left: git branch + dirty/untracked markers. Cheap by design — rev-parse,
# branch --show-current and status --porcelain are all working-tree-only, no
# history walk, and --no-optional-locks keeps concurrent git work unblocked.
pr_branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ] && command -v git >/dev/null 2>&1; then
  if git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
      sha=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
      [ -n "$sha" ] && branch="detached@$sha"
    fi
    if [ -n "$branch" ]; then
      porcelain=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)
      marks=""
      gbg=2
      if [ -n "$porcelain" ]; then
        # tracked modifications turn the block yellow, as VCS_MODIFIED_BACKGROUND does
        if printf '%s\n' "$porcelain" | grep -qvE '^(\?\?|$)'; then
          gbg=3
          marks="*"
        fi
        # untracked keeps the clean background and adds '?', per VCS_UNTRACKED_ICON
        printf '%s\n' "$porcelain" | grep -qE '^\?\?' && marks="${marks}?"
      fi
      gtext="${branch}${marks}"
      # width: branch glyph + space + text
      add_l "$gbg" "$(fg 0)${GIT} ${gtext}" $((GW + 1 + ${#gtext}))
      pr_branch="$branch"
    fi
  fi
fi

# ---- left: PR status, right after the git block. This talks to GitHub
# (`gh pr view`), which is a network call — never allowed to block a status line
# that renders on every keystroke. So the render path here ONLY reads a cache
# file; it never calls `gh` itself. If the cache is missing or older than the
# TTL, a background refresh is kicked off (detached, lock-guarded so concurrent
# renders don't pile up `gh` calls) and this render still completes immediately
# with whatever is already cached (or nothing).
#
# The cwd is usually the MAIN checkout, but the PR being worked tends to live in
# a worktree on another branch — keying purely on cwd's branch would show
# nothing in that common case. So a "hint file" takes precedence when present:
#   ~/.cache/claude-statusline/session-<session_id>.pr   (per Claude session)
#   ~/.cache/claude-statusline/current.pr                (global fallback)
# Each is a single line "owner/repo#number" written by hand (or by tooling) to
# pin the segment to a PR outside the cwd; clear it by deleting the file. If no
# hint file exists, the segment falls back to inferring number/repo from the
# cwd's current branch instead.
if [ "${CLAUDE_STATUSLINE_PR:-1}" != "0" ] && command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  pr_ttl=${CLAUDE_STATUSLINE_PR_TTL:-60}
  pr_cache_dir="$HOME/.cache/claude-statusline"
  mkdir -p "$pr_cache_dir" 2>/dev/null

  pr_hint=""
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  if [ -n "$session_id" ] && [ -f "${pr_cache_dir}/session-${session_id}.pr" ]; then
    pr_hint=$(cat "${pr_cache_dir}/session-${session_id}.pr" 2>/dev/null)
  fi
  if [ -z "$pr_hint" ] && [ -f "${pr_cache_dir}/current.pr" ]; then
    pr_hint=$(cat "${pr_cache_dir}/current.pr" 2>/dev/null)
  fi
  # Trim surrounding whitespace, then validate the "owner/repo#number" shape.
  pr_hint=$(printf '%s' "$pr_hint" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  case "$pr_hint" in
    */*#*[0-9])
      pr_owner_repo="${pr_hint%%#*}"
      pr_number="${pr_hint##*#}"
      case "$pr_number" in *[!0-9]*|'') pr_hint="" ;; esac
      ;;
    *) pr_hint="" ;;
  esac

  pr_key=""
  pr_view_args=""
  if [ -n "$pr_hint" ]; then
    pr_key="$pr_hint"
    pr_view_args="$pr_number -R $pr_owner_repo"
  elif [ -n "$cwd" ] && [ -d "$cwd" ] && command -v git >/dev/null 2>&1; then
    pr_root=$(git --no-optional-locks -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$pr_root" ] && [ -n "$pr_branch" ]; then
      pr_key="${pr_root}|${pr_branch}"
    fi
  fi

  if [ -n "$pr_key" ]; then
    pr_hash=$(printf '%s' "$pr_key" | shasum 2>/dev/null | cut -c1-16)
    if [ -z "$pr_hash" ]; then
      pr_hash=$(printf '%s' "$pr_key" | md5 2>/dev/null | cut -c1-16)
    fi

    if [ -n "$pr_hash" ]; then
      pr_cache="${pr_cache_dir}/pr-${pr_hash}.json"
      pr_lock="${pr_cache}.lock"

      pr_age=999999
      if [ -f "$pr_cache" ]; then
        pr_mtime=$(stat -f %m "$pr_cache" 2>/dev/null || stat -c %Y "$pr_cache" 2>/dev/null)
        now=$(date +%s)
        [ -n "$pr_mtime" ] && pr_age=$((now - pr_mtime))
      fi

      if [ ! -f "$pr_cache" ] || [ "$pr_age" -ge "$pr_ttl" ]; then
        # Stale lock (>120s) means a previous refresh died without cleaning up;
        # treat it as gone rather than blocking refreshes forever.
        lock_stale=1
        if [ -d "$pr_lock" ]; then
          lock_mtime=$(stat -f %m "$pr_lock" 2>/dev/null || stat -c %Y "$pr_lock" 2>/dev/null)
          lock_now=$(date +%s)
          if [ -n "$lock_mtime" ] && [ $((lock_now - lock_mtime)) -lt 120 ]; then
            lock_stale=0
          fi
        fi
        if [ ! -d "$pr_lock" ] || [ "$lock_stale" -eq 1 ]; then
          (
            if mkdir "$pr_lock" 2>/dev/null; then
              pr_tmp="${pr_cache}.tmp.$$"
              if [ -n "$pr_view_args" ]; then
                pr_json=$(gh pr view $pr_view_args --json number,isDraft,reviewDecision,statusCheckRollup 2>/dev/null)
              else
                pr_json=$(cd "$cwd" 2>/dev/null && gh pr view --json number,isDraft,reviewDecision,statusCheckRollup 2>/dev/null)
              fi
              if [ -n "$pr_json" ]; then
                printf '%s' "$pr_json" > "$pr_tmp" 2>/dev/null && mv "$pr_tmp" "$pr_cache" 2>/dev/null
              else
                printf '{"none":true}' > "$pr_tmp" 2>/dev/null && mv "$pr_tmp" "$pr_cache" 2>/dev/null
              fi
              rmdir "$pr_lock" 2>/dev/null
            fi
          ) >/dev/null 2>&1 &
          disown 2>/dev/null
        fi
      fi

      if [ -f "$pr_cache" ]; then
        pr_render=$(jq -r '
          if .none then
            ""
          else
            ((.statusCheckRollup // []) | map((.conclusion|select(.!="")) // .state // .status // "PENDING")) as $states |
            ($states | map(select(. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED")) | length) as $passed |
            ($states | map(select(. == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE")) | length) as $failed |
            ($states | map(select((. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED" or . == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") | not)) | length) as $pending |
            (if .reviewDecision == "APPROVED" then "✔"
             elif .reviewDecision == "CHANGES_REQUESTED" then "✎"
             else "" end) as $decision |
            ((if .isDraft then "draft " else "" end)
              + "#" + (.number|tostring)
              + " ✓" + ($passed|tostring)
              + (if $failed > 0 then " ✗" + ($failed|tostring) else "" end)
              + (if $pending > 0 then " …" + ($pending|tostring) else "" end)
              + (if $decision != "" then " " + $decision else "" end)
            ) as $text |
            (if $failed > 0 then 1 elif $pending > 0 then 3 else 2 end) as $bg |
            (if .isDraft then 8 else $bg end) as $finalbg |
            (if .isDraft then 254 elif $bg == 1 then 255 else 0 end) as $finalfg |
            ($finalbg|tostring) + "" + ($finalfg|tostring) + "" + $text
          end
        ' "$pr_cache" 2>/dev/null)
        if [ -n "$pr_render" ]; then
          pr_bg="${pr_render%%$(printf '\001')*}"
          pr_rest="${pr_render#*$(printf '\001')}"
          pr_fg="${pr_rest%%$(printf '\001')*}"
          pr_text="${pr_rest#*$(printf '\001')}"
          if [ -n "$pr_bg" ] && [ -n "$pr_text" ]; then
            add_l "$pr_bg" "$(fg "$pr_fg")${pr_text}" ${#pr_text}
          fi
        fi
      fi
    fi
  fi
fi

# ---- right: active model. Ordered before the context block so it renders to the
# LEFT of it. This is the one thing Claude Code's built-in status line showed that
# the p10k-derived one did not; there is no p10k counterpart, so magenta was chosen
# simply as a hue the prompt does not already use (4 blue = dir, 2/3 = vcs,
# 8/3/1 = ctx). display_name is used verbatim rather than reformatted — it is what
# Claude Code itself calls the model, e.g. "Opus 5 (1M context)".
#
# Also available in the payload if you ever want them here: effort.level ("high"),
# thinking.enabled, fast_mode, output_style.name, session_name.
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // empty' 2>/dev/null)
if [ -n "$model" ]; then
  add_r 5 "$(fg 255)${model}" ${#model}
fi

# ---- right: context window, read straight off the pre-computed field (verified
# present in the real payload as context_window.used_percentage). Omitted entirely
# when absent — e.g. no messages yet — rather than reported as 0%.
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used" 2>/dev/null)
  if [ -n "$pct" ]; then
    if [ "$pct" -ge 85 ]; then cbg=1; cfg=255
    elif [ "$pct" -ge 60 ]; then cbg=3; cfg=0
    else cbg=8; cfg=254; fi
    ctext="ctx ${pct}%"
    add_r "$cbg" "$(fg $cfg)${ctext}" ${#ctext}
  fi
fi

# ---- render left: block, then a separator carrying this block's bg as its fg so
# the triangle blends into the next block (or into the terminal at the end).
left=""
lw=0
n=${#l_bg[@]}
i=0
while [ $i -lt $n ]; do
  left="${left}$(bg "${l_bg[$i]}") ${l_tx[$i]} $(reset)"
  lw=$((lw + 1 + ${l_w[$i]} + 1))
  nxt=$((i + 1))
  if [ $nxt -lt $n ]; then
    left="${left}$(fg "${l_bg[$i]}")$(bg "${l_bg[$nxt]}")${SEP}$(reset)"
  else
    left="${left}$(fg "${l_bg[$i]}")${SEP}$(reset)"
  fi
  lw=$((lw + GW))
  i=$nxt
done

# ---- render right: separator FIRST, pointing left, carrying this block's colour as
# its foreground. For every block after the first, that separator also has to sit on
# the PREVIOUS block's background — otherwise the triangle is drawn over the terminal
# default and a stripe of unstyled background shows between two adjacent right blocks.
right=""
rw=0
m=${#r_bg[@]}
i=0
while [ $i -lt $m ]; do
  if [ $i -gt 0 ]; then
    prev=$((i - 1))
    right="${right}$(fg "${r_bg[$i]}")$(bg "${r_bg[$prev]}")${RSEP}$(reset)"
  else
    right="${right}$(fg "${r_bg[$i]}")${RSEP}$(reset)"
  fi
  right="${right}$(bg "${r_bg[$i]}") ${r_tx[$i]} $(reset)"
  rw=$((rw + GW + 1 + ${r_w[$i]} + 1))
  i=$((i + 1))
done

# ---- pad the two apart. COLUMNS is exported into this script's environment
# (verified: 215 under Ghostty); tput is the fallback. /dev/tty is NOT available
# here, so anything reading from it silently returns nothing — do not rely on it.
cols="${COLUMNS:-}"
case "$cols" in *[!0-9]*|'') cols=$(tput cols 2>/dev/null) ;; esac
case "$cols" in *[!0-9]*|'') cols=0 ;; esac

# Hold back MARGIN columns so a full-width line is never clipped or wrapped.
gap=$((cols - lw - rw - MARGIN))
if [ "$m" -eq 0 ]; then
  printf '%s' "$left"
elif [ "$cols" -lt 40 ] || [ "$gap" -lt 1 ]; then
  # Unknown or cramped width: fall back to inline rather than risk a wrapped line.
  printf '%s%s' "$left" "$right"
else
  pad=$(printf "%${gap}s" "")
  printf '%s%s%s' "$left" "$pad" "$right"
fi
