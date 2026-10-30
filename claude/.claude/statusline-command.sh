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

# ---- F: one jq pass for the whole payload instead of four separate ones
# (cwd, model, used_percentage, session_id each used to spawn their own `jq`).
# A non-whitespace separator preserves empty fields with Bash read.
pr_payload_tsv=$(printf '%s' "$input" | jq -r '[.workspace.current_dir // .cwd // "", .model.display_name // .model.id // "", (.context_window.used_percentage // "" | tostring), .session_id // ""] | @tsv' 2>/dev/null | tr '\t' '\037')
IFS=$'\037' read -r cwd model used session_id <<EOF
$pr_payload_tsv
EOF
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

# ---- left: git branch + dirty/untracked markers. Cheap by design: no history
# walk, and --no-optional-locks keeps concurrent git work unblocked. Finding the
# branch avoids spawning `git` at all in the common case — .git/HEAD (or, for a
# worktree, the file it points at) is read directly; `git branch --show-current`
# is only a fallback if that file read fails for any reason, so nothing
# regresses. The one `git` spawn this segment shares with the PR segment below
# (step E) does the toplevel + remote-branch-existence check; a second spawn
# (`git status --porcelain`) supplies the dirty/untracked markers. Two `git`
# calls total per render, was up to four before this pass.
pr_branch=""
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  gitref=""
  walk="$cwd"
  while [ -n "$walk" ] && [ "$walk" != "/" ]; do
    if [ -d "$walk/.git" ]; then
      gitref="$walk/.git/HEAD"
      break
    elif [ -f "$walk/.git" ]; then
      # Worktree: .git is a file containing "gitdir: <path>".
      gitdir=$(sed -n 's/^gitdir: //p' "$walk/.git" 2>/dev/null)
      [ -n "$gitdir" ] && gitref="$gitdir/HEAD"
      break
    fi
    walk="${walk%/*}"
  done
  if [ -n "$gitref" ] && [ -f "$gitref" ]; then
    headline=$(sed -n '1p' "$gitref" 2>/dev/null)
    case "$headline" in
      "ref: refs/heads/"*) branch="${headline#ref: refs/heads/}" ;;
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
        branch="detached@${headline%${headline#?????????}}" ;;
    esac
  fi
  # Fallback: file-based lookup found nothing usable — ask git directly.
  if [ -z "$branch" ] && command -v git >/dev/null 2>&1; then
    branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
      sha=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
      [ -n "$sha" ] && branch="detached@$sha"
    fi
  fi
  if [ -n "$branch" ] && command -v git >/dev/null 2>&1; then
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

# ---- left: PR status, right after the git block. This talks to GitHub via a
# single `gh api graphql` call — never allowed to block a status line that
# renders on every keystroke. So the render path here ONLY reads a cache file;
# it never calls `gh` itself. If the cache is missing or stale, a background
# refresh is kicked off (detached, lock-guarded so concurrent renders don't
# pile up `gh` calls) and this render still completes immediately with
# whatever is already cached (or nothing).
#
# ---- A: one GraphQL query, normalized cache. The query fetches everything the
# segment can ever show in ONE call (cost 1 rate-limit point, verified live):
# state/isDraft/reviewDecision/mergeable/headRefName/headRefOid/url, unresolved
# review-thread count, and the check-run/status-context rollup. Hint mode asks
# for a specific `repository.pullRequest(number:)`; cwd mode asks for
# `pullRequests(headRefName:, states:[OPEN,MERGED,CLOSED])` and picks the first
# OPEN node, else the first node (most-recently-updated non-open PR). owner/repo
# for cwd mode come from `git config --get remote.origin.url`, parsed for the
# https/ssh/scp GitHub forms — this git spawn happens ONLY inside the detached
# background refresh, never in the render path. The refresh normalizes the raw
# GraphQL response into a fixed schema so the render pass only needs one
# trivial jq read, not the whole per-context-node classification:
#   {"v":1,"fetchedAt":<epoch>,"none":<bool>,"error":<null|string>,
#    "failures":<int>,"pr":null|{number,state,isDraft,reviewDecision,mergeable,
#    headRefName,headRefOid,url,unresolvedThreads,passed,failed,pending}}
# Check-node classification: a CheckRun counts as pending unless
# status=="COMPLETED", in which case its `conclusion` is used; a StatusContext
# always uses its `state`. passed = SUCCESS/NEUTRAL/SKIPPED, failed =
# FAILURE/ERROR/CANCELLED/TIMED_OUT/ACTION_REQUIRED/STARTUP_FAILURE, pending =
# anything else (including null/QUEUED/IN_PROGRESS/EXPECTED).
#
# ---- B: stale-while-error with backoff. A `gh` failure (non-zero exit, empty
# output, or a GraphQL `.errors` array) does NOT clobber a good cache: the
# previous `none`/`pr` are kept, `error` is set to the first line of stderr or
# GraphQL error message (capped 120 chars), and `failures` increments. Only a
# SUCCESSFUL query can ever set `none:true` — errors never do, so a transient
# API hiccup can't make a real PR disappear from the segment. Success resets
# `failures` to 0 and `error` to null. While `error` is set the refresh backs
# off exponentially: min(active_ttl * 2^failures, 1800).
#
# ---- C: TTL policy (computed in the render path's precheck, before deciding
# whether to spawn a refresh):
#   none (cwd mode only — the remote-branch gate below already rules out the
#     no-remote case): active TTL, since a PR could be opened any moment.
#   OPEN, pending > 0: active TTL. OPEN, pending == 0: settled TTL.
#   CLOSED: settled TTL. MERGED: 315360000s (effectively never) — only a
#     forced refresh (hint mtime newer, or a cache-key change) re-fetches it.
#   error set: min(active_ttl * 2^failures, 1800), overriding the state-based
#     TTL above.
# Auto-unpin (hint mode only): if the cached PR is MERGED or CLOSED and
# `fetchedAt` is older than CLAUDE_STATUSLINE_PR_UNPIN seconds (default 600),
# the hint file that produced this pin (session file or current.pr) is
# deleted, and this SAME render falls through to cwd-branch mode instead — a
# merged/closed pin doesn't linger once its render has had time to be seen.
#
# ---- D: rendering. OPEN keeps the existing "#N ✓p ✗f …q" + reviewDecision
# glyph (✔ approved / ✎ changes requested), plus: ⚡ when mergeable ==
# CONFLICTING (after the counts, before the decision glyph), and ✉<n> when
# unresolvedThreads > 0 (after ⚡). MERGED renders "#N merged" on bg 5 fg 255;
# CLOSED renders "#N closed" on bg 8 fg 254. The draft prefix/colour rule is
# unchanged and only applies to OPEN. When `error` is set: if a `pr` is still
# cached, it renders normally with a trailing " ~" stale marker; if `pr` is
# null, hint mode shows "#N ~" on bg 8 fg 254 (using the hint's own PR number,
# since nothing was ever fetched) and cwd mode shows nothing (there is no
# number to anchor a stale marker to). All new glyphs (⚡ ✉ ~) are ordinary
# UTF-8, not nerd-font PUA, so — like ✔/✎/✓/✗/… already were — they count as 1
# column each; segment width is simply the rendered text's character count.
#
# ---- E: push awareness / git-spawn budget. This segment and the git-branch
# segment above share ONE `git rev-parse` call for the toplevel + remote-branch
# check: `git --no-optional-locks -C "$cwd" rev-parse --show-toplevel
# "refs/remotes/origin/${branch}^{commit}"` (plus a 3rd ref, the hint's
# headRefName on origin, when a hint cache with a headRefName exists — read
# BEFORE this call so it can be included). `--short` is never combined with
# multiple revisions here (a prior pass found that breaks rev-parse entirely on
# this git version — "Needed a single revision" — instead of resolving each
# independently); short shas are taken as 9-char bash substrings of the full
# hex output. Same hex-shape validation as before distinguishes a resolved sha
# from rev-parse's literal echo of an unresolved ref.
#   cwd mode cache key: root|branch|<remote sha> — replacing the local-HEAD key
#     from the previous pass, so unpushed local commits no longer force a
#     refresh (only a push/fetch that moves the remote ref does).
#   hint mode: if the remote sha for the hint's headRefName resolves AND
#     differs from the cached pr.headRefOid AND differs from the last-seen sha
#     recorded in `<cache>.seen`, a refresh is forced and the new sha is
#     written to `<cache>.seen` (a tiny write, only on change). Worktrees share
#     refs, so a push from ANY worktree updates a pinned PR immediately.
if [ "${CLAUDE_STATUSLINE_PR:-1}" != "0" ] && command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  pr_ttl_active=${CLAUDE_STATUSLINE_PR_TTL:-60}
  pr_ttl_settled=${CLAUDE_STATUSLINE_PR_TTL_SETTLED:-600}
  pr_ttl_merged=315360000
  pr_unpin_after=${CLAUDE_STATUSLINE_PR_UNPIN:-600}
  pr_cache_dir="$HOME/.cache/claude-statusline"
  mkdir -p "$pr_cache_dir" 2>/dev/null

  # The cwd is usually the MAIN checkout, but the PR being worked tends to live
  # in a worktree on another branch — keying purely on cwd's branch would show
  # nothing in that common case. So a "hint file" takes precedence when
  # present:
  #   ~/.cache/claude-statusline/session-<session_id>.pr   (per Claude session)
  #   ~/.cache/claude-statusline/current.pr                (global fallback)
  # Each is a single line "owner/repo#number" written by hand (or by the
  # pin-pr.sh hook — step G) to pin the segment to a PR outside the cwd; clear
  # it by deleting the file. If no hint file exists (or it was auto-unpinned,
  # step C), the segment falls back to inferring owner/repo/PR from the cwd's
  # current branch instead.
  pr_hint=""
  pr_hint_file=""
  if [ -n "$session_id" ] && [ -f "${pr_cache_dir}/session-${session_id}.pr" ]; then
    pr_hint=$(cat "${pr_cache_dir}/session-${session_id}.pr" 2>/dev/null)
    pr_hint_file="${pr_cache_dir}/session-${session_id}.pr"
  fi
  if [ -z "$pr_hint" ] && [ -f "${pr_cache_dir}/current.pr" ]; then
    pr_hint=$(cat "${pr_cache_dir}/current.pr" 2>/dev/null)
    pr_hint_file="${pr_cache_dir}/current.pr"
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
  [ -z "$pr_hint" ] && pr_hint_file=""

  # If hint mode: read its cache now (before the git call) so a cached
  # headRefName can ride the same rev-parse as the remote-branch check.
  pr_hint_hash=""
  pr_hint_cache=""
  pr_hint_head_ref=""
  pr_hint_head_oid=""
  pr_hint_state=""
  pr_hint_fetched_at=""
  if [ -n "$pr_hint" ]; then
    pr_hint_hash=$(printf '%s' "$pr_hint" | shasum 2>/dev/null | cut -c1-16)
    [ -z "$pr_hint_hash" ] && pr_hint_hash=$(printf '%s' "$pr_hint" | md5 2>/dev/null | cut -c1-16)
    if [ -n "$pr_hint_hash" ]; then
      pr_hint_cache="${pr_cache_dir}/pr-${pr_hint_hash}.json"
      if [ -f "$pr_hint_cache" ]; then
        pr_hint_fields=$(jq -r '
          [(.pr.headRefName // ""), (.pr.headRefOid // ""), (.pr.state // ""), (.fetchedAt // 0 | tostring)] | @tsv
        ' "$pr_hint_cache" 2>/dev/null | tr '\t' '\037')
        IFS=$'\037' read -r pr_hint_head_ref pr_hint_head_oid pr_hint_state pr_hint_fetched_at <<EOF
$pr_hint_fields
EOF
      fi
    fi
  fi

  # ---- Auto-unpin (step C): a MERGED/CLOSED pin older than the unpin window
  # deletes its own hint file and falls through to cwd mode for THIS render.
  if [ -n "$pr_hint_file" ] && [ -n "$pr_hint_state" ]; then
    case "$pr_hint_state" in
      MERGED|CLOSED)
        now_unpin=$(date +%s)
        age_unpin=999999
        [ -n "$pr_hint_fetched_at" ] && age_unpin=$((now_unpin - pr_hint_fetched_at))
        if [ "$age_unpin" -ge "$pr_unpin_after" ]; then
          rm -f "$pr_hint_file" 2>/dev/null
          pr_hint=""
          pr_hint_file=""
          pr_hint_hash=""
          pr_hint_cache=""
          pr_hint_head_ref=""
        fi
        ;;
    esac
  fi

  # ---- E: the shared git call — toplevel + remote-branch check (+ hint's
  # remote head, if any).
  pr_key=""
  pr_view_owner=""
  pr_view_name=""
  pr_view_number=""
  pr_mode=""
  pr_root=""
  pr_remote_sha=""
  pr_hint_remote_sha=""
  if [ -n "$cwd" ] && [ -d "$cwd" ] && command -v git >/dev/null 2>&1 && { [ -n "$pr_hint" ] || [ -n "$pr_branch" ]; }; then
    if [ -n "$pr_hint" ] && [ -n "$pr_hint_head_ref" ]; then
      pr_rev_out=$(git --no-optional-locks -C "$cwd" rev-parse --show-toplevel "refs/remotes/origin/${pr_branch:-__no_branch__}^{commit}" "refs/remotes/origin/${pr_hint_head_ref}^{commit}" 2>/dev/null)
    else
      pr_rev_out=$(git --no-optional-locks -C "$cwd" rev-parse --show-toplevel "refs/remotes/origin/${pr_branch:-__no_branch__}^{commit}" 2>/dev/null)
    fi
    pr_root=$(printf '%s\n' "$pr_rev_out" | sed -n '1p')
    pr_line2=$(printf '%s\n' "$pr_rev_out" | sed -n '2p')
    pr_line3=$(printf '%s\n' "$pr_rev_out" | sed -n '3p')
    case "$pr_line2" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
        pr_remote_sha="$pr_line2" ;;
    esac
    if [ -n "$pr_hint" ] && [ -n "$pr_hint_head_ref" ]; then
      case "$pr_line3" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
          pr_hint_remote_sha="$pr_line3" ;;
      esac
    fi
  fi

  if [ -n "$pr_hint" ]; then
    pr_mode="hint"
    pr_view_owner="${pr_hint%%/*}"
    pr_rest_hint="${pr_hint#*/}"
    pr_view_name="${pr_rest_hint%%#*}"
    pr_view_number="$pr_number"
    pr_key="$pr_hint"
  elif [ -n "$pr_branch" ] && [ -n "$pr_remote_sha" ]; then
    # Remote branch confirmed to exist — a PR can plausibly be opened on it.
    pr_mode="cwd"
    pr_key="${pr_root}|${pr_branch}|${pr_remote_sha}"
  fi
  # (else: hint absent AND no remote branch — nothing to poll, no segment.)

  if [ -n "$pr_key" ]; then
    pr_hash=$(printf '%s' "$pr_key" | shasum 2>/dev/null | cut -c1-16)
    [ -z "$pr_hash" ] && pr_hash=$(printf '%s' "$pr_key" | md5 2>/dev/null | cut -c1-16)

    if [ -n "$pr_hash" ]; then
      pr_cache="${pr_cache_dir}/pr-${pr_hash}.json"
      pr_lock="${pr_cache}.lock"
      pr_seen="${pr_cache}.seen"

      pr_age=999999
      pr_mtime=""
      if [ -f "$pr_cache" ]; then
        pr_mtime=$(stat -c %Y "$pr_cache" 2>/dev/null || stat -f %m "$pr_cache" 2>/dev/null)
        now=$(date +%s)
        [ -n "$pr_mtime" ] && pr_age=$((now - pr_mtime))
      fi

      # ---- C: derive the TTL to apply from the cached state itself, BEFORE
      # deciding whether a refresh is due.
      pr_ttl="$pr_ttl_settled"
      if [ -f "$pr_cache" ]; then
        pr_precheck_fields=$(jq -r '
          [(.error // ""), (.failures // 0 | tostring), (.none // false | tostring),
           (.pr.state // ""), (.pr.pending // 0 | tostring)] | @tsv
        ' "$pr_cache" 2>/dev/null | tr '\t' '\037')
        IFS=$'\037' read -r pc_error pc_failures pc_none pc_state pc_pending <<EOF
$pr_precheck_fields
EOF
        if [ -n "$pc_error" ]; then
          pr_ttl=$((pr_ttl_active * (2 ** pc_failures)))
          [ "$pr_ttl" -gt 1800 ] && pr_ttl=1800
        elif [ "$pc_none" = "true" ]; then
          if [ "$pr_mode" = "cwd" ]; then pr_ttl="$pr_ttl_active"; else pr_ttl="$pr_ttl_settled"; fi
        else
          case "$pc_state" in
            MERGED) pr_ttl="$pr_ttl_merged" ;;
            CLOSED) pr_ttl="$pr_ttl_settled" ;;
            *)
              if [ "${pc_pending:-0}" -gt 0 ] 2>/dev/null; then pr_ttl="$pr_ttl_active"; else pr_ttl="$pr_ttl_settled"; fi
              ;;
          esac
        fi
      fi

      pr_stale=0
      [ ! -f "$pr_cache" ] && pr_stale=1
      [ -f "$pr_cache" ] && [ "$pr_age" -ge "$pr_ttl" ] && pr_stale=1
      # hint mode: hint file touched/rewritten after the cache forces a refresh.
      if [ -n "$pr_hint_file" ] && [ -f "$pr_hint_file" ] && [ -f "$pr_cache" ] && [ -n "$pr_mtime" ]; then
        hint_mtime=$(stat -c %Y "$pr_hint_file" 2>/dev/null || stat -f %m "$pr_hint_file" 2>/dev/null)
        if [ -n "$hint_mtime" ] && [ "$hint_mtime" -gt "$pr_mtime" ]; then
          pr_stale=1
        fi
      fi
      # hint mode (step E): the remote moved to a sha the cache/seen-file don't
      # know about yet — a push from any worktree, since refs are shared.
      if [ "$pr_mode" = "hint" ] && [ -n "$pr_hint_remote_sha" ] && [ "$pr_hint_remote_sha" != "$pr_hint_head_oid" ]; then
        pr_seen_sha=""
        [ -f "$pr_seen" ] && pr_seen_sha=$(cat "$pr_seen" 2>/dev/null)
        if [ "$pr_hint_remote_sha" != "$pr_seen_sha" ]; then
          pr_stale=1
          printf '%s' "$pr_hint_remote_sha" > "$pr_seen" 2>/dev/null
        fi
      fi

      if [ "$pr_stale" -eq 1 ]; then
        # Stale lock (>120s) means a previous refresh died without cleaning up;
        # treat it as gone rather than blocking refreshes forever.
        lock_stale=1
        if [ -d "$pr_lock" ]; then
          lock_mtime=$(stat -c %Y "$pr_lock" 2>/dev/null || stat -f %m "$pr_lock" 2>/dev/null)
          lock_now=$(date +%s)
          if [ -n "$lock_mtime" ] && [ $((lock_now - lock_mtime)) -lt 120 ]; then
            lock_stale=0
          fi
        fi
        if [ ! -d "$pr_lock" ] || [ "$lock_stale" -eq 1 ]; then
          (
            if mkdir "$pr_lock" 2>/dev/null; then
              pr_tmp="${pr_cache}.tmp.$$"
              pr_gql_err=""
              pr_gql_raw=""
              if [ "$pr_mode" = "hint" ]; then
                pr_gql_raw=$(gh api graphql -f query='
fragment PR on PullRequest {
  number state isDraft reviewDecision mergeable headRefName headRefOid url
  reviewThreads(first:100){ nodes{ isResolved } }
  commits(last:1){ nodes{ commit{ statusCheckRollup{ state contexts(first:100){ nodes{ __typename ... on CheckRun{ name status conclusion } ... on StatusContext{ context state } } } } } } }
}
query($owner:String!,$name:String!,$number:Int!){ repository(owner:$owner,name:$name){ pullRequest(number:$number){ ...PR } } }
' -f owner="$pr_view_owner" -f name="$pr_view_name" -F number="$pr_view_number" 2>&1 1>"${pr_tmp}.out")
                pr_gql_status=$?
              else
                remote_url=$(git --no-optional-locks -C "$cwd" config --get remote.origin.url 2>/dev/null)
                gh_owner=""
                gh_name=""
                case "$remote_url" in
                  https://github.com/*)
                    r="${remote_url#https://github.com/}"; r="${r%.git}"
                    gh_owner="${r%%/*}"; gh_name="${r#*/}" ;;
                  git@github.com:*)
                    r="${remote_url#git@github.com:}"; r="${r%.git}"
                    gh_owner="${r%%/*}"; gh_name="${r#*/}" ;;
                  ssh://git@github.com/*)
                    r="${remote_url#ssh://git@github.com/}"; r="${r%.git}"
                    gh_owner="${r%%/*}"; gh_name="${r#*/}" ;;
                esac
                if [ -z "$gh_owner" ] || [ -z "$gh_name" ]; then
                  pr_gql_err="unparseable remote.origin.url"
                  pr_gql_status=1
                  : > "${pr_tmp}.out"
                else
                  pr_gql_raw=$(gh api graphql -f query='
fragment PR on PullRequest {
  number state isDraft reviewDecision mergeable headRefName headRefOid url
  reviewThreads(first:100){ nodes{ isResolved } }
  commits(last:1){ nodes{ commit{ statusCheckRollup{ state contexts(first:100){ nodes{ __typename ... on CheckRun{ name status conclusion } ... on StatusContext{ context state } } } } } } }
}
query($owner:String!,$name:String!,$branch:String!){ repository(owner:$owner,name:$name){ pullRequests(headRefName:$branch, first:5, orderBy:{field:UPDATED_AT,direction:DESC}, states:[OPEN,MERGED,CLOSED]){ nodes{ ...PR } } } }
' -f owner="$gh_owner" -f name="$gh_name" -f branch="$pr_branch" 2>&1 1>"${pr_tmp}.out")
                  pr_gql_status=$?
                fi
              fi

              pr_prev_none="false"
              pr_prev_pr="null"
              if [ -f "$pr_cache" ]; then
                pr_prev_fields=$(jq -c '[(.none // false), (.pr // null)]' "$pr_cache" 2>/dev/null)
                pr_prev_none=$(printf '%s' "$pr_prev_fields" | jq -r '.[0]' 2>/dev/null)
                pr_prev_pr=$(printf '%s' "$pr_prev_fields" | jq -c '.[1]' 2>/dev/null)
              fi
              pr_prev_failures=0
              [ -f "$pr_cache" ] && pr_prev_failures=$(jq -r '.failures // 0' "$pr_cache" 2>/dev/null)
              [ -z "$pr_prev_failures" ] && pr_prev_failures=0

              pr_body=$(cat "${pr_tmp}.out" 2>/dev/null)
              pr_has_gql_errors=0
              if [ -n "$pr_body" ]; then
                pr_gql_error_msg=$(printf '%s' "$pr_body" | jq -r '(.errors[0].message // empty)' 2>/dev/null)
                [ -n "$pr_gql_error_msg" ] && pr_has_gql_errors=1
              fi

              if [ "$pr_gql_status" -ne 0 ] || [ -z "$pr_body" ] || [ "$pr_has_gql_errors" -eq 1 ]; then
                if [ -z "$pr_gql_err" ]; then
                  pr_gql_err=$(printf '%s' "$pr_gql_error_msg" | head -c 120)
                  [ -z "$pr_gql_err" ] && pr_gql_err=$(printf '%s\n' "$pr_body" | head -1 | head -c 120)
                fi
                [ -z "$pr_gql_err" ] && pr_gql_err="gh api graphql failed"
                pr_next_failures=$((pr_prev_failures + 1))
                jq -n --arg err "$pr_gql_err" --argjson failures "$pr_next_failures" \
                  --argjson none "$pr_prev_none" --argjson prv "$pr_prev_pr" \
                  --arg now "$(date +%s)" \
                  '{v:1, fetchedAt:($now|tonumber), none:$none, error:$err, failures:$failures, pr:$prv}' \
                  > "$pr_tmp" 2>/dev/null
              else
                if [ "$pr_mode" = "hint" ]; then
                  jq --arg now "$(date +%s)" '
                    .data.repository.pullRequest as $pr |
                    if $pr == null then
                      {v:1, fetchedAt:($now|tonumber), none:true, error:null, failures:0, pr:null}
                    else
                      ($pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // []) as $ctx |
                      ($ctx | map(if .__typename == "CheckRun" then (if .status != "COMPLETED" then "PENDING" else .conclusion end) else .state end)) as $states |
                      ($states | map(select(. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED")) | length) as $passed |
                      ($states | map(select(. == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE")) | length) as $failed |
                      ($states | map(select((. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED" or . == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") | not)) | length) as $pending |
                      (($pr.reviewThreads.nodes // []) | map(select(.isResolved == false)) | length) as $unresolved |
                      {v:1, fetchedAt:($now|tonumber), none:false, error:null, failures:0,
                       pr:{number:$pr.number, state:$pr.state, isDraft:$pr.isDraft, reviewDecision:$pr.reviewDecision, mergeable:$pr.mergeable, headRefName:$pr.headRefName, headRefOid:$pr.headRefOid, url:$pr.url, unresolvedThreads:$unresolved, passed:$passed, failed:$failed, pending:$pending}}
                    end
                  ' "${pr_tmp}.out" > "$pr_tmp" 2>/dev/null
                else
                  jq --arg now "$(date +%s)" '
                    ((.data.repository.pullRequests.nodes // []) as $nodes |
                     (($nodes | map(select(.state == "OPEN")) | .[0]) // $nodes[0])) as $pr |
                    if $pr == null then
                      {v:1, fetchedAt:($now|tonumber), none:true, error:null, failures:0, pr:null}
                    else
                      ($pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // []) as $ctx |
                      ($ctx | map(if .__typename == "CheckRun" then (if .status != "COMPLETED" then "PENDING" else .conclusion end) else .state end)) as $states |
                      ($states | map(select(. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED")) | length) as $passed |
                      ($states | map(select(. == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE")) | length) as $failed |
                      ($states | map(select((. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED" or . == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") | not)) | length) as $pending |
                      (($pr.reviewThreads.nodes // []) | map(select(.isResolved == false)) | length) as $unresolved |
                      {v:1, fetchedAt:($now|tonumber), none:false, error:null, failures:0,
                       pr:{number:$pr.number, state:$pr.state, isDraft:$pr.isDraft, reviewDecision:$pr.reviewDecision, mergeable:$pr.mergeable, headRefName:$pr.headRefName, headRefOid:$pr.headRefOid, url:$pr.url, unresolvedThreads:$unresolved, passed:$passed, failed:$failed, pending:$pending}}
                    end
                  ' "${pr_tmp}.out" > "$pr_tmp" 2>/dev/null
                fi
              fi
              rm -f "${pr_tmp}.out" 2>/dev/null
              if [ -s "$pr_tmp" ]; then
                mv "$pr_tmp" "$pr_cache" 2>/dev/null
              else
                rm -f "$pr_tmp" 2>/dev/null
              fi
              # Housekeeping: per-commit-sha cache keys would otherwise
              # accumulate forever — sweep anything untouched for 7+ days.
              find "$pr_cache_dir" -name 'pr-*.json' -mtime +7 -delete 2>/dev/null
              rmdir "$pr_lock" 2>/dev/null
            fi
          ) >/dev/null 2>&1 &
          disown 2>/dev/null
        fi
      fi

      if [ -f "$pr_cache" ]; then
        # ---- D: render. Emits bg\tfg\ttext — parsed with a plain tab-split
        # `read`, no raw control bytes anywhere in this file.
        pr_render=$(jq -r --arg hintnum "$pr_number" '
          (.error // "") as $err |
          (.pr // null) as $p |
          if $p == null then
            (if ($err | length) > 0 then
              (if $hintnum != "" then "8\t254\t#" + $hintnum + " ~" else "" end)
            else "" end)
          else
            ($p.state) as $state |
            (if $state == "MERGED" then
              "5\t255\t#" + ($p.number|tostring) + " merged" + (if ($err|length) > 0 then " ~" else "" end)
            elif $state == "CLOSED" then
              "8\t254\t#" + ($p.number|tostring) + " closed" + (if ($err|length) > 0 then " ~" else "" end)
            else
              ($p.passed) as $passed | ($p.failed) as $failed | ($p.pending) as $pending |
              (if $p.reviewDecision == "APPROVED" then "✔" elif $p.reviewDecision == "CHANGES_REQUESTED" then "✎" else "" end) as $decision |
              ((if $p.isDraft then "draft " else "" end)
                + "#" + ($p.number|tostring)
                + " ✓" + ($passed|tostring)
                + (if $failed > 0 then " ✗" + ($failed|tostring) else "" end)
                + (if $pending > 0 then " …" + ($pending|tostring) else "" end)
                + (if $p.mergeable == "CONFLICTING" then " ⚡" else "" end)
                + (if ($p.unresolvedThreads // 0) > 0 then " ✉" + ($p.unresolvedThreads|tostring) else "" end)
                + (if $decision != "" then " " + $decision else "" end)
                + (if ($err|length) > 0 then " ~" else "" end)
              ) as $text |
              (if $failed > 0 then 1 elif $pending > 0 then 3 else 2 end) as $bg |
              (if $p.isDraft then 8 else $bg end) as $finalbg |
              (if $p.isDraft then 254 elif $bg == 1 then 255 else 0 end) as $finalfg |
              ($finalbg|tostring) + "\t" + ($finalfg|tostring) + "\t" + $text
            end)
          end
        ' "$pr_cache" 2>/dev/null)
        if [ -n "$pr_render" ]; then
          IFS=$'\t' read -r pr_bg pr_fg pr_text <<EOF
$pr_render
EOF
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
# thinking.enabled, fast_mode, output_style.name, session_name. model/used are
# read from the single TSV parse at the top of the script (step F) now, not a
# separate jq call each.
if [ -n "$model" ]; then
  add_r 5 "$(fg 255)${model}" ${#model}
fi

# ---- right: context window, read straight off the pre-computed field (verified
# present in the real payload as context_window.used_percentage). Omitted entirely
# when absent — e.g. no messages yet — rather than reported as 0%.
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
