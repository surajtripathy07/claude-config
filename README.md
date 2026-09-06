# claude-config

Portable Claude Code configuration — personal skills installable on any device.

## Skills

| Skill | What it does |
|---|---|
| `handoff` | End-of-session handover note capturing what was achieved and what's next |
| `git-commit` | Commit message conventions (what/why, type::, supervision:: labels) |
| `write-goal` | Writes an executable goal file into `docs/goals/` from repo state |
| `pending-decisions` | Surfaces every pending maintainer decision as a decision brief |
| `own-it` | Author-depth walkthrough of a change or decision: mechanism, reasoning, verification, rebuild path |

## Install on a new device

```sh
git clone git@github.com:surajtripathy07/claude-config.git ~/dev/claude-config
cd ~/dev/claude-config
./install.sh
```

Skills are symlinked into `~/.claude/skills/` and `global/CLAUDE.md` is symlinked to
`~/.claude/CLAUDE.md` (standing rules for every project; an existing hand-written one is
backed up, not overwritten). If you don't want to keep the clone around, use
`./install.sh --copy` instead.

## Get the latest version on any device

```sh
~/dev/claude-config/sync.sh
```

Pulls from GitHub and re-runs the installer, so new skills get linked and everything is
current. It refuses to run over uncommitted local edits so nothing is lost.

## Update from a device

Edit under the clone (or under `~/.claude/skills/` — same files via symlink), then commit
and push. Other devices pick it up with `sync.sh`.
