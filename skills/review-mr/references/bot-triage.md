# Phase 2 — Triage the automated reviewer's comments

Many projects have an automated reviewer — an AI review bot, a linter bot, a CI policy bot —
that comments on every change request before a human does. **Check the profile for which
bot (if any) reviews this project, under which username, and in what comment format.** If
the profile names none, this phase is `n/a` and recorded as such; do not go looking for one.

A profile entry for a bot records: its username, whether it posts a summary note plus
per-finding diff notes or only one of the two, whether its notes are resolvable, and where
its instruction/config file lives so its comment conventions can be read.

Concrete example of what such an entry documents (GitLab profile): GitLab Duo Code Review
is GitLab's built-in AI reviewer, added as a reviewer and posting under the username
`GitLabDuo`; its comments follow the repo's `.gitlab/duo/mr-review-instructions.yaml`,
which asks for Conventional Comments (`suggestion (non-blocking): ...`,
`issue (blocking): ...`). A GitHub project's profile would document its own bot the same
way, or record that there is none.

## What the bot posts

Observed shape for the GitLab Duo example:

- One **summary note**: `type: null`, not resolvable, no position. Lists what it flagged and
  gives an overall read ("well-scoped and well-tested ...").
- One **diff note per finding**: `type: "DiffNote"`, `resolvable: true`, with `position`
  holding `new_path`, `new_line`, `head_sha`. Body starts with the Conventional Comments
  label and often carries a ```` ```suggestion ```` block.

Fetch the threads with the profile's CLI and filter to the bot's username. With the GitLab
profile (`glab`); a GitHub profile documents the equivalent `gh` call and JSON shape:

```sh
GL=/opt/homebrew/opt/glab/bin/glab
$GL api "projects/:id/merge_requests/<iid>/discussions?per_page=100" \
  | python3 -c '
import sys, json
BOT = "GitLabDuo"   # from the profile
for d in json.load(sys.stdin):
    n = d["notes"][0]
    if n["author"]["username"] != BOT: continue
    pos = n.get("position") or {}
    print(d["id"], n["id"], n["type"], pos.get("new_path"), pos.get("new_line"),
          "resolved" if n.get("resolved") else "open", len(d["notes"]) - 1, "replies")
    print(n["body"]); print("=" * 60)'
```

Keep the thread/discussion ID for replies and the note ID for reactions.

## Triage each diff note

For every diff note the bot left, in the record's bot-triage table:

| # | file:line | bot's label | bot's claim (one line) | Verdict | Reasoning | Draft |
|---|---|---|---|---|---|---|

Verdicts:

- **agree** — I opened the code at the note's path and line, the claim holds, and the fix
  the bot suggests is the fix I would ask for. Draft: 👍 reaction on the note. If the
  suggestion block is wrong in detail but the point is right, draft a short reply instead of
  a reaction.
- **agree, already addressed** — the head commit has moved and the code now differs. Draft:
  nothing; note it so the user is not surprised by an open thread.
- **disagree** — the claim is false or the trade-off is intentional. Draft a reply that
  states the mechanism, in Conventional Comments: `note: ...` or `thought: ...`. Never a
  bare "disagree".
- **needs author** — the claim depends on intent I cannot verify. Draft a `question:` to
  the author in the same thread.
- **out of scope for me** — e.g. the bot raised a frontend nit and I am the database
  reviewer. Record it, draft nothing, mention in Phase 6 so the user can choose.
- **disagree with the author's resolution** — the thread is already resolved and the
  author's reply is an assertion ("intentional", "that deployment type only") rather than a
  mechanism, and the code still supports the concern. Do not unresolve or reply inside the
  bot's thread. A new thread of the user's own on the same line is allowed, but its context
  block must quote and link **both** the bot's note and the author's reply (per-note
  permalinks), so the author can see the earlier exchange was read and what is new. One
  thread per point still holds: this new thread is the only place the point is raised again.
  (Seen in practice on a review where the new thread engaged the author's comment but did
  not link the resolved bot thread.)

Do not resolve threads. Do not reply to the summary note unless it misstates the change.

Also read any **CI policy bot** comment the profile names (warnings such as commit message
length, missing milestone, a missing schema-dump update, "requires a database review"). Its
warnings that are still true are findings the author should fix; record them.

## Drafting the reaction

Reactions and replies are outbound and gated like everything else. Queue entries:

```
type: reaction  target: note <note_id>          text: thumbsup
type: reply     target: thread <thread_id>      text: <Conventional Comment>
```

Posting mechanics live in `posting.md`.
