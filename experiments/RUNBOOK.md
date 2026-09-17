# Cost experiment: orchestrate skill × headroom

Goal: decide with data whether (1) the `orchestrate` delegation pattern and (2) the
headroom compression proxy reduce spend without hurting outcomes.

## Arms

| Arm | How to start | What varies |
|---|---|---|
| A control | `claude` | orchestrate skill on (it is a standing rule), no proxy |
| B headroom | `claude-hr` | same, plus `ANTHROPIC_BASE_URL` → local headroom proxy on :8787 |

Baseline (no orchestrate skill) is the history before 2026-09-10: `session-cost --since 2026-08-27`.
Those sessions show `arm=unknown` because the SessionStart hook did not exist yet.

Optional finer labels: `ORCHESTRATE_LABEL=review claude` tags a session; `session-cost --by label`.

## First run of arm B — this is the open question

Headroom's README says `headroom wrap claude` preserves "your Anthropic authentication", but
does not say whether that covers Claude Code's subscription OAuth (this machine uses a
managed-account login, no `ANTHROPIC_API_KEY`). A haiku scout read it as API-key-only; that
is unverified. So the first `claude-hr` session is a smoke test:

1. `uv tool install --python 3.13 'headroom-ai[all]'` (3.13, not 3.14: dollar tracking is
   disabled on 3.14 per the README). Set `HEADROOM_BEACON=off` to disable telemetry.
2. `claude-hr` in any repo, ask one trivial question. If the request fails with an auth
   error, the proxy does not forward the OAuth bearer and arm B is dead until headroom
   supports it (or you have an API key you are allowed to use for work). Record the result
   here either way.
3. If it works: `headroom stats` shows the proxy's own view of savings; `session-cost --by arm`
   shows Claude Code's view. They should agree in direction.

2026-09-11: OAuth passthrough confirmed — `claude-hr` sessions (arm=on) show real fable
usage through the 127.0.0.1:8787 proxy.

## What to record

Schedule: arm on (headroom via `claude-hr`) for 2 working days starting 2026-09-11, then
arm off (plain `claude`) for the next 2 working days. Metric: fable `main` `usd/turn`,
`cread/turn`, `cwrite/turn`, and `cache%` from `session-cost --by arm --since <start>`.
`headroom stats` is a self-report of removed request tokens, not billed tokens — cross-check
it against the billed per-turn drop, don't take it at face value.

Caveat: 2 days/arm is a small sample and task mix differs day to day. Compare per-turn
(not per-session) numbers, and tag sessions with `ORCHESTRATE_LABEL` so like work can be
compared to like.

Other confounders to keep in mind:

- Cache reads are ~10% the price of input. A change that raises cache_write and lowers
  cache_read can look like savings in token count and be a loss in dollars.
- Headroom compresses tool results the model sees. Watch for retries, re-reads, or wrong
  answers caused by a compressed error tail — that is a quality cost `session-cost` cannot see.
  Note any such incident in the session's handoff.

## Reading the numbers

```
session-cost --since 2026-09-10 --by arm     # per arm × model
session-cost --since 2026-09-10              # per session; main vs sub split
session-cost --session <id>                  # one session, per-agent
```

For the orchestrate skill specifically: the `main` row for the fable model should shrink
relative to the pre-skill baseline, and `sub` rows on haiku/sonnet should appear. If fable
`main` input+cache tokens per user turn are not falling, the brain is still reading too much:
check the hook counter denials and the anti-patterns list in the skill.

## Results log

| Date | Arm | Sessions | turns | usd/turn | cread/turn | cwrite/turn | cache% | notes |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |
