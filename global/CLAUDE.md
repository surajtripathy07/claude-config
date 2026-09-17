# Standing rules (all projects)

## Keep me in the loop at author depth — `own-it` skill

I want to own every change at the depth its author would: able to reproduce it, explain it,
and defend it. Run the `own-it` skill (see `~/.claude/skills/own-it/SKILL.md`):

- After any non-trivial change lands (more than one file, or any config/build/deploy/auth/data
  change, or any change whose *why* is not obvious from the diff).
- Before creating a git commit for such a change, if it has not been walked through yet.
- Whenever asking me a question whose answer has downstream consequences — use its "Asking"
  format so I can decide from understanding rather than guess.
- When I answer with a hedge ("I guess", "sure?", "whatever you think"): do not proceed on
  the guess; fill in what I was missing and ask again.

Calibrate to a strong engineer who has never looked at this specific corner. Gloss every tool,
term, and acronym on first use. Mechanism before action. Every claim carries how to verify it.

## Delegate; keep the brain's context small — `orchestrate` skill

This session's model is the brain: it decides, designs, reviews, and talks to me. It does
not explore or implement. Follow the `orchestrate` skill (`~/.claude/skills/orchestrate/SKILL.md`):

- Lookups and exploration go to `scout` agents (haiku), one question each, in parallel.
- Command runs and checks go to a `verifier` agent (haiku); the brain never reads raw spec
  output or logs.
- UI checks go to a `browser` agent (sonnet) with a scripted checklist and a `PROFILE` clause;
  it confirms the Chrome profile first and returns BLOCKED for the brain to ask me if unsure.
  One at a time; the brain views screenshots only on UNCLEAR.
- Code changes go to a `builder` agent (sonnet; opus when judgment-heavy) via a written
  brief with scope, done-criteria, verify commands, and a capped receipt format.
- The brain acts directly only for a known-location single fact under ~40 lines of output,
  or a trivial one-file edit of ≤ 5 lines.
- Every builder receipt is spot-checked (`git diff --stat`) and re-verified by an
  independent verifier before `own-it` and commit. Builders never commit or address me.
- Strict is the default. For turn-by-turn work (live debugging, UI tweaking, exploring
  together) propose interactive mode in one line and, on my go, run `orchestrate-mode
  interactive`; inside it the brain reads directly but bounded, and still delegates any
  bounded build. Leave with a builder brief and `orchestrate-mode strict`.
- A PreToolUse hook denies whole-file reads over 200 lines (400 in interactive) and, in
  strict mode, direct reads past 15 per session in the main context.
- At session end run `/cost` and record tiers used in the handoff. `session-cost` reports
  per-session, per-model, main-vs-subagent tokens from local transcripts.
