#!/usr/bin/env bash
# Fetch the latest config from GitHub and re-install it. Run any time, from anywhere:
#   ~/dev/claude-config/sync.sh
#
# Refuses to pull over uncommitted local edits so nothing is lost; commit or stash first.
# This is what protects a symlinked skill (the default install mode) from being
# overwritten: editing it edits the repo file directly, so it shows up here as an
# uncommitted change. A --copy-installed or de-symlinked skill isn't a repo file, so
# it isn't covered by this check — see the local-changes guard in install.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes in $REPO_DIR — commit or stash them, then re-run." >&2
  git status --short >&2
  exit 1
fi

echo "Pulling latest from origin..."
git pull --ff-only

echo
"$REPO_DIR/install.sh" "$@"
