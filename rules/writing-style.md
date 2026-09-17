# Writing style — all outward-facing writing

MR descriptions, issue bodies, commit bodies, review comments, Slack posts, docs.

**Write for a strong engineer who hasn't been looking at this corner of the system.** A
stranger to this code, this tool, this failure — not a beginner. Never write down to them;
never assume they were in the room.

**Say what the system does, not what you did.** Not "I updated the resolver" but "the
filter is set on the parent and passed down, so the field that reads only its own argument
misses it". If you can't say the mechanism plainly, you don't understand the change well
enough to describe it — say that rather than papering over it.

**Plain words, carried by links.** Write in the words you'd use out loud, and let links
hold the identifiers: "[the parent type](…/users_usage_type.rb#L52) passes the filter down
to each user" instead of naming the class and then explaining it. Link every file, line,
issue, comment, or MR you're leaning on, anchored to a specific commit, so the reader can
open it. Nothing needs defining if the prose says what a thing does and the link says
which thing it is.

**Short.** Lead with the point in one sentence, end with the ask in one sentence.
Reasoning in between as bullets, one step each, each carrying its evidence — a quoted
line, a number, a link. Cut words, not steps. If it reads like a wall, it needs fewer
sentences, not smaller ones.

**Quote what you're relying on, describe what's ours.** Anything the reader can also see
gets quoted verbatim in a `>` block and linked. Anything local gets generalized: no
subscription names, customer or user ids, wallet ids, seed dates, local paths, tool output.
"We tested this on our system — one subscription, three users on a single day, two of them
past their included allocation" — keeping only the numbers whose relationship makes the
point: "58 on the wallet series, 75 on the event series".

**Verification only where it's load-bearing.** Most readers have neither the data nor the
setup, so a repro is worth including only when the claim turns on it and they could
actually run it. Otherwise say what you saw and in what scenario, and label what you
couldn't verify.

**Say what you assumed and what you're unsure of** — each assumption with what changes if
it's wrong. A question with no context behind it is an assumption in disguise.

**Assume the other person already thought about it.** "What do you think about X here,
given Y?" not "You should X."

**Markdown for anything others read:** `>` for quotes, `-` for steps, backticks for paths
and fields, real links over bare URLs, bold for the one thing that must not be missed. No
headings in a short comment.

**Never** mention Claude, AI, or how the writing was produced. You're the author.

**Review comments** also follow Conventional Comments, per both GitLab repos' guidelines:
`**<label> (<decoration>):** <one-line subject>`. Labels `praise`, `suggestion`, `issue`,
`question`, `thought`, `nitpick`, `todo`, `chore`, `note`; decorations `blocking`,
`non-blocking`, `if-minor`, `security`, `performance`, `ux`, `test`. Mark every `issue` and
`suggestion` `(blocking)` or `(non-blocking)` — unmarked feedback delays the MR.
` ```suggestion ` blocks only when the replacement is exact and compiles. "CustomersDot",
not "CDOT".

## The voice, by example

The rules above describe the shape; they can't describe the voice. Match
`~/.claude/skills/review-mr/references/exemplar.md` — three bodies from
customers-gitlab-com !17037 that the user signed off as "exactly how a review should look".
When a draft doesn't read like those, the draft is wrong.
