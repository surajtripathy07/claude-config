# Phase 2 — Triage GitLab Duo's review comments

GitLab Duo Code Review is the built-in AI reviewer. It is added as a reviewer
(`@GitLabDuo`) and posts under the username `GitLabDuo`. Its comments follow the repo's
`.gitlab/duo/mr-review-instructions.yaml`, which asks for Conventional Comments
(`suggestion (non-blocking): ...`, `issue (blocking): ...`).

## What Duo posts

Observed shape (customers-dot MR !17039, 2026-09):

- One **summary note**: `type: null`, not resolvable, no position. Lists what it flagged and
  gives an overall read ("well-scoped and well-tested ...").
- One **DiffNote per finding**: `type: "DiffNote"`, `resolvable: true`, with `position`
  holding `new_path`, `new_line`, `head_sha`. Body starts with the Conventional Comments
  label and often carries a ```` ```suggestion ```` block.

Fetch:

```sh
GL=/opt/homebrew/opt/glab/bin/glab
$GL api "projects/:id/merge_requests/<iid>/discussions?per_page=100" \
  | python3 -c '
import sys, json
for d in json.load(sys.stdin):
    n = d["notes"][0]
    if n["author"]["username"] != "GitLabDuo": continue
    pos = n.get("position") or {}
    print(d["id"], n["id"], n["type"], pos.get("new_path"), pos.get("new_line"),
          "resolved" if n.get("resolved") else "open", len(d["notes"]) - 1, "replies")
    print(n["body"]); print("=" * 60)'
```

Keep `d["id"]` (discussion ID) for replies and `n["id"]` (note ID) for awards.

## Triage each diff note

For every Duo DiffNote, in the record's Duo triage table:

| # | file:line | Duo's label | Duo's claim (one line) | Verdict | Reasoning | Draft |
|---|---|---|---|---|---|---|

Verdicts:

- **agree** — I opened the code at `new_path:new_line`, the claim holds, and the fix Duo
  suggests is the fix I would ask for. Draft: 👍 award on the note. If the suggestion block
  is wrong in detail but the point is right, draft a short reply instead of an award.
- **agree, already addressed** — the head SHA has moved and the code now differs. Draft:
  nothing; note it so the user is not surprised by an open thread.
- **disagree** — the claim is false or the trade-off is intentional. Draft a reply that
  states the mechanism, in Conventional Comments: `note: ...` or `thought: ...`. Never a
  bare "disagree".
- **needs author** — the claim depends on intent I cannot verify. Draft a `question:` to
  the author in the same thread.
- **out of scope for me** — e.g. Duo raised a frontend nit and I am the database reviewer.
  Record it, draft nothing, mention in Phase 6 so the user can choose.
- **disagree with the author's resolution** — the thread is already resolved and the
  author's reply is an assertion ("intentional", "SaaS only") rather than a mechanism, and
  the code still supports the concern. Do not unresolve or reply inside the Duo thread. A
  new thread of the user's own on the same line is allowed, but its context block must
  quote and link **both** Duo's note and the author's reply (`#note_<id>` URLs), so the
  author can see the earlier exchange was read and what is new. One thread per point still
  holds: this new thread is the only place the point is raised again. (Seen on !17037,
  `enriched.rb:258`, where the new thread engaged the author's comment but did not link
  the resolved Duo thread.)

Do not resolve threads. Do not reply to the summary note unless it misstates the change.

Also read the **Danger** comment on the MR (warnings such as commit message length, missing
milestone, missing `db/structure.sql` update, "requires a database review"). Danger
warnings that are still true are findings the author should fix; record them.

## Drafting the reaction

Awards and replies are outbound and gated like everything else. Queue entries:

```
type: award   target: note <note_id>          text: thumbsup
type: reply   target: discussion <disc_id>    text: <Conventional Comment>
```

Posting mechanics live in `posting.md`.
