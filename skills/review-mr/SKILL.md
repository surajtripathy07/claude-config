---
name: review-mr
description: Author-depth merge request review for gitlab-org/customers-gitlab-com and gitlab-org/gitlab. Grounds in the linked issue, triages GitLab Duo's comments, checks the branch out and runs the targeted specs, applies the canonical database / backend / frontend review checklists, reproduces the author's testing steps in Rails console and Chrome, and gates every outbound note, reply, emoji, label, or approval behind an own-it walkthrough and the user's explicit go. Use when asked to review an MR, when given an MR URL or IID with "review", or when the user has been tagged as reviewer, maintainer, or database reviewer.
model: sonnet
---

# review-mr — review an MR the way its author would have to defend it

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
   not approval of the next. This includes 👍 on Duo notes.
2. **Never approve or merge the MR.** Approval is the user's act, done by hand.
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
   ("we're done", "revert", "restore"); until then the MR branch stays checked out and
   runnable so the user can test or debug alongside. Always confirm before reverting.
7. **Targeted specs locally; the full suite is CI's job.** Run the specs that the change
   touches or that exercise the changed classes, then read the MR pipeline for the rest.
   Never claim "all specs pass" from a targeted run.
8. **Hedged answers are not decisions.** If the user answers a gating question with "I
   guess" / "sure?" / "whatever", stop, run `own-it` § Asking properly, ask again.
9. **Quote, link, then reason — never abbreviate.** Anything referenced from outside the
    text the reader is looking at (an issue's acceptance criterion, a line of code, a
    comment, a doc sentence) is copied verbatim as a `>` quote with a link to its exact
    position (issue URL with `#note_…` or heading anchor, file URL with `#L…`, MR note
    URL). **No abbreviations or invented labels of any kind** — not "AC3", not "F1"/"Q2",
    not "the finder", "the helper", "BAGI", "SM", "CH", "PG": write the thing out ("the
    issue's third acceptance criterion", "Self-Managed", "ClickHouse", "the flow-type
    filter thread"). Internal queue ids stay inside the record and are never used in a
    message to the user or the author. Applies to comments posted to the MR, to questions
    to the user, and to the review record's prose.
10. **Write for a reader who knows nothing about this corner.** Every outbound comment and
    every question to the user is written as if the reader has never seen this code, this
    issue, or this reviewer's earlier thinking. Lead with the one-sentence point, then walk
    the reasoning as short bullets (one step per bullet, with its evidence), then the ask.
    No wall of text: prefer four bullets to a paragraph, and one idea per bullet.
11. **Local state is described as a scenario, never as identifiers.** Subscription names,
    customer/user ids, wallet ids, dates and row counts from the reviewer's own database
    mean nothing to the author. In outbound comments, describe *what was set up* and *what
    happened* in words ("one subscription, three users, one of whom used more than their
    included allocation on a single day"), give the numbers only as the relationship that
    matters ("the wallet-based series showed 58, the event-based series 75"), and put the
    exact reproduction (ids, script) only in the review record. If a reader outside this
    machine could not act on a detail, it does not go in the comment.
12. **Comments must be indistinguishable from a review done by hand in the GitLab UI.**
    Objectively, that means: (a) exactly **one MR-level summary note** on the review page
    plus **one diff note per point** on the exact line in the MR's current diff version;
    nothing else at MR level; the summary is posted **after** the diff notes and is a reply
    in the author's review-request thread when one exists; (b) one thread per point, no
    duplicate or placeholder
    bodies, no literal file paths, variable names, or tool output in a body; (c) each body
    reads as one person's reasoning: Conventional Comments label, the quoted context with a
    link, three to six bullets, one ask; (d) nothing is posted until its body and anchor
    have been shown to the user and the response of the previous post has been verified
    (`type == "DiffNote"`, `position.new_line` as intended, body starts with the expected
    first line). A misplaced or malformed post is deleted or fixed immediately and reported.
    Posting mechanics that have been verified to work are in `references/posting.md`; do
    not improvise new ones during a review. The canonical shape of a summary and of a diff
    note is `references/exemplar.md` (taken from !17037); match it.
13. **Everything the user is asked to approve is shown inline, in full.** Drafted comments,
   replies, suggestion blocks, label changes, and the exact text of any question to a
   domain expert appear verbatim in the message that asks for the go. Never ask the user to
   open a file, a URL, or the record to see what they are approving.

## Inputs

- MR reference: IID, URL, or branch. If absent, ask for it before anything else.
- Repo: detected from `git remote get-url origin`. Load the matching profile:
  - `gitlab-org/customers-gitlab-com` → `profiles/customers-gitlab-com.md`
  - `gitlab-org/gitlab` → `profiles/gitlab.md`
  - Anything else: stop and tell the user this skill has no profile for it.
- The GitLab CLI is `glab`, aliased `gl` in the user's shell. In scripts use the full
  path `/opt/homebrew/opt/glab/bin/glab`. Raw API calls go through `glab api`.

## The review record

One file per MR, outside any repo so it can never be committed by accident:

```
~/.claude/reviews/<project>/<iid>/review.md      the record (sections below, in order)
~/.claude/reviews/<project>/<iid>/artifacts/     screenshots, plans, spec output, console logs
```

Every phase appends its section before the next phase starts, so a long session survives
context compaction. The record's sections, in order:

```
0 Setup          role, profile, changed-file categories, pipeline status, BASELINE
1 Understanding  the ask, how the MR claims to meet it, gaps, description-quality check
2 Duo triage     one row per Duo thread: verdict, reasoning, drafted reaction/reply
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

1. Detect repo, load profile, note the MR IID and URL. Create the record.
2. `glab mr view <iid>` for title, author, labels, reviewers, milestone, description.
3. Determine **the user's role on this MR** from the reviewers list, the labels
   (`~database`, `~"database::review pending"`), and Danger's roulette table (see
   `references/grounding.md` § 4 Determine the user's role). One of: reviewer, maintainer, database reviewer,
   database maintainer, not assigned. Confirm with the user if ambiguous. The role changes
   what is mandatory in Phase 4.
4. Pull the diff (`glab mr diff <iid>`) and the changed-file list. Bucket files by the
   profile's category map (database / backend / frontend / test / docs). Record which
   Phase 4 checklists apply.
5. Read the MR pipeline status (`glab ci status` on the checked-out branch, or
   `glab api projects/:id/merge_requests/<iid>/pipelines`). Record failing jobs by name.
6. **Capture the baseline** before touching anything. Follow `references/restore.md`
   § Baseline. At minimum: current branch and HEAD, `git status --porcelain`, stash list
   length, which app processes are running and on which ports, the database snapshot
   (or the migration version if the profile says snapshots are too large), and the current
   state of every feature flag the MR names. Write it to the record's Setup section and to
   `artifacts/baseline/`. If the working tree is dirty, stop and ask the user whether to
   stash; do not decide for them.

### Phase 1 — Ground in the problem

Follow `references/grounding.md`. Output: the **Understanding** section, which must answer:

- What is the ask, in the issue's words, with the issue's acceptance criteria if it has any.
- What does the MR claim to do, and by which mechanism (name the classes / flows).
- Where the claim and the ask diverge, or where the description does not say how the
  MR meets the ask.
- Description quality: what/why present, test steps present and concrete, feature flags
  listed, Before/After screenshots present for any UI change.

Then **always** draft an understanding-confirmation comment to the author: two to five
sentences stating what I believe the MR does and why, ending with "Is that right?" If the
understanding is complete and confident, say so to the user and let them decide whether
it still goes out; if anything is unclear, it must go out. Both go into the outbound queue.
**Before Phase 6, check it for overlap:** if a finding or question thread already covers
the same point (same mechanism, same ask), fold the confirmation's ask into that thread's
last line and drop the separate comment. Two threads the author would answer with one
reply is padding. Only an understanding gap no other thread touches gets its own comment.

### Phase 2 — Triage GitLab Duo's comments

Follow `references/duo-triage.md`. Duo (GitLab's built-in AI reviewer, username
`GitLabDuo`) leaves one summary note and one resolvable diff note per finding. For each
thread: open the code at the note's position, decide agree / disagree / needs author, write
the reasoning, and draft the reaction (👍 award) or reply. All drafts go into the queue.
Never resolve Duo threads; that is the author's or user's act.

### Phase 3 — Check out the branch and run what the change touches

Follow the profile's "Branch and specs" section. In order:

1. `glab mr checkout <iid>` only after the Phase 0 dirty-tree decision (stash with the
   user's go, or abort); never commit anything of the user's. Record whether the local
   branch existed before.
2. Dependencies: run `bundle check` (and `yarn check --verify-tree` if `yarn.lock` differs)
   **even if the MR did not touch a lockfile** — the MR's base is usually newer than the
   user's branch, so gems can be missing. Install if needed; installing is additive and is
   recorded in `artifacts/baseline/created_files`.
3. **Make the MR runnable locally.** Snapshot the dev database first (`pg_dump -Fc`, per
   the profile; seconds). Then run `bin/rails db:migrate` so that *both* the MR's own
   migrations *and* any migrations its base carries that the local DB lacks are applied;
   otherwise the running dev server answers every request with
   `ActiveRecord::PendingMigrationError`. Announce which migrations will run (from
   `bin/rails db:migrate:status | grep down`) in the message before running them; the user
   has authorised this step for review-mr, so do not block on a question. For the MR's own
   migrations also roll back and re-migrate, confirm the schema dump has no diff beyond the
   MR's own, and record timings (`references/database.md` § Local migration checks). Record
   every applied version in `artifacts/baseline/migrations_applied` for Phase 8.
3b. **Prove the local dev environment works on the MR branch before going further.** Phase 3
   ends with a health check against the user's running stack (per profile: `GET` the app
   root and the pages the MR touches, one API call the MR changes, a console boot). Expected
   result: the app serves normally with the MR's code. If something the review set up is
   missing (gems, migrations, assets, a restart the profile allows), fix it and re-check.
   If the app is still broken and the cause is in the MR (a migration that fails, a boot
   error, a broken route, a schema that no longer compiles), that is a **blocking finding**
   with the verbatim error, not an environment note — record it in § 3 and § 6 and carry on
   with the phases that do not depend on it. Never proceed to Phase 5 with a dev server
   that returns errors without having classified the cause as "ours" or "the MR's".
4. Targeted specs: changed spec files, plus the spec that mirrors each changed
   `app/`/`lib/` file, plus specs found by grepping `spec/` for the changed class names.
   Frontend: Jest for changed `spec/frontend` files and for the spec mirroring each changed
   component. Record the exact command and verbatim failures.
5. Lint the changed files only (RuboCop, ESLint/Prettier per profile).
6. Compare with CI: which jobs the MR pipeline ran and their state. A local pass plus a
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
- Backend → `references/backend.md`, then the profile's skill routing (customers-dot
  routes Ruby to its `rails` and `rspec` skills; gitlab.com uses its own docs).
- Frontend → `references/frontend.md`.
- Tests, docs, and anything else → the general acceptance checklist in
  `references/backend.md` § Acceptance checklist.

The `database` subagent (query evaluation and plan verification) may be used to read a
plan; its output is evidence, not a verdict, and the item is still recorded here.

### Phase 5 — Reproduce the author's testing

Precondition: Phase 3 step 3b passed (the dev environment serves the MR's code). Follow
`references/testing.md`. Take the MR's "How to set up and validate locally" steps
(or equivalent) and execute them as literally as possible: enable the listed flags the
profile's way, start the app, hand the UI steps to the `browser` agent (`orchestrate`
skill: scripted STEPS with EXPECT per step, a `PROFILE` clause, screenshots saved into
`artifacts/`; one browser agent at a time, continued via `SendMessage`; if it returns
`BLOCKED` on the profile handshake, ask the user which Chrome profile before retrying),
run scripted console checks via the `verifier` agent with `bin/rails runner`, and use
`bin/rails c` in the brain only for genuinely interactive poking. Compare the agent's
per-step verdicts with the author's Before/After; view a screenshot only on `UNCLEAR`. Record each step as: author's step → what I did →
what I saw → match / mismatch.

If the MR has no steps, no flags, or no screenshots where the change is visible, that is a
drafted request to the author (queue), and I still reproduce from the diff and say so.

Known blockers and their fallbacks (do not stop the phase on them; record which applied):
- **Dev server returns errors** (`PendingMigrationError`, boot failure, 500 on a touched
  page): Phase 3 step 3b was not completed — go back, fix what the review owes (migrations,
  gems) or record a blocking finding if the MR is at fault, then retry. The runner path
  (`<Schema>.execute(query, context: {...})`) complements behaviour checks; it never
  replaces the HTTP path.
- **Chrome MCP refuses** ("browser is already running for … chrome-profile"): do not kill
  the user's browser. Use `curl` against the running server for the HTTP layer and the
  runner for behaviour; record the message verbatim.
- **No browser login possible** (OAuth-only customers, GDK down): same runner fallback with
  `current_user` set to the owning customer.
- **Seed data does not fit the API** (ids outside GraphQL `Int`, mismatched subjects): show
  the non-empty result at the model layer and the empty/`null` shapes through the schema;
  state the seed limitation in the record, never in a comment.

### Phase 6 — Synthesize and walk the user through it

0. **Overlap check first.** Before ranking, take the Phase 1 understanding-confirmation
   draft and test it against every finding and question: if one already covers the same
   mechanism or ask, fold the confirmation's question into that thread's last line and mark
   the separate comment `dropped`. This happens here, never after posting.
1. Rank findings: blocking → non-blocking → nitpick, each in Conventional Comments
   format (`label (decoration): subject` then discussion), each with the file:line, the
   evidence, and the reproduction command. See `references/posting.md` § Format.
1b. Draft the **review summary note** (the single MR-level comment). If the author posted a
   review request on the MR ("could you please review", an @-mention of the user), the
   summary is a **reply in that thread**, not a new note, and it opens by addressing the
   author by handle and thanking them for the work on the MR (specific, one sentence: what
   was good about it). Only when no such thread exists is it a new MR-level note. Then, in
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
   themselves: the MR's mechanism as the code names it, what each finding rests on and the
   command that reproduces it, what was observed versus inferred, what each Duo verdict
   rests on, what remains unknown and who can answer it. Every drafted outbound item is
   shown here with its reasoning. The test: after this, the user could defend every
   comment in the queue to the author without me.
4. Present the **outbound queue** as a table: item, type (diffnote / reply / 👍 / label),
   target (file:line / author's request thread / Duo thread), status. Anchor rule: a diff
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

**The summary is posted last and is re-derived first.** Before sending it, fetch the MR's
discussions, list the user's own `DiffNote` threads (id, anchor, first line), and rebuild
the summary's count sentence from that list by label. If the count or the labels differ
from the approved draft (a thread was dropped, deleted, or relabelled during posting), show
the corrected summary to the user again before posting; a stale count is a factual error
in the user's name. After posting, fetch once more and confirm: the summary is a reply in
the intended thread, its count equals the number of the user's diff threads on the MR, and
the thread it names as gating carries `(blocking)`. Report anything that does not match.

### Phase 8 — Restore the machine to the baseline

Follow `references/restore.md`. Order matters: roll back the MR's migrations **before**
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
you want to keep the MR running to test or debug?" and wait. While waiting, the MR branch
stays checked out with its migrations applied and the dev server working. If the session
ends without a go, leave the machine on the MR branch and say so in the final message with
the exact restore commands.

**Order:** roll back every migration this review applied (the MR's own and the base's,
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
  still unclear, ask the user, not the MR.

## Anti-patterns — the review is not done if any of these are present

- A finding without a file:line and a way to reproduce it.
- "Specs pass" without the exact command and scope that was run.
- A Phase 4a section left empty ("no alternatives", "inputs: fine") without the evidence.
- A Phase 4b item skipped without a recorded verdict.
- A Phase 5 step described from the diff rather than executed, without saying so.
- A question posted, or a 👍 given, that the user did not see first.
- A verdict on a Duo comment with no reasoning attached.
- An assumption about intent, load, or rollout that could have been a question.
- Any MR-level note other than the single summary reply; a summary longer than six sentences
  or containing a per-thread list.
- A posted note whose response was not parsed and verified before the next post.
- A shorthand ("AC3", "the helper") used without the quoted, linked text it stands for.
- A local id, subscription name, or seed date in an outbound comment.
- An AskUserQuestion, or any go request, whose bodies were not printed in full above it.
- A separate understanding-confirmation thread when a finding thread already covers the
  same point.
- A comment body that reads as a paragraph rather than: point, quoted context, bullets, ask.
- A summary whose thread count or labels differ from the diff notes actually on the MR.
- A summary that gates approval on a thread whose own first line says `(non-blocking)`.
- "Ran the specs" in a summary without saying they were the targeted specs.
- A new thread on a point Duo raised and the author resolved, without quoting and linking
  the Duo note and the author's reply in its context block.
- A PUT on an existing note whose `updated_at` was not re-checked immediately before the
  write with a guard that stops the write.
