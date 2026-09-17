---
name: handoff
description: Writes end of session handover/handoff note to capture details of what was achieved in this session.
model: haiku
---

When writing a handoff:
- Write to `docs/HANDOFF.md` at the project root. It is the single tracked handoff file —
  **overwrite** its `## Latest` section (or the whole file, if no such structure exists yet) with
  this session's handoff. Never write to a `handoff/` directory and never create a numbered
  handoff file (e.g. no `docs/adr/NNNN-handoff-*.md` — that convention is retired).
- Sections, in this order:
  - **Intent** — what this session set out to do and why.
  - **What shipped** — with commit shas.
  - **Steers** — the user's explicit asks/directives, verbatim, in the order given; what they
    cared about most.
  - **Open gates** — anything still blocking (human sign-off, unpushed commits, pending review).
  - **Next session** — where to start, what to parallelize, any dependency chain to honor.
  - **Model table** — models used this session (driver / design-and-review / implementation),
    plus spend if known.
- Keep it a thin state-transfer, not a re-stated backlog — task state belongs on GitHub issues,
  not in the handoff.
