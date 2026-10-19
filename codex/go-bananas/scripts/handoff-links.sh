#!/usr/bin/env bash
# Read-only continuation links. Bash 3.2+ (including macOS).
# Usage: handoff-links.sh [--for claude|codex] [--handover project-relative-path] [project-dir]
set -u
RUNTIME=claude
DIR=.
HANDOVER=HANDOVER.md
while [ "$#" -gt 0 ]; do
  case "$1" in
    --for|--handover)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "Missing value for $1" >&2; exit 2; }
      if [ "$1" = --for ]; then RUNTIME="$2"; else HANDOVER="$2"; fi
      shift 2 ;;
    --for=*) RUNTIME="${1#*=}"; shift ;;
    --handover=*) HANDOVER="${1#*=}"; shift ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) DIR="$1"; shift ;;
  esac
done
case "$RUNTIME" in claude|codex) ;; *) echo 'Runtime must be claude or codex' >&2; exit 2 ;; esac
case "$HANDOVER" in ''|/*|..|../*|*/../*|*/..) echo 'Use a project-relative handover path without ..' >&2; exit 2 ;; esac
HANDOVER="${HANDOVER#./}"
ROOT="$(cd -- "$DIR" && pwd -P)" || exit 1
IN_GIT=no
if GIT_ROOT="$(LC_ALL=C git -C "$ROOT" rev-parse --show-toplevel 2>&1)"; then
  ROOT="$GIT_ROOT"; IN_GIT=yes
else
  case "$GIT_ROOT" in
    *'not a git repository'*) ;;
    *) printf '%s\n' "$GIT_ROOT" >&2; exit 1 ;;
  esac
fi

urlencode() {
  local LC_ALL=C s="$1" out="" c i n
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out="$out$c" ;;
      *) printf -v n '%d' "'$c"; out="$out$(printf '%%%02X' "$((n & 255))")" ;;
    esac
  done
  printf '%s' "$out"
}

PROMPT="Resume from $HANDOVER in this project: read the whole file and follow its resume rules."
REASON=""
SLUG=""
BRANCH=""
DIRTY=""
if [ -L "$ROOT/$HANDOVER" ]; then
  REASON="The handover is a symlink; its target is not verified for cloud continuation."
elif [ ! -s "$ROOT/$HANDOVER" ]; then
  REASON="The handover is missing or empty. Save it before continuing."
fi
if [ "$IN_GIT" = yes ]; then
  BRANCH="$(git -C "$ROOT" branch --show-current)" || exit 1
  REMOTE="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  # Only exact public GitHub hosts can produce a claude.ai repo link.
  case "$REMOTE" in
    https://github.com/*) SLUG="${REMOTE#https://github.com/}" ;;
    git@github.com:*) SLUG="${REMOTE#git@github.com:}" ;;
    ssh://git@github.com/*) SLUG="${REMOTE#ssh://git@github.com/}" ;;
  esac
  SLUG="${SLUG%/}"; SLUG="${SLUG%.git}"
  if ! printf '%s' "$SLUG" | LC_ALL=C grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then SLUG=""; fi
  DIRTY="$(git -C "$ROOT" status --porcelain --untracked-files=normal)" || exit 1
  if [ -z "$REASON" ]; then
    if ! git -C "$ROOT" ls-files --error-unmatch -- "$HANDOVER" >/dev/null 2>&1 ||
       ! git -C "$ROOT" cat-file -e "HEAD:$HANDOVER" 2>/dev/null; then
      REASON="The handover is not committed; a cloud session cannot read it."
    elif ! git -C "$ROOT" diff --quiet HEAD -- "$HANDOVER"; then
      REASON="The handover has uncommitted changes; the remote copy is stale."
    elif [ -n "$DIRTY" ]; then
      REASON="Uncommitted changes exist only here; checkpoint the required work first."
    elif [ -z "$BRANCH" ]; then
      REASON="Detached HEAD has no branch to open in the cloud."
    elif [ -z "$SLUG" ]; then
      REASON="No supported GitHub origin; use local or copyable continuation."
    else
      HEAD_OID="$(git -C "$ROOT" rev-parse HEAD)" || exit 1
      # Read the exact link destination, not a possibly stale/different upstream.
      # Disable interactive credential prompts; do not retry a failed inspection.
      if REMOTE_LINE="$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes -oConnectTimeout=10' git -C "$ROOT" -c credential.interactive=false ls-remote --exit-code origin "refs/heads/$BRANCH" 2>/dev/null)"; then
        REMOTE_OID="${REMOTE_LINE%%[[:space:]]*}"
        if [ "$REMOTE_OID" != "$HEAD_OID" ]; then
          REASON="The live origin branch differs from HEAD; cloud readiness is unverified."
        fi
      else
        REASON="Could not verify the live origin branch (missing branch, network or access). No retry was made."
      fi
    fi
  fi
elif [ -z "$REASON" ]; then
  REASON="This is not a Git repository; the handover is local only."
fi

CLOUD=no
if [ "${CLAUDE_CODE_REMOTE:-}" = true ] || [ -n "${CODEX_CLOUD:-}" ]; then CLOUD=yes; fi
Q="$(urlencode "$PROMPT")"
P="$(urlencode "$ROOT")"
WEB=""
if [ -z "$REASON" ]; then
  WEB="https://claude.ai/code/new?q=$Q&repo=$(urlencode "$SLUG")&branch=$(urlencode "$BRANCH")"
fi
printf '### ▶️ Continue in a new session\n\n'
if [ "$RUNTIME" = claude ] && [ -n "$WEB" ]; then
  printf '%s\n' "- [Open in Claude Code]($WEB)"
fi
if [ "$CLOUD" = no ] && [ -s "$ROOT/$HANDOVER" ]; then
  if [ "$RUNTIME" = codex ]; then
    printf '%s\n' "- [Open in the Codex app](codex://threads/new?prompt=$Q&path=$P)"
  else
    printf '%s\n' "- [Open in Claude desktop](claude://code/new?q=$Q), then select this project folder"
    printf '%s\n' "- [Open a Claude Code terminal](claude-cli://open?cwd=$P&q=$Q)"
  fi
  printf -- '- Terminal (on this computer): `cd -- %q && %s %q`\n' "$ROOT" "$RUNTIME" "$PROMPT"
fi
if [ "$RUNTIME" = codex ] && [ -n "$WEB" ]; then
  printf '%s\n' "- [Open in Claude Code instead]($WEB)"
fi
if [ -n "$REASON" ]; then printf '\n> ⚠️ Cloud continuation unavailable: %s\n' "$REASON"; fi
if [ -n "$DIRTY" ]; then
  printf '\n> Local changes (including the handover) do not travel automatically. Inspect `git status --short`.\n'
fi
printf '\nLinks prefill a prompt; opening and successful resume still need verification.\n'
printf '\nFallback: open the intended project and send: %s\n' "$PROMPT"
printf 'If the file is unavailable there, paste the full handover instead.\n'
