---
name: review-mr
description: Author-depth review of a merge request or pull request for any project with a per-project profile defined under `profiles/`. Grounds in the linked issue, triages automated review-bot comments, checks the branch out and runs the targeted tests, applies the canonical database / backend / frontend review checklists, reproduces the author's testing steps locally, and gates every outbound note, reply, emoji, label, or approval behind an own-it walkthrough and the user's explicit go. Use when asked to review an MR or PR, when given a change-request URL or number with "review", or when the user has been tagged as reviewer, maintainer, or database reviewer.
model: sonnet
---

# review-mr — review a change the way its author would have to defend it

**Vocabulary and tooling come from the profile, not from this file.** Hosts differ: GitLab
calls the unit of review a *merge request* (`glab`, identified by an IID), GitHub calls it a
*pull request* (`gh`, identified by a number). This file says **change request** where the
host's own word should be used, and **the CLI** where the profile's command belongs. Use the
project's vocabulary in everything the user or the author reads; keep the mechanics below
exactly as they are, since none of them depend on the host.

Purpose: produce a review the user can own end to end, at the depth of someone who did
every step themselves. Every finding carries the evidence that produced it and the command
that reproduces it. At the end, `own-it` is run on the review itself (Phase 6), and every
question to the author or a domain expert is posted only on the user's explicit go. Nothing
is assumed that could have been verified or asked.

The reader of the review record is the user: a strong engineer who may not have looked at
this corner of the system. Gloss every named thing on first use.

## Hard rules

1. **Nothing leaves the machine without a go.** No note, reply, thumbs-up, label, approval,
   or "request changes" is sent until that exact item has been shown to the user, walked
   through with `own-it`, and the user has said go for that item. Approval of one item is
   not approval of the next. This includes 👍 reactions on a review bot's notes.
2. **Never approve or merge the change request.** Approval is the user's act, done by hand.
3. **Ask, do not assume.** An inference about intent, business rule, load shape, or rollout
   that cannot be verified from code, docs, or the issue becomes a drafted question to the
   author or the named domain expert, not a finding.
4. **Reproduce, do not read about.** Phase 5 (follow the author's test steps) is mandatory.
   Skipping any part of it must be stated in the record with the reason.
5. **Read-only on the branch.** Never commit, push, amend, or edit tracked files on the
   author's branch. Local scratch (flags, seed data, console sessions) is fine.
6. **Leave the machine as it was found — but only when the user says so.** Branch,
   working tree, database schema and data, feature flags, and running processes are
   captured in Phase 0 and restored in Phase 8. The restore is verified against the
   baseline, not assumed. Phase 8 runs **only after the user has said the review is done**
   ("we're done", "revert", "restore"); until then the author's branch stays checked out and
   runnable so the user can test or debug alongside. Always confirm before reverting.
7. **Targeted specs locally; the full suite is CI's job.** Run the specs that the change
   touches or that exercise the changed classes, then read the CI pipeline for the rest.
   Never claim "all specs pass" from a targeted run.
8. **Hedged answers are not decisions.** If the user answers a gating question with "I
   guess" / "sure?" / "whatever", stop, run `own-it` § Asking properly, ask again.
9. **Quote, link, then reason — never abbreviate.** Anything referenced from outside the
    text the reader is looking at (an issue's acceptance criterion, a line of code, a
    comment, a doc sentence) is copied verbatim as a `>` quote with a link to its exact
    position (the host's permalink to a comment or heading anchor, a file link with the line
    anchored at the head commit, a note permalink). **No abbreviations or invented labels of
    any kind** — not "AC3", not "F1"/"Q2", not "the finder", "the helper", and no in-house
    acronym for a product, deployment type, or datastore: write the thing out ("the
    issue's third acceptance criterion", the full product name, the datastore's full name,
    "the category-filter thread"). Internal queue ids stay inside the record and are never
    used in a message to the user or the author. Applies to posted comments, to questions
    to the user, and to the review record's prose.
10. **Write for a reader who knows nothing about this corner.** Every outbound comment and
    every question to the user is written as if the reader has never seen this code, this
    issue, or this reviewer's earlier thinking. Lead with the one-sentence point, then walk
    the reasoning as short bullets (one step per bullet, with its evidence), then the ask.
    No wall of text: prefer four bullets to a paragraph, and one idea per bullet.
11. **Local state is described as a scenario, never as identifiers.** Account and
    subscription names, record ids, dates and row counts from the reviewer's own database
    mean nothing to the author. In outbound comments, describe *what was set up* and *what
    happened* in words ("one account, three users, one of whom used more than their
    included allocation on a single day"), give the numbers only as the relationship that
    matters ("the allocation-based series showed 58, the record-based series 75"), and put
    the exact reproduction (ids, script) only in the review record. If a reader outside this
    machine could not act on a detail, it does not go in the comment.
12. **Comments must be indistinguishable from a review done by hand in the host's web UI.**
    Objectively, that means: (a) exactly **one change-request-level summary note** on the
    review page plus **one diff note per point** on the exact line in the current diff
    version; nothing else at that level; the summary is posted **after** the diff notes and is a reply
    in the author's review-request thread when one exists; (b) one thread per point, no
    duplicate or placeholder
    bodies, no literal file paths, variable names, or tool output in a body; (c) each body
    reads as one person's reasoning: Conventional Comments label, the quoted context with a
    link, three to six bullets, one ask; (d) nothing is posted until its body and anchor
    have been shown to the user and the response of the previous post has been verified
    (the note came back as a diff note, anchored to the intended file and line, its body
    starting with the expected first line). A misplaced or malformed post is deleted or
    fixed immediately and reported. Posting mechanics that have been verified to work are in
    `references/posting.md` (written against the GitLab profile; a profile for another host
    documents its own equivalents); do not improvise new ones during a review. The canonical
    shape of a summary and of a diff note is `references/exemplar.md`; match it.
13. **Everything the user is asked to approve is shown inline, in full.** Drafted comments,
   replies, suggestion blocks, label changes, and the exact text of any question to a
   domain expert appear verbatim in the message that asks for the go. Never ask the user to
   open a file, a URL, or the record to see what they are approving.

## Inputs

- Change-request reference: number/IID, URL, or branch. If absent, ask for it before
  anything else.
- Repo: detected from `git remote get-url origin`. Load the matching profile at
  `profiles/<project-path-with-slashes-replaced-by-dashes>.md` (e.g.
  `acme/web-app` → `profiles/acme-web-app.md`). If no profile file exists for
  this repo, **stop and ask the user to create one before proceeding.** Do not
  improvise any of it from memory; wrong assumptions here (e.g. the wrong bot username for
  parsing the reviewer-assignment table) silently break Phase 4 role detection.
- **Everything host-specific comes from the profile.** At minimum a profile records:
  - the **host and CLI** — GitLab via `glab` (aliased `gl` in this user's shell; in scripts
    use the full path, e.g. `/opt/homebrew/opt/glab/bin/glab`, with raw API calls through
    `glab api`), GitHub via `gh`, or another host's tool — and the exact commands for
    viewing a change request, its diff, its discussions, and its CI status;
  - the **terminology** the project uses (merge request / pull request; IID / number) and
    the reference syntax for issues and change requests (`!123` vs `#123`);
  - the **review bot**, if any: its username, comment format, and config file (see
    `references/bot-triage.md`);
  - the **reviewer-assignment bot** and its comment heading, plus the project's specialist
    **label vocabulary** for role detection;
  - the **local stack**: language and framework versions, and which of this skill's
    checklists apply at all (`references/backend.md`, `database.md`, `frontend.md` each
    open with an "Applicability" section the profile narrows);
  - the **commands**, verbatim, for: checking a change request's branch out; installing
    dependencies; running migrations, rolling them back, and reading migration status;
    linting, per ecosystem (the backend linter, the frontend linter, any formatter);
    running tests, per suite (the backend test runner and the frontend test runner are
    usually different commands); running a one-off script or console snippet;
  - the **paths and conventions**: the **category map** that buckets changed files into
    database / backend / frontend / test / docs (Phase 0 step 4 and `frontend.md`'s
    applicability table both read it); the project's **change-request template** fields, so
    Phase 1 can tell a missing section from an absent one (`references/grounding.md`);
    **skill routing**, if the repo ships its own per-area skills this review should use
    instead of generic ones;
  - the **data and environment access**: how to snapshot and restore the local database and
    the exact connection flags (`references/restore.md`), how to reach a production replica
    or query-plan service if the project has one (`references/database.md`), where
    **feature flags** live and how to read and toggle them locally, and the **ownership
    sources** for finding a domain expert.

  Anything on this list the project does not have is recorded in the profile as `n/a` with
  a reason, so a review can tell "not applicable" from "not yet written down".

## The review record

One file per change request, outside any repo so it can never be committed by accident
(`<id>` is the host's identifier — IID on GitLab, PR number on GitHub):

```
~/.claude/reviews/<project>/<id>/review.md      the record (sections below, in order)
~/.claude/reviews/<project>/<id>/artifacts/     screenshots, plans, spec output, console logs
```

Every phase appends its section before the next phase starts, so a long session survives
context compaction. The record's sections, in order:

```
0 Setup          role, profile, changed-file categories, pipeline status, BASELINE
1 Understanding  the ask, how the change claims to meet it, gaps, description-quality check
2 Bot triage     one row per review-bot thread: verdict, reasoning, drafted reaction/reply
3 Branch + specs what ran, what passed, what failed (verbatim), what CI covers
4 Change review  4a root cause, hunk table, inputs walked, blast radius, tests, alternatives
                 4b per-item verdict for each applicable domain checklist
5 Reproduction   the author's steps, what I did, what I saw, artifacts
6 Findings       ranked, Conventional Comments format, evidence per finding
7 Outbound queue every drafted item, its status (draft / shown / approved / posted / dropped)
8 Restore        baseline vs. after, per item: restored / verified / could not restore
```

## Phases

### Phase 0 — Setup

1. Detect repo, load profile, note the change request's id and URL. Create the record.
2. View the change request with the profile's CLI (GitLab: `glab mr view <iid>`) for title,
   author, labels, reviewers, milestone, description.
3. Determine **the user's role on this change** from the reviewers list, the project's
   specialist labels, and the reviewer-assignment bot's table if the profile names one (see
   `references/grounding.md` § 4 Determine the user's role). One of: reviewer, maintainer, database reviewer,
   database maintainer, not assigned. Confirm with the user if ambiguous. The role changes
   what is mandatory in Phase 4.
4. Pull the diff (GitLab: `glab mr diff <iid>`) and the changed-file list. Bucket files by
   the profile's category map (database / backend / frontend / test / docs). Record which
   Phase 4 checklists apply.
5. Read the CI pipeline status the profile's way (GitLab: `glab ci status` on the checked-out
   branch, or the pipelines endpoint for the change request). Record failing jobs by name.
6. **Capture the baseline** before touching anything. Follow `references/restore.md`
   § Baseline. At minimum: current branch and HEAD, `git status --porcelain`, stash list
   length, which app processes are running and on which ports, the database snapshot
   (or the migration version if the profile says snapshots are too large), and the current
   state of every feature flag the change names. Write it to the record's Setup section and to
   `artifacts/baseline/`. If the working tree is dirty, stop and ask the user whether to
   stash; do not decide for them.

### Phase 1 — Ground in the problem

Follow `references/grounding.md`. Output: the **Understanding** section, which must answer:

- What is the ask, in the issue's words, with the issue's acceptance criteria if it has any.
- What does the change claim to do, and by which mechanism (name the classes / flows).
- Where the claim and the ask diverge, or where the description does not say how the
  change meets the ask.
- Description quality: what/why present, test steps present and concrete, feature flags
  listed, Before/After screenshots present for any UI change.

Then **always** draft an understanding-confirmation comment to the author: two to five
sentences stating what I believe the change does and why, ending with "Is that right?" If the
understanding is complete and confident, say so to the user and let them decide whether
it still goes out; if anything is unclear, it must go out. Both go into the outbound queue.
**Before Phase 6, check it for overlap:** if a finding or question thread already covers
the same point (same mechanism, same ask), fold the confirmation's ask into that thread's
last line and drop the separate comment. Two threads the author would answer with one
reply is padding. Only an understanding gap no other thread touches gets its own comment.

### Phase 2 — Triage the automated reviewer's comments

Follow `references/bot-triage.md`. **Check the profile for which review bot, if any, runs on
this project** — its username and comment format. Typically such a bot leaves one summary
note and one resolvable diff note per finding. For each thread: open the code at the note's
position, decide agree / disagree / needs author, write the reasoning, and draft the
reaction (👍) or reply. All drafts go into the queue. Never resolve the bot's threads; that
is the author's or user's act. If the profile names no bot, record this phase as `n/a`.

### Phase 3 — Check out the branch and run what the change touches

Follow the profile's "Branch and specs" section. In order:

1. Check the author's branch out with the profile's CLI (GitLab: `glab mr checkout <iid>`)
   only after the Phase 0 dirty-tree decision (stash with the
   user's go, or abort); never commit anything of the user's. Record whether the local
   branch existed before.
2. Dependencies: run the profile's dependency check for each ecosystem the project uses
   **even if the change did not touch a lockfile** — its base is usually newer than the
   user's branch, so dependencies can be missing. Install if needed; installing is additive
   and is recorded in `artifacts/baseline/created_files`.
3. **Make the change runnable locally.** Snapshot the dev database first (per
   the profile; seconds). Then run the profile's migrate command so that *both* the
   change's own migrations *and* any migrations its base carries that the local database
   lacks are applied; otherwise the running dev server errors on every request with a
   pending-migration error. Announce which migrations will run (from the profile's
   migration-status command, filtered to those not yet applied) in the message before
   running them; the user has authorised this step for review-mr, so do not block on a
   question. For the change's own migrations also roll back and re-migrate, confirm the
   schema dump has no diff beyond the change's own, and record timings
   (`references/database.md` § Local migration checks). Record
   every applied version in `artifacts/baseline/migrations_applied` for Phase 8.
3b. **Prove the local dev environment works on the author's branch before going further.** Phase 3
   ends with a health check against the user's running stack (per profile: `GET` the app
   root and the pages the change touches, one API call it changes, a console boot). Expected
   result: the app serves normally with the new code. If something the review set up is
   missing (dependencies, migrations, assets, a restart the profile allows), fix it and re-check.
   If the app is still broken and the cause is in the change (a migration that fails, a boot
   error, a broken route, a schema that no longer compiles), that is a **blocking finding**
   with the verbatim error, not an environment note — record it in § 3 and § 6 and carry on
   with the phases that do not depend on it. Never proceed to Phase 5 with a dev server
   that returns errors without having classified the cause as "ours" or "the change's".
4. Targeted specs: changed spec files, plus the spec that mirrors each changed source
   file, plus specs found by grepping the test tree for the changed class or module names.
   Frontend: the profile's frontend test runner for changed frontend specs and for the spec
   mirroring each changed component. Record the exact command and verbatim failures.
5. Lint the changed files only, with the profile's linters for each ecosystem.
6. Compare with CI: which jobs the change's pipeline ran and their state. A local pass plus a
   red pipeline is a finding; a local fail is a blocking finding with the output attached.

### Phase 4 — Review the change, then apply the domain checklists

**4a. Review the change against the problem.** Follow `references/change-review.md`. This
is the judgment part of the review and comes first: is the fix at the root cause or
downstream of it, does every hunk earn its place, does the logic hold on existing data,
boundaries, both flag states, retries and failure paths, what changes for callers and
persisted shapes outside the diff, do the tests actually fail without the change, and what
were the alternatives. Every conclusion carries file:line evidence or a console/spec
reproduction; every open point becomes a question with what was tried before asking.

**4b. Domain checklists.** For each applicable category, walk the reference file item by
item and record a verdict:
`pass` (with evidence), `fail` (with evidence, becomes a finding), `n/a` (with the reason),
or `unverified` (with what would verify it; becomes a question). No item is skipped
silently.

- Database → `references/database.md`. **Mandatory when the user is the database
  reviewer or maintainer:** every new or changed query has a plan from representative
  data; every new table has a stated access pattern and volume; every migration has a
  timing estimate. Missing plan = blocking question to the author, drafted for the queue.
  Where a plan cannot come from production, follow § Simulating load locally.
- Backend → `references/backend.md`, then the profile's skill routing (a project that ships
  its own language or framework skills routes to them; otherwise the project's own review
  docs).
- Frontend → `references/frontend.md`.
- Tests, docs, and anything else → the general acceptance checklist in
  `references/backend.md` § Acceptance checklist.

The `database` subagent (query evaluation and plan verification) may be used to read a
plan; its output is evidence, not a verdict, and the item is still recorded here.

### Phase 5 — Reproduce the author's testing

Precondition: Phase 3 step 3b passed (the dev environment serves the new code). Follow
`references/testing.md`. Take the change's "How to set up and validate locally" steps
(or whatever the project's template calls them) and execute them as literally as possible:
enable the listed flags the
profile's way, start the app, hand the UI steps to the `browser` agent (`orchestrate`
skill: scripted STEPS with EXPECT per step, a `PROFILE` clause, screenshots saved into
`artifacts/`; one browser agent at a time, continued via `SendMessage`; if it returns
`BLOCKED` on the profile handshake, ask the user which Chrome profile before retrying),
run scripted non-interactive checks via the `verifier` agent using the profile's
script-runner command, and use an interactive console in the brain only for genuinely
interactive poking. Compare the agent's
per-step verdicts with the author's Before/After; view a screenshot only on `UNCLEAR`. Record each step as: author's step → what I did →
what I saw → match / mismatch.

If the change has no steps, no flags, or no screenshots where it is visible, that is a
drafted request to the author (queue), and I still reproduce from the diff and say so.

Known blockers and their fallbacks (do not stop the phase on them; record which applied):
- **Dev server returns errors** (pending migrations, boot failure, a 500 on a touched
  page): Phase 3 step 3b was not completed — go back, fix what the review owes (migrations,
  dependencies) or record a blocking finding if the change is at fault, then retry. Calling
  the API layer directly from a script complements behaviour checks; it never
  replaces the HTTP path.
- **Browser automation refuses** (e.g. "browser is already running for … profile"): do not
  kill the user's browser. Use `curl` against the running server for the HTTP layer and the
  script runner for behaviour; record the message verbatim.
- **No browser login possible** (external identity provider only, local environment down):
  same script-runner fallback with the current user set to the owning account.
- **Seed data does not fit the API** (ids outside a type's range, mismatched keys): show
  the non-empty result at the model layer and the empty/`null` shapes through the API;
  state the seed limitation in the record, never in a comment.

### Phase 6 — Synthesize and walk the user through it

0. **Overlap check first.** Before ranking, take the Phase 1 understanding-confirmation
   draft and test it against every finding and question: if one already covers the same
   mechanism or ask, fold the confirmation's question into that thread's last line and mark
   the separate comment `dropped`. This happens here, never after posting.
1. Rank findings: blocking → non-blocking → nitpick, each in Conventional Comments
   format (`label (decoration): subject` then discussion), each with the file:line, the
   evidence, and the reproduction command. See `references/posting.md` § Format.
1b. Draft the **review summary note** (the single change-request-level comment). If the
   author posted a review request on it ("could you please review", an @-mention of the
   user), the
   summary is a **reply in that thread**, not a new note, and it opens by addressing the
   author by handle and thanking them for the work (specific, one sentence: what
   was good about it). Only when no such thread exists is it a new top-level note. Then, in
   this order, **short** (the diff threads carry the detail; the summary is four to six
   sentences, no headings, no per-thread bullets): what was checked in one sentence
   (specs **with their scope** — "the targeted specs for the changed files and their
   callers", never a bare count that reads as the full suite — lint, what was exercised
   locally); the verdict in one sentence (blocking or not, what decides approval); how many
   threads were left, by label, and which one gates approval; any point with no diff line
   (commit-message hygiene) in one clause; what happens next.
   No new findings appear only in the summary. Queue entry: `type: reply, target: author's
   review-request thread`.
   **Labels and the gate must agree.** The thread the summary names as gating approval
   carries `(blocking)` in its own first line; a thread labelled `(non-blocking)` is never
   named as gating. A `question (non-blocking)` whose answer might turn into a block keeps
   its label, and the summary says what answer would decide it ("whether it blocks depends
   on the staging numbers"). If the verdict in § 6 says a point decides approval, relabel
   the diff note `(blocking)` rather than softening the verdict.
   **The thread count is provisional** until Phase 7 re-derives it from what actually
   landed (see Phase 7).
2. Identify questions that need a **domain expert** rather than the author (ownership from
   the profile's ownership sources). Draft them addressed to that person.
3. Run `own-it` **on the review**, so the user can own it as if they had done every step
   themselves: the change's mechanism as the code names it, what each finding rests on and the
   command that reproduces it, what was observed versus inferred, what each review-bot verdict
   rests on, what remains unknown and who can answer it. Every drafted outbound item is
   shown here with its reasoning. The test: after this, the user could defend every
   comment in the queue to the author without me.
4. Present the **outbound queue** as a table: item, type (diffnote / reply / 👍 / label),
   target (file:line / author's request thread / review-bot thread), status. Anchor rule: a diff
   note goes on the line that *introduces* the behaviour in question (the method `def`, the
   field declaration, the hard-coded value), not on a line that merely mentions it. Then,
   **below the table, print every drafted body in full, inline, in a fenced block per
   item**, exactly as it would be posted, before any reasoning. The
   file under `artifacts/outbound/` is the posting source, never the only place the text
   lives: the user must be able to decide from the message alone without opening a file.
   Only after the bodies are on screen ask for a go per item, or a go on the batch with
   named exclusions. Use `own-it` § Asking format for anything with consequences.

### Phase 7 — Post only what was approved

Follow `references/posting.md`. Post each approved item **one at a time**: send, parse the
response, verify type/anchor/body, record the returned note or award ID in the queue, mark
it `posted`, and only then send the next. Stop on the first verification failure. Anything not approved stays `draft` or is marked
`dropped` with the user's reason.

**The summary is posted last and is re-derived first.** Before sending it, fetch the
discussions, list the user's own diff-note threads (id, anchor, first line), and rebuild
the summary's count sentence from that list by label. If the count or the labels differ
from the approved draft (a thread was dropped, deleted, or relabelled during posting), show
the corrected summary to the user again before posting; a stale count is a factual error
in the user's name. After posting, fetch once more and confirm: the summary is a reply in
the intended thread, its count equals the number of the user's diff threads on the change request, and
the thread it names as gating carries `(blocking)`. Report anything that does not match.

### Phase 8 — Restore the machine to the baseline

Follow `references/restore.md`. Order matters: roll back the change's migrations **before**
switching branches (the rollback needs the migration files), restore the database snapshot
(or confirm the schema version matches the baseline), return feature flags to their
captured state, stop any process this review started and leave running any that was
already running, remove scratch files this review created, then `git switch` back to the
baseline branch and re-apply the stash if one was taken with the user's go. Finish with the
verification block: for every baseline item, the before value, the after value, and
`restored` / `could not restore (reason)`. A restore that could not be verified is reported
as such, never as done.

**When:** only after the user says the review is done. After Phase 7 ask, in one line,
"Ready to restore (roll back N migrations, switch back to <branch>, pop the stash), or do
you want to keep the branch running to test or debug?" and wait. While waiting, the author's branch
stays checked out with its migrations applied and the dev server working. If the session
ends without a go, leave the machine on the author's branch and say so in the final message with
the exact restore commands.

**Order:** roll back every migration this review applied (the change's own and the base's,
from `artifacts/baseline/migrations_applied`) *before* switching branches, then restore the
database snapshot if data was written, then the rest of `references/restore.md`.

### Phase 9 — Close-out

1. Write to memory (`~/.claude/projects/<project>/memory/`) every non-obvious, recurring
   fact this review cost a probe to learn and that the repo does not record: local data
   quirks, tooling gotchas, where an external consumer of the API lives, auth paths. One
   file per fact, indexed in `MEMORY.md`. Skip anything derivable from the code or already
   in the profile; move stable environment facts into the profile instead.
2. If the user corrected the skill's behaviour during the review, encode the correction in
   the skill (rule or reference) in the same session and note it in the record.

## When the work is blocked

- Author's branch will not boot locally (missing seed, external sandbox down): record
  what failed verbatim, try the profile's fallback, and if still blocked, draft a question
  to the author asking how they ran it. Continue every phase that does not depend on it.
- A checklist item needs production data the user cannot access: mark `unverified`, name
  the exact query or plan that would settle it, and draft the ask.
- Uncertain which domain expert to ask: check the profile's ownership sources first; if
  still unclear, ask the user, not the change request.

## Anti-patterns — the review is not done if any of these are present

- A finding without a file:line and a way to reproduce it.
- "Specs pass" without the exact command and scope that was run.
- A Phase 4a section left empty ("no alternatives", "inputs: fine") without the evidence.
- A Phase 4b item skipped without a recorded verdict.
- A Phase 5 step described from the diff rather than executed, without saying so.
- A question posted, or a 👍 given, that the user did not see first.
- A verdict on a review-bot comment with no reasoning attached.
- An assumption about intent, load, or rollout that could have been a question.
- Any change-request-level note other than the single summary reply; a summary longer than six sentences
  or containing a per-thread list.
- A posted note whose response was not parsed and verified before the next post.
- A shorthand ("AC3", "the helper") used without the quoted, linked text it stands for.
- A local id, account name, or seed date in an outbound comment.
- An AskUserQuestion, or any go request, whose bodies were not printed in full above it.
- A separate understanding-confirmation thread when a finding thread already covers the
  same point.
- A comment body that reads as a paragraph rather than: point, quoted context, bullets, ask.
- A summary whose thread count or labels differ from the diff notes actually posted.
- A summary that gates approval on a thread whose own first line says `(non-blocking)`.
- "Ran the specs" in a summary without saying they were the targeted specs.
- A new thread on a point the review bot raised and the author resolved, without quoting and
  linking the bot's note and the author's reply in its context block.
- A PUT on an existing note whose `updated_at` was not re-checked immediately before the
  write with a guard that stops the write.
