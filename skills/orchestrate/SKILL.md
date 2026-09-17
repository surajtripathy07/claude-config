---
name: orchestrate
description: Operating principle for every session. The session model is the brain — it decides, designs, reviews, and talks to the user — and delegates reading, searching, running, and editing to cheaper subagents (scout=haiku, verifier=haiku, builder=sonnet or opus) through written briefs and receipts, guarding its own context as the scarcest resource. Use at session start, before any file read, search, long command, or code edit, and whenever a subagent reports back.
---

# orchestrate — the brain delegates; the hands are cheap and disposable

## Why this exists

Every token the session model (the *brain*) reads stays in its context for the rest of the
session and is re-read on every subsequent turn. Brain tokens are the most expensive tokens
there are, and their cost compounds. A subagent's tokens are cheaper per token, are read
once, and are thrown away when it finishes — only its final message comes back.

So the rule is not "save money"; it is **keep the brain's context small and high-signal**.
Money follows. A brain that has read 40 files cannot reason as well as one that has read
40 receipts, and it costs ten times more per turn to keep alive.

Three consequences:

1. The brain never explores. It asks a scout a targeted question and gets an answer.
2. The brain never edits code of any size beyond a trivial fix. It writes a brief; a
   builder implements; a verifier checks; the brain reads receipts and decides.
3. The brain never trusts a receipt it has not had independently checked, because the
   whole design rests on the brain not reading the raw evidence itself.

## Roles

| Role | Model | Does | Never does | Invoked as |
|---|---|---|---|---|
| **Brain** | session model (fable) | Understands the ask, plans, writes briefs, reads receipts, decides, reviews, runs `own-it`, talks to the user, commits | Reads whole files, greps broadly, runs long commands, edits more than a trivial fix | — (this is the session) |
| **Scout** | haiku | Answers a *specific* question about the codebase: where, what, how many, which. Returns locations and short excerpts | Edits, runs commands with side effects, speculates beyond the question | `Agent(subagent_type: "scout")` |
| **Verifier** | haiku (sonnet if the check needs judgment) | Runs the specs, lints, diffs, or commands named in the brief and reports results verbatim-tail. Independent of the builder | Edits, fixes, "helps" | `Agent(subagent_type: "verifier")` |
| **Browser** | sonnet | Runs a scripted UI checklist in the user's real Chrome via the chrome-devtools MCP: navigate, fill, click, snapshot, assert, screenshot. Confirms the Chrome profile first. Returns per-step verdicts and screenshot paths, never images | Runs in parallel with another browser agent, logs in/out, takes money/data actions not listed in the brief | `Agent(subagent_type: "browser")` — one at a time; continue via `SendMessage` |
| **Builder** | sonnet by default; opus when judgment-heavy (see § Tiering) | Implements one bounded task from a brief, in scope, runs the checks the brief names, returns a receipt | Commits, touches files outside scope, widens scope, asks the user directly | `Agent(subagent_type: "builder", model: "sonnet"|"opus")` |

Agent definitions live in `~/.claude/agents/{scout,verifier,browser,builder}.md` (installed from
`~/dev/claude-config/agents/`). The `model:` passed to the `Agent` tool overrides the
definition, so tier selection is a per-call decision, not a config change.

Built-in `Explore` and `Plan` agents are acceptable substitutes for scout when a custom
agent is unavailable — pass `model: "haiku"` explicitly. **Never use `subagent_type: "fork"`
for exploration or building**: a fork inherits the brain's entire context, so it costs as
much as the brain and defeats the purpose. Fork only when the accumulated context *is* the
input (e.g. "write the handoff for this session").

## Routing — who does what

| Task | Route | Why |
|---|---|---|
| "Where is X defined / used / configured?" | scout | Pure lookup |
| "How does subsystem Y work?" | 2–4 scouts in parallel, one question each | Targeted beats broad; parallel is free |
| "Is this claim in the docs / issue / MR true?" | scout (with Orbit/Glean/WebFetch tools) | Lookup |
| Run specs, lint, migrations status, `git diff --stat`, build | verifier | Long output the brain must not read raw |
| Reproduce UI steps, check a page, capture Before/After | browser | Screenshots are the most expensive thing the brain can ingest |
| Implement a change: new method, spec, migration, component | builder (sonnet) | Well-specified mechanical work |
| Multi-file refactor, subtle bug fix, anything where "which of three ways" matters | builder (opus) | Judgment inside the edit |
| Design, choose between approaches, review a receipt, answer the user | brain | This is the job |
| `own-it`, `git-commit`, `pending-decisions`, MR review verdicts | brain | User-facing, decision-bearing |
| Handoff | fork or brain | The context is the input |

**The brain may act directly only when all of these hold:**

- It already knows the exact file and symbol (a single-fact lookup, not a search), **and**
- the expected output is under ~40 lines (use `sed -n 'a,bp'`, `grep -n ... | head`,
  `git diff --stat`), **or**
- the edit is trivial: one file, ≤ 5 lines, no judgment, and spawning a builder would cost
  more than the edit (a typo, a version bump, a one-line rename).

Anything else is delegated. When in doubt, delegate: a wasted scout call costs cents; a
polluted brain context costs the rest of the session.

## Tiering — which model for which work

| Signal in the task | Tier |
|---|---|
| Find, list, count, locate, quote, check-if-exists | haiku |
| Run and report; compare expected vs actual | haiku |
| Implement against a precise spec with named files and named done-criteria | sonnet |
| Implement where the brief has to say "figure out the right seam" or "match the neighbouring pattern" | opus |
| Anything touching auth, data migrations, billing math, or that the brain would want to `own-it` line by line | opus, then verifier, then brain spot-check |
| Decide, design, review, communicate | brain |

Escalate a tier only after a failure at the current tier (see § Control loop). Never
start at opus "to be safe" — the brief was the unsafe part; fix the brief.

## The brief — what every delegation must contain

A subagent starts with an empty context. Everything it needs must be in the brief. A vague
brief produces a vague receipt and a second round-trip, which is the real waste.

```
GOAL        one sentence; what done looks like from the outside
CONTEXT     what the agent cannot know: repo, paths, conventions, glossary of project
            terms, the relevant project skill to invoke first (rails / rspec / frontend)
SCOPE       files/dirs it may touch; files/dirs it must not; no commits; no new deps
STEPS       only if order matters; otherwise leave the how to the agent
DONE WHEN   observable criteria (spec X green, file Y contains Z, command W prints V)
VERIFY      exact commands to run before returning, and what output to include
RETURN      the receipt format below, with a hard size cap (e.g. ≤ 300 words, ≤ 40 lines
            of quoted output); "say UNSURE rather than guess"; "STOP and return if
            you hit <condition> — do not work around it"
```

Scout briefs are shorter: GOAL, CONTEXT (paths to start from), RETURN (paths with line
numbers, ≤ 10-line excerpts, ≤ 200 words). Ask one question per scout. If the answer
raises a second question, that is a second scout.

## The receipt — what comes back

**Scout receipt**: answer first, then `path:line` for each claim, then excerpt(s), then
"not found / unsure" items. No narrative.

**Verifier receipt**: command, exit code, last ~20 lines of output verbatim, one-line
verdict per check. No interpretation beyond pass/fail unless asked.

**Builder receipt**:

```
CHANGED     path:lines — what, and why this and not the neighbouring option
RAN         each verify command with exit code and last ~15 lines verbatim
ASSUMED     decisions made without asking, and what changes if wrong
UNSURE      anything not verified, edges not tested
SCOPE       confirm nothing outside SCOPE was touched (`git status --short` output)
```

The brain reads the receipt and then does exactly two things, in order:

1. **Spot-check the shape**: `git diff --stat` and, for at most two files, a
   `git diff -- <path> | head -60`. If the diff is bigger than the receipt implies, stop.
2. **Verify independently**: dispatch a verifier with the same VERIFY commands. The
   builder's own "specs green" is a claim, not evidence. Two different agents agreeing
   is the evidence the brain works from.

Only then does the brain run `own-it` for the user and move to commit.

## Browser verification

Screenshots and DOM snapshots are the costliest tokens the brain can hold, and they are
never the decision — the decision is "did step 4 show the new price". So UI checks go to
the `browser` agent with a scripted checklist, and the brain reads verdicts.

**Profile handshake.** The chrome-devtools MCP runs with `--autoConnect`, which attaches to
whichever Chrome profile has remote debugging enabled — one at a time, and no agent can
switch it. Every browser brief carries a `PROFILE` clause (which profile, signed in as whom).
The agent's step 0 is `list_pages` plus a cheap identity check; on mismatch, no tabs, or
doubt it returns `BLOCKED` with what it saw. The brain then asks the user in `own-it`
§ Asking form: which profile is intended, and the remediation (make that profile's window
active, enable `chrome://inspect/#remote-debugging`, Allow the attach). The agent never
proceeds on a guess about the profile.

**Brief additions for browser work:**

```
PROFILE     which Chrome profile and signed-in identity the steps assume
STEPS       numbered; each = action + EXPECT (text to be present/absent, URL, element)
EVIDENCE    which steps need a screenshot, and the directory to save into
FORBIDDEN   any UI action with money/data/account consequences not in STEPS is a STOP
```

**Rules:**

- **One browser agent at a time.** Chrome's selected page is shared state; two agents
  would fight over it. Serialise, or run the UI checks after the spec checks.
- **Continue, don't respawn**, across a multi-step reproduction: `SendMessage` to the same
  browser agent keeps the page, the login, and the checklist position.
- **The brain views a screenshot only on `UNCLEAR`** or when the user asks. `PASS`/`FAIL`
  with quoted observed text is the evidence; the file path is the receipt.
- **Snapshots over screenshots.** Text asserts better and costs less; the brief says
  "screenshot" only for Before/After evidence the review will publish.
- For `review-mr`: the reproduction step drives the browser agent; screenshots land in the
  review's `artifacts/` directory as before.

## Control loop for builders

- **One task per builder.** A task is one coherent change with one DONE WHEN. If the brief
  needs the word "also", split it.
- **Serial when files overlap, parallel otherwise.** Two builders in the same file will
  race; two builders in disjoint files are free concurrency.
- **Turn cap.** Builders carry `maxTurns` in their definition. A builder that runs out of
  turns has a bad brief or a bad tier, not bad luck.
- **Escalation ladder, per task:**
  1. Failure at sonnet → re-read the receipt's UNSURE; if the brief was ambiguous, fix the
     brief and retry at sonnet. Otherwise retry at opus.
  2. Failure at opus → the brain inspects, bounded: one scout question, one targeted diff.
     Then either a corrected brief or
  3. Stop and ask the user via `own-it` § Asking. Three failed attempts is a signal about
     the task, not about persistence.
- **Never let a builder commit.** Commits are the brain's, after `own-it`, via `git-commit`.
- **Never let a builder talk to the user.** It returns; the brain speaks.
- **Continue, don't respawn**, when the same builder needs a follow-up on the same task:
  `SendMessage` to its id keeps its context. A new spawn re-reads everything.

## Context hygiene for the brain — hard rules

- No `cat`/`Read` of a file over ~200 lines without `offset`/`limit` or `sed -n`. A
  PreToolUse hook (§ Enforcement) denies this in the main session as a backstop.
- Every direct shell command ends in a cap: `| head -40`, `--stat`, `--oneline`,
  `| tail -20`, `| wc -l`. Unbounded output is the most common way a session gets ruined.
- Never read logs, spec output, or JSON dumps in the brain. A verifier reads them and
  returns the tail and the verdict.
- Never `Read` a subagent's output file. It is the transcript; the summary already came back.
- Receipts are capped in the brief. A subagent that returns 2,000 words has ignored the
  RETURN clause; say so in the next brief.
- At milestones (plan agreed, first builder done, before commit) run `/context`. If the
  brain is over ~60% of its window, write state to a handoff note *now*, before compaction
  chooses what to forget for you.
- Prefer many small scouts over one big one. Five 200-word answers beat one 1,500-word
  survey, because the brain can ask the sixth question only after reading the first five.

## Session rhythm

**Start.** Restate the ask in one line. If the codebase is unfamiliar to this session,
fan out scouts for a map (entry points, the domain doc under `doc/agents/`, the nearest
existing example of the thing being built) rather than reading. Plan in the brain.

**Middle.** Brief → builder → receipt → spot-check → verifier → `own-it` → commit. Repeat.
Keep the user informed in short lines between rounds; they see only your messages.

**End.** Run `/cost`. Run the `handoff` skill and fill its `model :bot:` section with the
tiers actually used and roughly how many calls per tier. This is how the routing table
above gets tuned over time.

## Interactive mode — the deliberate exception

**Strict is the default.** Every session starts delegating. Interactive mode exists for
work where a subagent round-trip (twenty seconds to a minute) would make the user wait on
every steer: live debugging in a console, tweaking a component while watching the page,
exploring a subsystem together turn by turn.

**Entering** is a stated decision, never drift. When the brain notices turn-by-turn
steering, it says so in one line and proposes the switch; the user can also ask for it or
run it themselves with `! orchestrate-mode interactive`. The brain runs
`orchestrate-mode interactive` only after the user's go. Tag the session for the
experiment: the label is what `session-cost --by label` groups on.

**Inside**, the brain works directly under bounded outputs: windowed reads
(`sed -n`, `offset`/`limit`; the hook still denies whole-file reads over 400 lines),
every command piped through `head`/`tail`, no logs or spec dumps read raw. Anything that
becomes a clear bounded task mid-loop — "now write the spec for that", "run the full
file" — still goes to a builder or verifier. Interactive relaxes *where the brain looks*,
not *what it builds*.

**Leaving**: summarise what the loop established into a builder brief (that is the payoff
of the exploration), then `orchestrate-mode strict`. If the session ends in interactive
mode, the handoff says so and the next session starts strict regardless, because the
mode file is global and the next `orchestrate-mode strict` resets it.

The mode marker is one file, `~/.claude/experiments/orchestrate.mode`, read by the hook on
every call, so a switch takes effect on the next tool call without a restart. It is shared
by all concurrent sessions on the machine; that is a known trade-off.

## Enforcement — the backstop hook

`~/dev/claude-config/hooks/orchestrate-pretooluse.sh` runs on `PreToolUse` in the **main
session only** (it checks that `agent_id` is absent in the hook input, so subagents are
untouched). It denies, with a reason the model sees:

- `Read` of a file longer than `ORCHESTRATE_MAX_DIRECT_READ_LINES` (default 200) with no
  `offset`/`limit`.
- The Nth+1 direct `Read`/`Grep`/`Glob` in a session past
  `ORCHESTRATE_DIRECT_READ_BUDGET` (default 15). The counter lives in
  `${TMPDIR}/orchestrate-<session_id>.count`.

Mode (`strict` | `interactive` | `off`) comes from `orchestrate-mode`; in interactive the
budget is off and the whole-file limit is 400. `ORCHESTRATE_HOOK=off` at launch disables it
for that session. It does not police `Bash`; that is the
brain's discipline (the `| head` rule). Install via `./install.sh --hooks` (merges into
`~/.claude/settings.json` with `jq`) or paste the snippet from `hooks/README.md`.

## Anti-patterns — if you see these, the skill is not being followed

- The brain runs `grep -r` or `Read` on a file it has never seen, "just to check".
- A brief with no DONE WHEN or no RETURN cap.
- Accepting "all specs pass" from a builder without a verifier run.
- `subagent_type: "fork"` for a lookup.
- Retrying a failed builder with the same brief.
- One builder briefed with three tasks joined by "and then".
- A 60-file `git diff` read in the brain instead of `--stat` plus two targeted files.
- Starting at opus because the task "feels important". Importance goes into the brief and
  the verification, not the tier.

## Interaction with other skills

- `own-it` — always the brain. Receipts give it §3 (each edit and why); the verifier gives
  it §4 (verify it yourself). If a receipt is too thin for `own-it`, the brief's RETURN
  clause was too thin.
- `git-commit` — the brain, after `own-it`. Builders never commit.
- `handoff` — fork or brain; record tiers used.
- Project skills (`rails`, `rspec`, `frontend` in this repo; whatever the project ships) —
  name them in the builder's CONTEXT so the builder invokes them first. The brain does not
  load them into its own context.
- `review-mr` — the brain owns verdicts and every outbound note; scouts do the reading,
  verifiers run the specs.

## Measuring — the skill is an experiment until the data says otherwise

`session-cost` (in `~/dev/claude-config/bin`, linked to `~/.local/bin`) sums token usage
per session, per model, and main-vs-subagent from the local transcripts under
`~/.claude/projects/`. The SessionStart hook labels each session with whether the
headroom proxy was on (`claude-hr`) and any `ORCHESTRATE_LABEL`. The protocol, arms,
confounders, and results log are in `~/dev/claude-config/experiments/RUNBOOK.md`.

The number to watch for this skill is **fable `main` input+cache tokens per user turn**.
If it is not falling relative to the pre-skill baseline, the brain is still reading; look
at hook denials and the anti-patterns above.
