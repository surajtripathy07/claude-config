#!/usr/bin/env bash
# Installs this repo's skills and global CLAUDE.md into ~/.claude/ via symlinks,
# so `git pull` in this repo updates them everywhere. Safe to re-run any time.
#
# Usage: ./install.sh [--copy] [--hooks]
#   --copy   copy instead of symlink (for machines where you won't keep the clone)
#   --hooks  also merge hooks/ into ~/.claude/settings.json (needs jq); see hooks/README.md
#
# To pull the latest from GitHub and re-install in one go, run ./sync.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/skills"
MODE="link"; HOOKS="no"
for arg in "$@"; do
  case "$arg" in
    --copy) MODE="--copy" ;;
    --hooks) HOOKS="yes" ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

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

# --- agents (custom subagents for the orchestrate skill) ---------------------
mkdir -p "$CLAUDE_DIR/agents"
for agent in "$REPO_DIR"/agents/*.md; do
  name="$(basename "$agent")"
  dest="$CLAUDE_DIR/agents/$name"
  [ -e "$dest" ] || [ -L "$dest" ] && rm -f "$dest"
  if [ "$MODE" = "--copy" ]; then cp "$agent" "$dest"; echo "copied:   agents/$name"
  else ln -s "$agent" "$dest"; echo "linked:   agents/$name -> $agent"; fi
done

# --- bin (session-cost, claude-hr) --------------------------------------------
mkdir -p "$HOME/.local/bin"
for tool in "$REPO_DIR"/bin/*; do
  [ -f "$tool" ] && [ -x "$tool" ] || continue
  name="$(basename "$tool")"
  dest="$HOME/.local/bin/$name"
  [ -e "$dest" ] || [ -L "$dest" ] && rm -f "$dest"
  ln -s "$tool" "$dest"; echo "linked:   bin/$name -> ~/.local/bin/$name"
done
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "NOTE: add ~/.local/bin to PATH to use $(ls "$REPO_DIR"/bin | tr '\n' ' ')";; esac

# --- hooks (opt-in) -------------------------------------------------------------
if [ "$HOOKS" = "yes" ]; then
  settings="$CLAUDE_DIR/settings.json"
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found; paste the snippet from hooks/README.md into $settings by hand" >&2
  else
    [ -f "$settings" ] || echo '{}' > "$settings"
    cp "$settings" "$settings.bak.$(date +%Y%m%d%H%M%S)"
    pre="$REPO_DIR/hooks/orchestrate-pretooluse.sh"; start="$REPO_DIR/hooks/orchestrate-sessionstart.sh"
    jq --arg pre "$pre" --arg start "$start" '
      .hooks //= {} |
      .hooks.PreToolUse   = ((.hooks.PreToolUse   // []) | map(select((.hooks // []) | any(.command == $pre)   | not))) + [{matcher:"Read|Grep|Glob", hooks:[{type:"command", command:$pre}]}] |
      .hooks.SessionStart = ((.hooks.SessionStart // []) | map(select((.hooks // []) | any(.command == $start) | not))) + [{matcher:"", hooks:[{type:"command", command:$start}]}]
    ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
    echo "merged:   hooks into $settings (backup kept alongside)"
  fi
fi

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
