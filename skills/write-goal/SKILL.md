---
name: write-goal
description: Write a goal file into docs/goals/ following the enforced YYYY-MM-DD_<summary>_goal.md naming. Synthesizes the goal from whatever repo state is available — open GitHub issues, a handoff note, recorded decisions, design docs — falling back to just what the user states directly if none of that exists. Produces a file a future Claude session can execute against without re-deriving context.
---

# write-goal — turn repo state into an executable goal file

Purpose: the user says "write a goal" (optionally with a topic, e.g. `/write-goal ship pass-1`)
and gets a file in `docs/goals/` that a fresh Claude session can pick up and execute without
re-reading the whole repo history.

Nothing here is required to exist first. `docs/goals/` is created (`mkdir -p`) if missing;
every other source below is used only if present.

## 1. Gather (delegate — do not burn driver context)

Dispatch one `scout` agent (see the `orchestrate` skill, if this repo has it — otherwise just
gather this directly) to collect, and return structured, whatever of these exist:

- `gh issue list --state open --limit 100` — number, title, labels; flag anything the user's
  topic matches. Skip if `gh` isn't set up or the repo has no issue tracker.
- `docs/HANDOFF.md`'s `## Latest` section — "Next session" / unblocked-work content, if the
  file exists.
- `docs/DECISIONS.md` entries with **Status: Accepted**, if the file exists — a settled
  decision the goal should build on, not re-litigate.
- `docs/design/*.md` docs whose build isn't shipped yet, if the directory exists — a natural
  work queue for a goal.

If the user stated the goal explicitly, gathering only needs to fill in linked issues, gates,
and verification — not invent the goal. If none of the above exists (a fresh repo, or one
that doesn't use this doc layout), gather nothing and build the goal from what the user said
plus a quick look at the codebase.

## 2. Draft — what makes a goal file effective for a Claude session

The consumer is a future session with zero context. Optimize for that:

- **Goal**: one sentence, an *outcome*, not an activity. "Pass-1 emits validated claims[]
  with the stopgap deleted" — not "work on extraction".
- **Why now**: 2–3 sentences. What decision/merge unblocked it; what delaying costs
  (dollars, drift, blocked work). Cite evidence with numbers where the repo has them.
- **Definition of done**: only criteria a session can *verify mechanically* — a command that
  exits 0, a test count, a page state, a row count, a cost ceiling. Never "improved" or
  "better". Each criterion gets its verification command in §Verification.
- **Work queue**: ordered steps. Each step carries: its issue `#N` or design doc if one
  exists, the gate if one applies (sign-off, fresh adversarial review, HUMAN GATE), and what
  evidence closes it. A session should be able to start at the first unchecked step.
- **Non-goals**: the adjacent work most likely to cause scope creep, named explicitly, with
  where it lives instead (issue number or "future goal").
- **Verification**: exact commands and URLs, one per done-criterion — whatever this repo
  actually uses (its build/test/lint/typecheck commands, `gh issue view`, a local dev server
  URL, etc.). Look at how the repo verifies itself elsewhere rather than assuming a stack.
- **Loop condition**: a final section containing one ready-to-paste line for Claude Code's
  **built-in `/goal` command** (`/goal <condition>` — a small model evaluates the condition
  after every turn and the session keeps running until it holds). Write the condition for
  that evaluator, not for a human:
  - It must be checkable from **observable state**: checkbox counts in this file, a command
    that exits 0, an issue's closed state — never judgment words ("done well", "clean").
  - Anchor it to this file: the canonical form is
    `/goal every checkbox in docs/goals/<this-file> is checked and its status is done`.
  - Keep it one sentence; the evaluator is cheap and literal.

**Checkboxes are the loop's shared state.** Write every Definition-of-done criterion and
every work-queue step as a markdown checkbox (`- [ ]`). Executing turns check items off in
the file as evidence lands; the `/goal` evaluator reads the same file to decide whether to
stop. State the rule in the goal file itself: *a box is only checked in the same turn its
verification command actually passed.* This is what makes the file loop-driving rather than
documentation.

Frontmatter (machine-read):

```yaml
---
status: active
written: YYYY-MM-DD
issues: [..]
decisions: [..]
---
```

## 3. Write — naming is enforced

- `mkdir -p docs/goals` first if it doesn't exist yet.
- Path: `docs/goals/YYYY-MM-DD_<kebab-case-summary>_goal.md` — date is today, summary is
  2–6 lowercase hyphenated words, suffix `_goal.md` literal.
- Refuse any other name or location. If `docs/goals/README.md` exists, follow its rules for
  the slug too; if it doesn't, the naming convention above is the whole rule — no need to
  create that README just to satisfy this skill.
- If a goal file with `status: active` already covers the same work, update that file
  instead of writing a second active goal for it — surface the overlap to the user.

## 4. Hand back

Show the user: the goal file path, its Definition of done, and the ready-to-paste `/goal`
loop line. Ask nothing unless a blocking choice surfaced during gathering (use
AskUserQuestion only then). Do not start executing the goal — writing and executing are
separate requests; the user starts the loop by pasting the `/goal` line (optionally with
auto mode for unattended runs), and stops it any time with `/goal clear`.

## Lifecycle

- Executing sessions check off work-queue steps and, when all done-criteria verify, flip
  `status: done` with evidence inline.
- A goal overtaken by events gets `status: abandoned` plus one line on why — never deleted.
