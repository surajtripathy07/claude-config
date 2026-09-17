# hooks

Installed by `./install.sh --hooks` (merges into `~/.claude/settings.json` with `jq`).
To install by hand, add to `settings.json`:

```json
"hooks": {
  "PreToolUse": [{ "matcher": "Read|Grep|Glob",
    "hooks": [{ "type": "command", "command": "~/dev/claude-config/hooks/orchestrate-pretooluse.sh" }] }],
  "SessionStart": [{ "matcher": "",
    "hooks": [{ "type": "command", "command": "~/dev/claude-config/hooks/orchestrate-sessionstart.sh" }] }]
}
```

| Hook | Event | Purpose |
|---|---|---|
| `orchestrate-pretooluse.sh` | PreToolUse | Backstop for the `orchestrate` skill: deny whole-file reads > 200 lines and direct reads past a per-session budget of 15, main session only. `ORCHESTRATE_HOOK=off` disables. |
| `orchestrate-sessionstart.sh` | SessionStart | Appends a row to `~/.claude/experiments/sessions.tsv` recording `ANTHROPIC_BASE_URL` (so headroom on/off is known) and `ORCHESTRATE_LABEL`. Used by `bin/session-cost`. |

Test the PreToolUse hook without a session:

```sh
printf '{"session_id":"t","tool_name":"Read","tool_input":{"file_path":"%s"}}' \
  ~/dev/claude-config/skills/orchestrate/SKILL.md | ./hooks/orchestrate-pretooluse.sh
```
