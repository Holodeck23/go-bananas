#!/usr/bin/env bash
# Prints the "handoff buttons" (Markdown links) that open a fresh session
# already pointed at HANDOVER.md. Bash 3.2+ (macOS default) compatible.
#
# Usage: handoff-links.sh [--for claude|codex] [project-dir]

set -u

RUNTIME="claude"
DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --for) RUNTIME="${2:-claude}"; shift 2 ;;
    --for=*) RUNTIME="${1#--for=}"; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) DIR="$1"; shift ;;
  esac
done

# Works with or without the skill installed in the new session, because
# HANDOVER.md carries its own resume rules. App links fill the prompt box
# as plain text, so slash commands would not run from there.
PROMPT="Resume from HANDOVER.md in this project: read all of it and follow its resume rules."

urlencode() {
  local LC_ALL=C s="$1" out="" c i
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out="$out$c" ;;
      *) out="$out$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$DIR" && pwd))"
BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
REMOTE="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"

# owner/name from any GitHub-style remote (https, ssh, or a proxy path ending in owner/name).
SLUG=""
case "$REMOTE" in
  *github*|*/git/*)
    SLUG="$(printf '%s' "$REMOTE" | sed -E 's#\.git$##; s#/+$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#')"
    ;;
esac

# Is the branch pushed and up to date? Cloud links need it on GitHub.
PUSHED="no"
if [ -n "$BRANCH" ] && git -C "$ROOT" rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
  if [ -z "$(git -C "$ROOT" log --oneline "@{u}..HEAD" 2>/dev/null)" ]; then PUSHED="yes"; else PUSHED="behind"; fi
fi

# Uncommitted changes (other than HANDOVER.md itself) never reach a new session elsewhere.
DIRTY="$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -v ' HANDOVER.md$' | sed -E 's/^.{3}//' | head -5 | tr '\n' ' ')"

# Sessions running in a cloud container can't open local apps on the user's machine.
CLOUD="no"
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || [ -n "${CODEX_CLOUD:-}" ]; then CLOUD="yes"; fi

Q="$(urlencode "$PROMPT")"
P="$(urlencode "$ROOT")"

web_link=""
if [ -n "$SLUG" ]; then
  web_link="https://claude.ai/code/new?q=$Q&repo=$(urlencode "$SLUG")"
  [ -n "$BRANCH" ] && web_link="$web_link&branch=$(urlencode "$BRANCH")"
fi
codex_link="codex://threads/new?prompt=$Q&path=$P"
desktop_link="claude://code/new?q=$Q"
cli_link="claude-cli://open?cwd=$P&q=$(urlencode "/go-bananas resume")"

echo "### ▶️ Start the next session"
echo
if [ "$RUNTIME" = "codex" ]; then
  [ "$CLOUD" = "no" ] && echo "- [**▶ Open in the Codex app**]($codex_link)"
  echo "- Terminal: \`codex '\$go-bananas resume'\`"
  [ -n "$web_link" ] && echo "- [Open in Claude Code instead]($web_link)"
else
  [ -n "$web_link" ] && echo "- [**▶ Open in Claude Code** (web, desktop or phone)]($web_link)"
  if [ "$CLOUD" = "no" ]; then
    echo "- [Open in the Claude desktop app]($desktop_link), then pick this project's folder"
    echo "- [Open in a Claude Code terminal]($cli_link)"
  fi
  echo "- Terminal: \`claude \"/go-bananas resume\"\`"
fi
echo
if [ -n "$web_link" ] && [ "$PUSHED" != "yes" ]; then
  echo "> ⚠️ Branch \`${BRANCH:-?}\` isn't fully pushed, so a new cloud session won't see the latest work or HANDOVER.md. Push first."
  echo
fi
if [ -n "$DIRTY" ]; then
  echo "> ⚠️ Uncommitted changes (${DIRTY% }) exist only on this machine. A session opened from the claude.ai link won't see them."
  echo
fi
echo "If a button doesn't open anything, start a new session in this project and send: $PROMPT"
