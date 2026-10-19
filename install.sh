#!/usr/bin/env bash
# Recoverable installer for the Polyskill-built Claude Code and Codex variants.
# Usage: bash install.sh [--dry-run] [--replace] [--target claude|codex|all] [--ref COMMIT_OR_TAG]
set -euo pipefail
REPO=https://github.com/Holodeck23/go-bananas
TARGET=auto
REF=""
DRY=no
REPLACE=no
SKILLS=(go-bananas gb)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=yes; shift ;;
    --replace) REPLACE=yes; shift ;;
    --target|--ref)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "Missing value for $1" >&2; exit 2; }
      if [ "$1" = --target ]; then TARGET="$2"; else REF="$2"; fi
      shift 2 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$TARGET" in auto|claude|codex|all) ;; *) echo 'Choose claude, codex or all' >&2; exit 2 ;; esac
case "$REF" in -*) echo 'Invalid ref' >&2; exit 2 ;; esac
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TMP=""
LOCKS=()
STAGES=()
DESTS=()
OLDS=()
HAD_OLD=()
RECEIPT=""
COMMITTED=no
cleanup() {
  local status="$1" i dest old
  trap - EXIT INT TERM
  if [ "$COMMITTED" != yes ]; then
    for ((i=${#DESTS[@]}-1; i>=0; i--)); do
      dest="${DESTS[$i]}"; old="${OLDS[$i]}"
      if [ -e "$old" ] || [ -L "$old" ]; then
        if [ -e "$dest" ] || [ -L "$dest" ]; then
          mkdir -p "$RECEIPT/interrupted/$i"
          mv "$dest" "$RECEIPT/interrupted/$i/" || true
        fi
        mv "$old" "$dest" || echo "Restore manually: $old -> $dest" >&2
      elif [ "${HAD_OLD[$i]}" = no ] && { [ -e "$dest" ] || [ -L "$dest" ]; }; then
        mkdir -p "$RECEIPT/interrupted/$i"
        mv "$dest" "$RECEIPT/interrupted/$i/" || true
      fi
    done
  fi
  # Only disposable downloads/staging are removed; existing skills are retained.
  if [ "$COMMITTED" != yes ] && [ -n "$RECEIPT" ]; then
    touch "$RECEIPT/AUTOMATIC_ROLLBACK"
  fi
  for i in "${STAGES[@]-}"; do [ -z "$i" ] || rm -rf -- "$i"; done
  for i in "${LOCKS[@]-}"; do [ -z "$i" ] || rmdir "$i" 2>/dev/null || true; done
  [ -z "$TMP" ] || rm -rf -- "$TMP"
  exit "$status"
}
trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -n "$REF" ] || [ ! -d "$SRC/claude/go-bananas" ]; then
  [ -n "$REF" ] || { echo 'Remote install requires --ref with a reviewed commit or tag.' >&2; exit 2; }
  TMP="$(mktemp -d)"
  git init -q "$TMP/repo"
  git -C "$TMP/repo" remote add origin "$REPO"
  GIT_TERMINAL_PROMPT=0 git -C "$TMP/repo" fetch --quiet --depth 1 origin "$REF"
  git -C "$TMP/repo" checkout --quiet --detach FETCH_HEAD
  SRC="$TMP/repo"
fi
RUNTIMES=()
if [ "$TARGET" = all ] || [ "$TARGET" = claude ] ||
   { [ "$TARGET" = auto ] && { [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; }; }; then
  RUNTIMES+=(claude)
fi
if [ "$TARGET" = all ] || [ "$TARGET" = codex ] ||
   { [ "$TARGET" = auto ] && { [ -d "$HOME/.agents" ] || [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; }; }; then
  RUNTIMES+=(codex)
fi
[ "${#RUNTIMES[@]}" -gt 0 ] || { echo 'No runtime found. Choose --target claude, codex or all.' >&2; exit 2; }
destination() {
  if [ "$1" = claude ]; then printf '%s/.claude/skills' "$HOME"; else printf '%s/.agents/skills' "$HOME"; fi
}
# Complete preflight before changing any installation.
for runtime in "${RUNTIMES[@]}"; do
  dest="$(destination "$runtime")"
  for skill in "${SKILLS[@]}"; do
    [ -s "$SRC/$runtime/$skill/SKILL.md" ] || { echo "Missing built skill: $runtime/$skill" >&2; exit 1; }
    if { [ -e "$dest/$skill" ] || [ -L "$dest/$skill" ]; } && [ "$REPLACE" != yes ]; then
      if [ "$DRY" = yes ]; then
        echo "COLLISION: $dest/$skill (use --replace only after review)"
      else
        echo "Already exists: $dest/$skill. Review --dry-run, then use --replace to back up and replace." >&2
        exit 1
      fi
    fi
    printf 'Plan: %s/%s -> %s/%s\n' "$SRC" "$runtime/$skill" "$dest" "$skill"
  done
done
[ "$DRY" != yes ] || { echo 'Preview only; no installed files changed.'; exit 0; }

# Lock and stage every runtime before replacing either skill.
for runtime in "${RUNTIMES[@]}"; do
  dest="$(destination "$runtime")"
  mkdir -p "$dest"
  lock="$dest/.go-bananas-install.lock"
  mkdir "$lock" 2>/dev/null || { echo "Installer lock exists: $lock. Stop and inspect; no retry." >&2; exit 1; }
  LOCKS+=("$lock")
  stage="$(mktemp -d "$dest/.go-bananas-stage.XXXXXX")"
  STAGES+=("$stage")
  for skill in "${SKILLS[@]}"; do cp -R "$SRC/$runtime/$skill" "$stage/$skill"; done
done
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RECEIPT="${XDG_STATE_HOME:-$HOME/.local/state}/go-bananas/backups/$STAMP"
mkdir -p "$RECEIPT"
printf '#!/usr/bin/env bash\nset -euo pipefail\n' > "$RECEIPT/restore.sh"
printf '[ ! -e %q ] || { echo "Automatic rollback already ran; inspect MANIFEST and backups."; exit 1; }\n' "$RECEIPT/AUTOMATIC_ROLLBACK" >> "$RECEIPT/restore.sh"
printf 'mkdir %q || { echo "Restore already started; inspect retained copies before continuing."; exit 1; }\n' "$RECEIPT/restore-started" >> "$RECEIPT/restore.sh"
printf 'Source: %s\nRevision: %s\n' "$SRC" "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)" > "$RECEIPT/MANIFEST.txt"
# Record undo before each swap, so even a hard interruption has a recovery path.
for ((r=0; r<${#RUNTIMES[@]}; r++)); do
  runtime="${RUNTIMES[$r]}"; dest="$(destination "$runtime")"
  mkdir -p "$RECEIPT/$runtime" "$RECEIPT/restored-away/$runtime"
  for skill in "${SKILLS[@]}"; do
    old="$RECEIPT/$runtime/$skill"
    present=no
    if [ -e "$dest/$skill" ] || [ -L "$dest/$skill" ]; then present=yes; fi
    DESTS+=("$dest/$skill"); OLDS+=("$old"); HAD_OLD+=("$present")
    printf '\n# Undo %s/%s; preserves the currently installed copy.\n' "$runtime" "$skill" >> "$RECEIPT/restore.sh"
    printf 'if [ -e %q ] || [ -L %q ]; then mv -- %q %q; fi\n' "$dest/$skill" "$dest/$skill" "$dest/$skill" "$RECEIPT/restored-away/$runtime/$skill" >> "$RECEIPT/restore.sh"
    if [ "$present" = yes ]; then
      printf 'if [ -e %q ] || [ -L %q ]; then mv -- %q %q; fi\n' "$old" "$old" "$old" "$dest/$skill" >> "$RECEIPT/restore.sh"
      mv "$dest/$skill" "$old"
    fi
    mv "${STAGES[$r]}/$skill" "$dest/$skill"
    printf '%s/%s -> %s/%s (previous: %s)\n' "$runtime" "$skill" "$dest" "$skill" "$present" >> "$RECEIPT/MANIFEST.txt"
  done
done
COMMITTED=yes
printf 'Installed on demand. Receipt and retained backups: %s\n' "$RECEIPT"
printf 'Undo once with: bash %q\n' "$RECEIPT/restore.sh"
printf 'Invoke /gb in Claude Code or $gb in Codex. Plain GB relies on discovery.\n'
