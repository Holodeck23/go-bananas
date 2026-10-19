#!/usr/bin/env bash
# Checks the handoff-button script against throwaway git repos.
# Run from the repo root: bash tests/handoff-links.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/src/scripts/handoff-links.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
check() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "ok   - $1"; else echo "FAIL - $1 (missing: $3)"; fails=$((fails+1)); fi; }
refute() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "FAIL - $1 (unexpected: $3)"; fails=$((fails+1)); else echo "ok   - $1"; fi; }

# A repo whose remote looks like GitHub, pushed and clean, in a folder with a space and an accent.
mkdir -p "$TMP/remote/acme" && git init -q --bare -b main "$TMP/remote/acme/demo.git"
P="$TMP/My Proj é"; mkdir -p "$P" && cd "$P"
git init -q -b feature/x && git -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git remote add origin "$TMP/remote/acme/demo.git" && git push -q -u origin feature/x 2>/dev/null
git remote set-url origin "https://github.com/acme/demo.git"
git config remote.origin.pushurl "$TMP/remote/acme/demo.git"
git fetch -q "$TMP/remote/acme/demo.git" "feature/x:refs/remotes/origin/feature/x" 2>/dev/null

out="$(CLAUDE_CODE_REMOTE= bash "$SCRIPT" --for claude)"
check "claude.ai link with repo and branch" "$out" "https://claude.ai/code/new?q=Resume%20from%20HANDOVER.md"
check "repo slug encoded"                 "$out" "&repo=acme%2Fdemo&branch=feature%2Fx"
check "desktop link"                      "$out" "claude://code/new?q="
check "terminal link encodes path"        "$out" "cwd=%2F"
check "accent encoded as UTF-8"           "$out" "My%20Proj%20%C3%A9"
check "terminal command"                  "$out" 'claude "/go-bananas resume"'
refute "no push warning when in sync"     "$out" "isn't fully pushed"
refute "no dirty warning when clean"      "$out" "Uncommitted changes"

out="$(CLAUDE_CODE_REMOTE= bash "$SCRIPT" --for codex)"
check "codex app link with path"          "$out" "codex://threads/new?prompt=Resume"
check "codex terminal command"            "$out" "codex '\$go-bananas resume'"

echo hi > notes.txt
out="$(CLAUDE_CODE_REMOTE= bash "$SCRIPT")"
check "dirty warning names the file"      "$out" "Uncommitted changes (notes.txt)"

git add notes.txt; git -c user.name=t -c user.email=t@example.com commit -q -m notes
out="$(CLAUDE_CODE_REMOTE= bash "$SCRIPT")"
check "push warning when ahead"           "$out" "isn't fully pushed"

out="$(CLAUDE_CODE_REMOTE=true bash "$SCRIPT")"
refute "cloud session hides local app links" "$out" "claude://code/new"
check  "cloud session keeps claude.ai link"  "$out" "https://claude.ai/code/new"

cd "$TMP" && mkdir plain && cd plain
out="$(CLAUDE_CODE_REMOTE= bash "$SCRIPT")"
refute "no claude.ai link without a GitHub remote" "$out" "https://claude.ai"
check  "fallback prompt always shown"              "$out" "follow its resume rules"

echo; [ "$fails" -eq 0 ] && echo "All passed." || { echo "$fails failed."; exit 1; }
