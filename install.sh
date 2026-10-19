#!/usr/bin/env bash
# Installs the go-bananas skill into Claude Code and/or OpenAI Codex.
# Usage: curl -fsSL https://raw.githubusercontent.com/Holodeck23/go-bananas/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/Holodeck23/go-bananas"
SKILLS="go-bananas gb"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Use the local checkout when run from inside the repo, otherwise download it.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$SRC" ] || [ ! -d "$SRC/claude/go-bananas" ]; then
  git clone --quiet --depth 1 "$REPO" "$TMP/repo"
  SRC="$TMP/repo"
fi

installed=0
install_to() {
  local runtime="$1" dest="$2" label="$3" skill
  mkdir -p "$dest"
  for skill in $SKILLS; do
    rm -rf "$dest/$skill"
    cp -R "$SRC/$runtime/$skill" "$dest/$skill"
  done
  echo "🍌 $label → $dest/{${SKILLS// /,}}"
  installed=1
}

if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  install_to claude "$HOME/.claude/skills" "Claude Code"
fi
if [ -d "$HOME/.agents" ] || [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; then
  install_to codex "$HOME/.agents/skills" "OpenAI Codex"
fi

if [ "$installed" -eq 0 ]; then
  echo "Couldn't find Claude Code or Codex, so installing for Claude Code by default."
  install_to claude "$HOME/.claude/skills" "Claude Code"
fi

echo "Done. At the end of a session just type GB. Bob's your uncle."
