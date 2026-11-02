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

## Verifier receipt guard (SubagentStop)

`verifier-receipt-subagentstop.sh` rejects a `verifier` receipt that lacks an `EXIT <integer>` per `CMD`,
lacks exactly one `OVERALL: PASS|FAIL` line, or says `PASS` beside a non-zero EXIT. It blocks once per
`agent_id` (marker in `$TMPDIR/verifier-guard/`); on the second stop it lets the agent through with a
`RECEIPT INVALID — treat as FAIL` systemMessage. Missing `jq` blocks once ("receipt unverifiable").
`VERIFIER_GUARD=off` disables. Add to `settings.json`:

Since Claude Code 2.1.271 a subagent in auto mode may deliver its report through the `SubagentHandback` tool,
and then `last_assistant_message` is only closing text. The same script also runs as a `PreToolUse` hook on that
tool and checks `tool_input.message`. A bad report is denied (Claude Code asks the subagent to re-deliver, up to
three times); the second bad report is let through with a `RECEIPT INVALID — treat as FAIL` `additionalContext`.
A delivered report is marked, so the later SubagentStop skips it. Add both to `settings.json`:

```json
"SubagentStop": [{ "matcher": "verifier",
  "hooks": [{ "type": "command", "command": "~/dev/claude-config/hooks/verifier-receipt-subagentstop.sh" }] }],
"PreToolUse": [{ "matcher": "SubagentHandback",
  "hooks": [{ "type": "command", "command": "~/dev/claude-config/hooks/verifier-receipt-subagentstop.sh" }] }]
```

Add the `PreToolUse` entry to the existing `PreToolUse` array, not a second key.

Test: `hooks/tests/verifier-receipt.test.sh` (exit 0 = all cases pass).

## Shared local DB lock (`db-mutation-guard-pretooluse.sh`, `bin/db-lock`)

Parallel sessions in worktrees of one repo share the local Postgres. These two pieces
stop one session's migrate/restore/prepare from breaking another's run. They assume each
worktree already has its own test DB; the development DB stays shared.

| Piece | Event | Purpose |
|---|---|---|
| `db-mutation-guard-pretooluse.sh` | PreToolUse (Bash) | Denies `db:migrate`, `db:rollback`, `db:test:prepare`, `db:prepare`, `db:schema:load`, `db:structure:load`, `db:drop`, `db:create`, `db:reset`, `db:setup`, `db:seed`, `pg_restore`, `dropdb`, `createdb` unless the segment starts with `db-lock --`. rspec is allowed. Fails closed without jq. `DB_GUARD_HOOK=off` disables. |
| `hooks/db-guard-patterns.local.txt` | — | Optional, never committed. Extra extended regexes the guard also denies, one per line, `#` comments. Use it for tool-specific reset commands. `DB_GUARD_PATTERNS=<path>` points elsewhere. |
| `bin/db-lock` | — | `db-lock -- <cmd>`: exclusive `mkdir` lock per repo (keyed on the git common dir, so all worktrees share it) under `~/.claude/locks/`. Dead-owner locks are taken over. `DB_LOCK_WAIT=<s>` waits (default 0); exit 75 names the holder. |

Add to `~/.claude/settings.json` (not merged by `./install.sh --hooks`):

```json
"PreToolUse": [{ "matcher": "Bash",
  "hooks": [{ "type": "command", "command": "~/dev/claude-config/hooks/db-mutation-guard-pretooluse.sh" }] }]
```

Install `db-lock` onto `PATH` (what `install.sh`'s bin loop does):

```sh
mkdir -p ~/.local/bin && ln -sf ~/dev/claude-config/bin/db-lock ~/.local/bin/db-lock
```

Tests (fake commands only): `hooks/tests/db-guard.test.sh`.

## Local overlay

Files named `*.local.*` or under a `local/` directory are machine-specific and never committed
(list them in `.git/info/exclude`). Generic hooks and scripts read them when present and work without them.
