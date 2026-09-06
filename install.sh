#!/usr/bin/env bash
# Installs this repo's skills and global CLAUDE.md into ~/.claude/ via symlinks,
# so `git pull` in this repo updates them everywhere. Safe to re-run any time.
#
# Usage: ./install.sh [--copy]
#   --copy   copy instead of symlink (for machines where you won't keep the clone)
#
# To pull the latest from GitHub and re-install in one go, run ./sync.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/skills"
MODE="${1:-link}"

mkdir -p "$TARGET"

# --- skills -----------------------------------------------------------------
for skill in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill")"
  dest="$TARGET/$name"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "replacing existing: $name"
    rm -rf "$dest"
  fi

  if [ "$MODE" = "--copy" ]; then
    cp -R "$skill" "$dest"
    echo "copied:   $name"
  else
    ln -s "${skill%/}" "$dest"
    echo "linked:   $name -> ${skill%/}"
  fi
done

# --- global CLAUDE.md ---------------------------------------------------------
# Standing rules loaded into every session on every project (e.g. own-it triggers).
src="$REPO_DIR/global/CLAUDE.md"
dest="$CLAUDE_DIR/CLAUDE.md"

if [ -f "$src" ]; then
  # Never silently destroy a hand-written global CLAUDE.md on a new machine.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "backed up existing CLAUDE.md -> $backup (merge anything you want kept into global/CLAUDE.md)"
  fi
  rm -f "$dest"
  if [ "$MODE" = "--copy" ]; then
    cp "$src" "$dest"
    echo "copied:   CLAUDE.md"
  else
    ln -s "$src" "$dest"
    echo "linked:   CLAUDE.md -> $src"
  fi
fi

echo
echo "Done. Installed into $CLAUDE_DIR"
