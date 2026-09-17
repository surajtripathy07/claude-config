---
name: pending-decisions
description: Surface every pending maintainer decision/action with enough context to decide on the spot. Reads the latest handoff, Proposed design docs in docs/design/, Status lines in docs/DECISIONS.md, and open issues; presents each blocking item as a decision brief with selectable options; records the outcomes so work unblocks.
---

# Pending decisions — the sign-off conversation, made cheap

Purpose: the maintainer should be able to sit down, run this, and clear every decision that is blocking work — each one presented with just enough context to decide, as a selection wherever possible.

## 1. Gather (delegate — do not burn driver context)

Dispatch a `scout` agent (see the `orchestrate` skill) to sweep, in this order, and return a structured list:

- **`docs/HANDOFF.md`**'s `## Latest` section — especially "Next session", "sign-off", "Decisions made", "flagged".
- **Design docs in `docs/design/` whose status is Proposed** (or containing "awaiting sign-off", "decision needed", "open question", "OQ"). Capture each open call, its options, and any provisional values that must not freeze without validation.
- **`docs/DECISIONS.md` entries without a terminal `Status:`** (not yet `Accepted` or `Superseded by D-NNN`) — these are open calls too.
- **Open GitHub issues** (`gh issue list`) mentioning a maintainer call, "HUMAN GATE", "decision", or blocked-on labels; plus any issue the handoff names as gated.
- **Branch state**: unpushed commits, un-merged branches, anything the handoff flags for "morning review".

De-duplicate against what is already decided: a design doc or `docs/DECISIONS.md` entry marked Accepted/Superseded, an issue comment recording the call, or the handoff noting sign-off received. Never re-ask a settled question.

## 2. Build a decision brief per item

Every surfaced item gets, in one tight block:

- **The decision** — one sentence, concrete ("Accept ADR NNNN's option d", not "review the ADR").
- **Context** — why it exists, what evidence supports it (validation numbers, audit results, costs), in 2–4 sentences a non-refreshed reader can absorb.
- **What it blocks** — the work that starts the moment this is decided.
- **Recommendation** — the option the evidence favors, with the one-line reason. There is almost always a recommendation; "no recommendation" needs a stated reason.
- **Reversibility / risk** — can it be undone, and what it costs if wrong.

Order items by **unblocking power**: the decision that releases the most queued work goes first.

## 3. Present — selections wherever possible

- Use **AskUserQuestion** for every item that reduces to 2–4 options (accept/reject/modify, option a/b/c, kill/keep). Recommended option first, labeled "(Recommended)". Batch up to 4 related decisions per call; group by theme (one ADR's calls together).
- Items that are **actions, not choices** (eyeball a graph, review a diff, push a branch) are listed separately as a short checklist with direct pointers (URL, file path, command) so each takes one click/command to start.
- Long tail: if there are more than ~8 decisions, present the blocking tier first, then ask whether to continue into the nice-to-have tier.

## 4. Record outcomes — a decision that isn't written down didn't happen

For each decision taken, immediately:

- Update the **design doc or `docs/DECISIONS.md` status line** (Proposed → Accepted/Superseded by D-NNN, with date and any modifications inline).
- **Comment on the linked issue** with the call and its rationale; close issues the decision kills.
- Note deferred/skipped items explicitly — they carry to the next run, not into oblivion.
- Finish with a one-screen summary: decided / deferred / newly unblocked work, and offer to dispatch the unblocked work per `/operating-mode` (this skill decides; it does not build).

## Guardrails

- This skill is **read-and-record only** — no implementation, no migrations, no data runs. Dispatching unblocked work happens only after the maintainer confirms.
- Present evidence, not advocacy: if an adversarial review or validation report contradicts the recommendation, say so in the brief.
- If context for an item is too thin to decide, say what is missing and offer "gather more" as an option rather than forcing a guess.
