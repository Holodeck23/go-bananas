#!/usr/bin/env bash
# Installs the go-bananas skill into Claude Code and/or OpenAI Codex.
# Usage: curl -fsSL https://raw.githubusercontent.com/Holodeck23/go-bananas/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/Holodeck23/go-bananas"
SKILL="go-bananas"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Use the local checkout when run from inside the repo, otherwise download it.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$SRC" ] || [ ! -d "$SRC/claude/$SKILL" ]; then
  git clone --quiet --depth 1 "$REPO" "$TMP/repo"
  SRC="$TMP/repo"
fi

installed=0
install_to() {
  local from="$1" dest="$2" label="$3"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$from" "$dest"
  echo "🍌 $label → $dest"
  installed=1
}

if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  install_to "$SRC/claude/$SKILL" "$HOME/.claude/skills/$SKILL" "Claude Code"
fi
if [ -d "$HOME/.agents" ] || [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; then
  install_to "$SRC/codex/$SKILL" "$HOME/.agents/skills/$SKILL" "OpenAI Codex"
fi

if [ "$installed" -eq 0 ]; then
  echo "Couldn't find Claude Code or Codex, so installing for Claude Code by default."
  install_to "$SRC/claude/$SKILL" "$HOME/.claude/skills/$SKILL" "Claude Code"
fi

echo "Done. Type /$SKILL (Claude Code) or \$$SKILL (Codex) at the end of a session. Bob's your uncle."
