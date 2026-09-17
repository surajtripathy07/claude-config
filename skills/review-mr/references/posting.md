# Phases 6–7 — Format, queue, and post outbound items

## Format: Conventional Comments

Every comment this skill drafts uses
[Conventional Comments](https://conventionalcomments.org) — a comment-style convention, not
a feature of any host. If the project's own guidelines or its review bot's instructions
prescribe a variation, the profile records it and that wins:

```
<label> [(decoration, decoration)]: <subject, one line>

<discussion: mechanism, evidence, what would resolve it>
```

Labels: `praise`, `suggestion`, `issue`, `question`, `thought`, `nitpick`, `todo`,
`chore`, `note`. Decorations: `blocking`, `non-blocking`, `if-minor`, `security`,
`performance`, `ux`, `test`.

Rules for this skill's drafts:

- **Shape of every comment** (the reader is assumed to know nothing about this corner):
  1. The Conventional Comments line: one sentence, the point.
  2. **Context, quoted and linked.** Whatever the comment leans on is copied verbatim as a
     `>` block with a link to its exact position, e.g.
     `The [issue](<link to the issue>) description says:` followed by
     `> Reconciles with the existing account-level monthly total when only one customer has orders.`
     For code: `` [`app/models/x.rb:20`](<link to that file and line at the head commit>) ``
     with the line quoted. Never a bare "AC3", "the finder", "the helper".
  3. **Reasoning as bullets**, one step per bullet, each carrying its evidence (a number,
     a quoted line, a command and its output). A reader should be able to follow the
     bullets top to bottom without opening anything else.
  4. **The ask**, one sentence: what would resolve the thread.
  Keep it short by cutting words, not steps. Prefer four bullets to one paragraph.
- **Gloss on first use** every class, table, field, or term the author may not have in
  mind (what it is, in a clause), even if the author wrote it.
- **Local reproductions are scenarios, not dumps.** Never paste local account or
  customer names, record ids, or seed dates into a comment; nobody else can resolve
  them. Say what the setup was in plain words and what the two sides showed, keeping only
  the numbers whose relationship carries the point (e.g. "the per-customer series totalled
  58 for the month, the ledger-based series 75, because two of the three customers had
  orders outside the filtered categories"). Ids and scripts live in the record's artifacts
  so the *user* can rerun them; the author gets a scenario they could reproduce anywhere.

- **Every `issue` and `suggestion` carries evidence**: the file:line, what I ran, what I
  saw. A finding the author cannot reproduce from the comment is not finished.
- **`question` is for things I could not verify**, and says what I tried. "Did you consider
  X?" without context is not a question, it is an assumption in disguise.
- **The label is bold.** The Conventional Comments line is written `**issue (non-blocking):** subject` so it stands out in the host's web UI; same in the summary's thread list.
- **Blocking is explicit.** Mark `(blocking)` or `(non-blocking)` on every `issue` and
  `suggestion`. Unmarked feedback delays the change: the author cannot tell what must be
  fixed before merge.
- **Assume the author considered alternatives.** Phrase as "What do you think about X
  here, given Y?" not "You should X."
- **Suggestion blocks** (```` ```suggestion ````, where the host supports applying them)
  only when the replacement is exact and compiles; otherwise describe.
- Inclusive language; spell project and product names out rather than using in-house
  abbreviations the profile does not list.
- Never mention Claude, AI, or that the review was assisted. The user is the reviewer.

## Where a comment lands

A finished review has exactly two kinds of outbound comment, mirroring a review done by
hand in the host's web UI:

1. **Diff notes** — every finding, suggestion, or question that concerns a line is posted
   on that line that *introduces* the behaviour (method `def`, field declaration, hard-coded
   value). An understanding-confirmation comment, if it survived the overlap check in
   Phase 1, anchors to the line that defines the thing being confirmed (e.g. the new field).
2. **One summary note** on the change request's page, posted last, as a **reply to the
   author's review request thread** when one exists (find it in the discussions: the
   author's note that @-mentions the user asking for review; on the GitLab profile, reply
   with `$P/discussions/<id>/notes`). It opens
   with "@author thanks for …" naming one concrete thing done well, then in four to six
   sentences: what was checked (specs named as *targeted*, with what they covered; lint;
   what was exercised locally), the verdict, how many threads by label and which one gates
   approval, anything with no diff line (commit-message hygiene), the next step. No
   headings, no per-thread list: the diff threads already carry the detail. No other
   MR-level notes. The gating thread's own label must be `(blocking)`; never name a
   `(non-blocking)` thread as the gate. Worked example: `exemplar.md`.

Order of posting: diff notes first (verify each), summary last (so it can list them).
**Recount before the summary goes out**: fetch the discussions, list the user's DiffNotes,
rebuild the count sentence from that list; if it changed, show the user again first.

**After a hand-edit by the user**, re-fetch the note and lint it before anything else is
posted: labels still `**label (decoration):**`, count still equal to the threads on the MR,
gate still on a `(blocking)` thread. A slip found here is reported, never silently fixed.

## The outbound queue

In the record, section 7. One row per item:

| id | type | target | text | status |
|---|---|---|---|---|
| Q1 | note | author | ... | draft |
| D1 | reaction | note <note_id> | thumbsup | draft |
| D2 | reply | thread <thread_id> | ... | draft |
| F1 | diffnote | app/x.rb:112 | ... | draft |
| E1 | note | @domain-expert-handle | ... | draft |

Statuses: `draft` → `shown` (walked through with own-it) → `approved` / `dropped` →
`posted <id>`. Only `approved` items are posted. Anything else never leaves the queue.

## Presenting the queue (Phase 6 step 4)

Show the table, then **for each item the full body verbatim in a fenced block** (the
exact text that will be posted, suggestion blocks included), then — separately and after
all bodies — the reasoning in own-it depth (mechanism, evidence, what changes if wrong),
kept to a few lines per item; the bodies are the deliverable, the reasoning is support. The user decides from the
message alone; `artifacts/outbound/<id>.md` is the posting source, not the reading copy.
Ask for a go per item, or per batch with named exclusions, using own-it § Asking: why now,
what each option means, the default, a decision heuristic. An AskUserQuestion whose
options refer to bodies the user has not yet seen inline is a skill violation.

A hedged answer ("sure", "I guess", "post whatever") is not a go. Stop, say which context
was missing, fill it, ask again.

## Posting (Phase 7)

The mechanics below are **the GitLab profile's** (via `glab`), kept because they are
verified to work. The *sequence* is host-agnostic and never changes: pre-flight the change
request's state and head, post one item, parse and verify the response, record the returned
id, then post the next; summary last. A GitHub profile documents its own `gh` equivalents
for each call below — do not improvise them here.

**Pre-flight, immediately before the first post:** fetch the change request and
assert it is still open, that its head commit equals the one the drafts were anchored to, and re-read the
discussions for any review posted since Phase 0 (another reviewer, a maintainer, an approval). If it
is merged or closed, **stop and tell the user**; blocking labels on a merged change are meaningless and
the comments may belong on a follow-up instead. If another reviewer's thread covers a queued point,
that item goes back to `draft` and is re-shown with the earlier thread quoted and linked. This guard
exists because a review once posted a same-line duplicate after a reviewer approved and a maintainer
merged: only the head commit had been re-checked, not the state or the discussions.

```sh
$GL api "$P" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["state"]=="opened", d["state"]; print(d["sha"])'
```

```sh
GL=/opt/homebrew/opt/glab/bin/glab
P="projects/<namespace>%2F<project>/merge_requests/<iid>"

# glab gotchas (verified in practice):
#  - `-f body=@file` is NOT expanded; it posts the literal "@/path". Read the file in the shell.
#  - `-f 'position[new_line]=62'` is sent as a flat key and silently ignored: the note posts as a
#    plain DiscussionNote with no position. Nested params need a JSON body via `--input`.
#  - In zsh never name a shell variable `path` (it is bound to $PATH); use `fpath`/`new_path`.
#  - Quote `position[...]`-style strings anyway or zsh treats the brackets as a glob.

# plain note on the MR (only when the user explicitly wants a summary outside the diff)
$GL api "$P/notes" -f "body=$(cat /path/to/text.md)"

# reply in an existing discussion (review-bot thread, roulette thread, ...)
$GL api "$P/discussions/<discussion_id>/notes" -f "body=$(cat /path/to/text.md)"

# 👍 on a note (agreeing with the review bot)
$GL api "$P/notes/<note_id>/award_emoji" -f name=thumbsup

# fix a note's body in place (keeps the note id)
$GL api -X PUT "$P/notes/<note_id>" -f "body=$(cat /path/to/text.md)"

# new diff note anchored to a line — the default for every finding and question that has a line.
# Needs the MR's diff refs and a nested JSON body:
$GL api "$P" | python3 -c 'import sys,json; r=json.load(sys.stdin)["diff_refs"]; print(r["base_sha"], r["start_sha"], r["head_sha"])'
python3 - text.md app/x.rb 112 <base> <start> <head> > /tmp/body.json <<'PY'
import sys,json
body,fpath,fline,base,start,head=sys.argv[1:]
print(json.dumps({"body":open(body).read(),"position":{"position_type":"text","base_sha":base,
  "start_sha":start,"head_sha":head,"new_path":fpath,"old_path":fpath,"new_line":int(fline)}}))
PY
$GL api -X POST "$P/discussions" --input /tmp/body.json -H 'Content-Type: application/json'

# After EVERY post, before the next one: parse the response, assert `notes[0].type == "DiffNote"`
# and `position.new_path`/`new_line` are the intended ones, and that `body` starts with the
# expected first line. Anything else did not land as intended: fix in place (PUT) or delete
# your own misplaced note and repost, and tell the user.

# labels (only if the user asked; e.g. after a database review as maintainer).
# The label names come from the profile, not from memory.
$GL mr update <iid> --label "<approved-label>" --unlabel "<review-pending-label>"
```

Write each body to a file under `artifacts/outbound/<id>.md` first and post from the
file, so the exact posted text is preserved.

**Editing an already-posted note (PUT) is a two-step with a hard stop in between.**
1. Fetch the note, save its body to `artifacts/outbound/<id>-server.md` and record its
   `updated_at`. Draft the new body from *that* file, never from the copy posted earlier.
2. Immediately before the PUT, fetch again and compare `updated_at` to the recorded value.
   **If it moved, do not write.** Print the current server body to the user, say when it
   changed, and ask whether to re-apply the draft on top of it. The user may have
   hand-edited the note between the two reads; a PUT would erase that edit, and hosts
   generally keep no note history to recover it from (this has happened in practice).
The guard must be one that cannot fall through: chain with `&&` or run under `set -e`; a
Python `assert` inside a pipeline followed by the PUT on the next line does **not** stop
the PUT.

```sh
set -e
GL=/opt/homebrew/opt/glab/bin/glab; P="projects/<namespace>%2F<project>/merge_requests/<iid>"
SEEN="<updated_at recorded when the draft was made>"
NOW=$($GL api "$P/notes/<note_id>" | python3 -c 'import sys,json; print(json.load(sys.stdin)["updated_at"])')
[ "$NOW" = "$SEEN" ] || { echo "note changed on server at $NOW — stop, show the user"; exit 1; }
$GL api -X PUT "$P/notes/<note_id>" -f "body=$(cat artifacts/outbound/<id>-v2.md)"
```

Never overwrite a user edit; if a factual mismatch remains after seeing it, tell the user. After posting, write the returned `id` into
the queue row. Then fetch the discussions once more and confirm each item is present at
the intended target. Report anything that did not land.

Never approve, never merge, and never resolve a discussion — whatever the host's command
for those is (`glab mr approve` / `glab mr merge` on the GitLab profile).

**Head guard.** Re-read the change request's diff refs immediately before every post and stop if the head commit differs from the one the review was done against. When it fires, classify the move before doing anything else: `git fetch` the branch, `git log --oneline <old>..FETCH_HEAD ^origin/<default-branch>` (new commits?) and `git diff --stat <old> FETCH_HEAD -- <the changed files>` (content change?). A pure rebase (same commits, the change's files unchanged, anchor line still reads the same) → reset the worktree to the new head, repoint file links in the body to the new commit, update the guard, post. Any content change → back to Phase 4 for the changed hunks; drafts that quote moved lines are stale.
