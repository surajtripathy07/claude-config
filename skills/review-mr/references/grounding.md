# Phase 1 — Ground in the problem the change request is solving

The goal is to be able to state, in the issue's own words, what was asked, and in the
code's own names, how the change meets it. Until both halves are written down the review has
not started.

"Change request" here means whatever the host calls it — a merge request on GitLab, a pull
request on GitHub. The profile names the term and the CLI; use the project's own vocabulary
in anything the user or the author reads.

## 1. Pull everything the change request points at

Three things are needed, whatever the host: **the change request's metadata** (title,
labels, reviewers, description, head commit, pipeline state), **the issues it closes or
mentions**, and **every discussion thread on it**. The profile says which CLI provides them.

With the GitLab profile (`glab`):

```sh
GL=/opt/homebrew/opt/glab/bin/glab
$GL mr view <iid>                                   # title, labels, reviewers, description
$GL api "projects/:id/merge_requests/<iid>"          # JSON: description, source_branch, sha, pipeline
$GL api "projects/:id/merge_requests/<iid>/discussions?per_page=100"   # all threads
$GL mr issues <iid>                                  # issues the MR closes / mentions
```

`:id` is the URL-encoded project path (e.g. `namespace%2Fproject`), from the profile or
`git remote get-url origin`. Use `?per_page=100&page=N` when a list may exceed 100.

A GitHub profile uses `gh`'s equivalents (`gh pr view`, `gh api` against the pulls and
issues endpoints); the profile documents the exact calls and the field names its JSON uses.
Do not improvise commands for a host whose profile does not document them — ask the user.

Then follow **every** link in the description, in this priority:

1. Issues (`#123`, `group/project#123`, full URLs). Read the issue body, then the whole
   discussion — on the GitLab profile
   `glab api projects/:id/issues/<iid>/discussions?per_page=100`, on another host the
   profile's equivalent. Product decisions often live in a comment, not the body. Note the
   author of each decisive comment and the date.
2. Other change requests referenced (`!456`, `#456`). Read their description; if this one
   says "removed in !456", check that the diff of !456 actually did that.
3. Docs links (internal handbook, product docs, design docs). Fetch with WebFetch and quote
   the sentence the change relies on.
4. Epics, Slack links, Figma. Slack and Figma need the user; note them as "not read" and
   ask the user to paste the relevant part if it matters.

For history questions ("why was this changed before?", "who owns this?"), check the
project's own doc for history-query tooling (e.g. an MCP query template file) before
falling back to `git log` / `git blame` by hand.

## 2. Write the Understanding section

```
### 1 Understanding

**The ask (issue #N, in its words):** ...
**Acceptance criteria stated in the issue:** quoted verbatim, numbered, each with a link to the issue; later references say "the issue's third acceptance criterion" and re-quote it, never "AC3" / none stated
**Decisive comments:** who said what, when (link)
**What the MR claims:** ...
**Mechanism (as the code names it):** class A validates X because ...; flag F gates ...
**Where claim and ask diverge or the description is silent:** ...
**Out of scope per the MR:** ...
```

Every line in "Mechanism" must point to a file:line in the diff. If I cannot connect an
issue requirement to a diff hunk, that is a gap, and it is written down.

## 3. Check the description itself

Most change-request templates ask for four things (the profile names the project's own
template and any extra sections it requires). Record present / missing / weak:

| Item | Present means |
|---|---|
| What and why | A reader can tell the problem and the mechanism without opening the diff |
| Test steps | Numbered, concrete, start from a clean local state, name the URL or console command |
| Feature flags | Every flag the diff reads is listed with how to enable it locally |
| Screenshots | Before/After for every visible UI change; recording for multi-step flows |

Missing test steps or missing screenshots on a UI change are drafted requests to the
author (queue). Do not soften them; the user decides the tone when they see the draft.

## 4. Determine the user's role

The review's mandatory set depends on role. Sources, in order:

1. The **reviewers assigned** on the change request (GitLab profile: `glab mr view`;
   another host: the profile's equivalent).
2. **Labels** that mark a specialist review as open or done. The profile lists the
   project's own label vocabulary — e.g. a `database` label plus a "review pending" state
   label means a database review is open, and an "approved" state label means it is done.
3. **The reviewer-assignment bot's comment**, if the profile names one. Such a bot posts a
   table of `Category | Reviewer | Maintainer` rows; the profile records the bot's username
   and the comment's heading so the table can be found and parsed. If the user's handle is
   in the row for a specialty (database, frontend, …), they hold that role on this change.

Record the role. If none of these sources names the user, ask them which hat they are
wearing before Phase 4.

## 5. Draft the understanding-confirmation comment

Always drafted, in the standard comment shape (point → quoted and linked context → bullets
→ ask; see `posting.md` § Format). It quotes the issue's proposal and the MR's mechanism
with links rather than paraphrasing them, and ends "Is that right, or am I missing a piece?"
Add one concrete question per gap found in § 2. Put it in the outbound queue as
`type: diffnote, target: <line that declares the thing being confirmed>, status: draft`.
In Phase 6 it is **folded into an overlapping finding/question thread** if one exists (same
mechanism, same ask) and dropped as a separate comment; only a gap no other thread covers
keeps its own thread. Tell the user whether the understanding is confident (they may drop
it) or uncertain (it must go out, folded or not, before findings are built on it).
