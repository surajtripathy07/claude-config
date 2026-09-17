# Phase 1 — Ground in the problem the MR is solving

The goal is to be able to state, in the issue's own words, what was asked, and in the
code's own names, how the MR meets it. Until both halves are written down the review has
not started.

## 1. Pull everything the MR points at

```sh
GL=/opt/homebrew/opt/glab/bin/glab
$GL mr view <iid>                                   # title, labels, reviewers, description
$GL api "projects/:id/merge_requests/<iid>"          # JSON: description, source_branch, sha, pipeline
$GL api "projects/:id/merge_requests/<iid>/discussions?per_page=100"   # all threads
$GL mr issues <iid>                                  # issues the MR closes / mentions
```

`:id` is `gitlab-org%2Fcustomers-gitlab-com` or `gitlab-org%2Fgitlab` (URL-encoded path).
Use `?per_page=100&page=N` when a list may exceed 100.

Then follow **every** link in the description, in this priority:

1. Issues (`#123`, `group/project#123`, full URLs). Read the issue body, then the whole
   discussion with `glab api projects/:id/issues/<iid>/discussions?per_page=100`. Product
   decisions often live in a comment, not the body. Note the author of each decisive
   comment and the date.
2. Other MRs referenced (`!456`). Read their description; if the MR says "removed in
   !456", check the diff of !456 actually did that.
3. Docs links (handbook, docs.gitlab.com, design docs). Fetch with WebFetch and quote the
   sentence the MR relies on.
4. Epics, Slack links, Figma. Slack and Figma need the user; note them as "not read" and
   ask the user to paste the relevant part if it matters.

For history questions ("why was this changed before?", "who owns this?") in
customers-dot, use the Orbit MCP query templates in `doc/agents/orbit-queries.md`.

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

The MR template in both repos asks for four things. Record present / missing / weak:

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

1. `reviewers` on the MR (from `glab mr view`).
2. Labels: `~database` plus `~"database::review pending"` means a DB review is open;
   `~"database::approved"` means it is done.
3. Danger's roulette comment. Danger is the CI bot that posts a comment headed
   `## Reviewer roulette` with a table `Category | Reviewer | Maintainer`. In customers-dot
   it posts as a project bot user (`project_<id>_bot_<hash>`), in gitlab-org/gitlab as
   `gitlab-bot`. Parse the table: if the user's handle is in the `database` row, they are
   the database reviewer or maintainer for this MR.

Record the role. If none of the three sources names the user, ask them which hat they are
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
