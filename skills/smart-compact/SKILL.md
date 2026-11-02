---
name: smart-compact
description: Draft the focus instructions for /compact from what this session actually needs to carry forward, and print a ready-to-run `/compact ...` line. Use when the user invokes /smart-compact, or says "compact smartly", "prepare to compact", "context is getting long".
---

# smart-compact

A skill cannot execute `/compact` (it is a CLI command, not a tool). This skill does the
hard part: deciding what must survive, and emitting the exact line for the user to run.

## Steps

1. From your own context, list what the next window cannot afford to lose. Be specific,
   one line each, no narration:
   - **Goal:** what the user is trying to achieve, in their words where possible.
   - **State:** done / in progress / not started. Branch, MR/issue numbers, key file paths.
   - **Decisions + why:** each choice the user made and the reason, including rejected
     options worth not re-litigating.
   - **Verified facts:** commands run and their outcomes that later steps depend on.
     Mark anything unverified as unverified.
   - **Pending:** next action, open questions for the user, anything waiting on someone.
   - **Rules in force:** user corrections or constraints given this session.
2. List what to drop: raw tool output, file dumps, exploration dead ends, superseded
   drafts, repeated status chatter.
3. Save the full list to `~/.claude/compact-notes/YYYY-MM-DD-HHMM-<project>.md` so it
   survives if the summary is lossy.
4. Print one line for the user to run, under ~120 words, in this form:

   `/compact Preserve: <goal; state; decisions+why; verified facts; pending; rules>. Drop: <raw outputs, dead ends, superseded drafts>.`

5. Say the notes file path. Stop. Do not claim compaction has happened.

## Rules

- Only things true in this session; no guesses about what might matter.
- Prefer identifiers (paths, MR numbers, commit shas) over prose.
- If the session has nothing worth carrying forward, say so and skip the command.
