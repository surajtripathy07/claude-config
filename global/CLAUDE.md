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
