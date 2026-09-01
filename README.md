# claude-config

Portable Claude Code configuration — personal skills installable on any device.

## Skills

| Skill | What it does |
|---|---|
| `handoff` | End-of-session handover note capturing what was achieved and what's next |
| `git-commit` | Commit message conventions (what/why, type::, supervision:: labels) |
| `write-goal` | Writes an executable goal file into `docs/goals/` from repo state |
| `pending-decisions` | Surfaces every pending maintainer decision as a decision brief |

## Install on a new device

```sh
git clone git@github.com:surajtripathy07/claude-config.git ~/dev/claude-config
cd ~/dev/claude-config
./install.sh
```

Skills are symlinked into `~/.claude/skills/`, so a `git pull` in the clone updates them everywhere. If you don't want to keep the clone around, use `./install.sh --copy` instead.

## Update from a device

Edit the skill under the clone (or under `~/.claude/skills/` — same files via symlink), then commit and push. Other devices pick it up with `git pull`.
