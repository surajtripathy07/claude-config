#!/usr/bin/env bash
# Installs the skills in this repo into ~/.claude/skills/ via symlinks,
# so `git pull` in this repo updates them everywhere.
#
# Usage: ./install.sh [--copy]
#   --copy   copy instead of symlink (for machines where you won't keep the clone)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/skills"
MODE="${1:-link}"

mkdir -p "$TARGET"

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

echo
echo "Done. Installed into $TARGET"
