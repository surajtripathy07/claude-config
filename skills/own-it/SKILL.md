---
name: own-it
description: Walk the user through a change or a decision at the depth its author would hold — mechanism, reasoning, alternatives, verification, rebuild path — so they could reproduce it or explain it themselves. Use when the user asks ("explain", "walk me through", "what did you just do", "I don't follow", "catch me up", "eli5"), after any non-trivial change lands, before writing a commit, and whenever a question is put to the user that they need context to answer rather than guess.
---

# own-it — transfer ownership of a change, not just a summary

Purpose: after this runs, the user should be able to do three things without me: make the
same change themselves from scratch, explain it to a colleague as if they wrote it, and
defend why it was done this way and not another. A summary of *what happened* fails all
three. What passes is the reasoning an author holds in their head and normally never writes
down.

The reader is a strong engineer who has not been looking at this corner of the system.
Not a beginner. A stranger to *this* code, *this* tool, *this* failure. Calibrate to that.

## When to run

- The user invokes `/own-it` (optionally with a topic: `/own-it the workflow change`).
- A non-trivial change has just landed: more than one file, or one file where the *why*
  is not obvious from the diff, or anything touching config, build, deploy, auth, data.
- Before writing a commit message for such a change (the `git-commit` skill calls this).
- Before asking the user any question whose answer has downstream consequences (§ Asking).
- The user answers a question with a hedge ("I guess", "sure?", "whatever you think",
  "probably the first one"). That is a guess, not a decision. Stop and run § Asking
  properly instead of taking the guess.

## Depth rules — these are what make it work

- **Mechanism before action.** Never "I updated X". Always "the system does A, which
  causes B; X is where A is decided, so changing X changes B". If I cannot state the
  mechanism, I do not understand the change well enough to have made it, and I say so.
- **Gloss every named thing on first use.** Tool, term, acronym, file with a special role.
  One clause, inline: "Dart Sass (the compiler that turns `.scss` into `.css`)". Never
  "as you know", never "obviously", never an unexplained acronym.
- **Concrete over abstract.** Show the actual line, the actual command output, the actual
  path. "The template loop" is abstract; `layouts/partials/home/extensions.html:14` is not.
- **Every claim carries its verification.** "I did X" is incomplete without "and you can
  see it by running Y". If there is no Y, the claim is unverified and gets labelled so.
- **Assumptions are surfaced, not buried.** Anything I decided without asking gets listed
  under its own heading, with what I assumed and what changes if the assumption is wrong.
- **Length follows understanding, not brevity.** This skill deliberately trades length for
  comprehension. The layering below lets the reader stop early; it does not let me.
- **Name the pattern.** When the change is an instance of something recurring (override
  resolution, a cache invalidation, an env-var precedence rule), name it and say where
  else it applies. This is how the reader builds their own model over time.

## The walkthrough — every section is filled, in this order

### 0. Thirty-second version
Three or four sentences. Problem, cause, fix, how to check. A reader who stops here has
the shape; everything below is the depth.

### 1. The problem, then the mechanism
- What was wrong or wanted, in one plain sentence.
- How the relevant part of the system actually works: the pieces involved, what each one
  is (glossed), how they connect, and where in that chain the problem lives. This is the
  section that makes the fix *obvious in hindsight*. Write it so that after reading it,
  the reader could have guessed the fix themselves.

### 2. The reasoning
- **Alternatives considered**: each one, and the specific reason it lost. "Not considered"
  is an acceptable answer only if stated; an empty list is a smell.
- **Assumptions made without asking**: each one, what it rests on, what changes if wrong.
- **What was deliberately left out** and where it lives instead.

### 3. Each edit, with its why
For every file touched, in causal order:
- Path and the specific lines or block.
- What changed, quoted or shown as before/after.
- Why *this* change and not the neighbouring one that would also compile.
- What breaks if this edit is left out — this is the test that the edit is necessary.

### 4. Verify it yourself
Exact commands, URLs, or files to open, one per claim in §3, with what the reader should
expect to see. Include the negative check where cheap: how to make it fail again, so the
reader sees the fix is doing the work.

### 5. Rebuild path
If the reader were making this change tomorrow from a clean checkout with no memory of
this session: what they would look at first, second, third; which command or search
reveals the cause; which file they would open and why. Ordered. This section is the
"could I do it myself" test made explicit.

### 6. The pattern
Name the recurring idea, one or two sentences, and where else in this codebase or tool it
shows up. Skip only if the change is genuinely one-off, and say so.

### 7. What I am not sure about
Anything unverified, any behaviour I inferred rather than observed, any edge I did not
test. Empty is allowed only if true.

### 8. Open door
End with one line: *"Name any section to go deeper, or explain it back to me if you want
your understanding checked."* Nothing more. The reader decides whether they are confident;
they do not have to prove it. If they do explain back, correct precisely: right, missed,
backwards. Short — calibration, not a second lecture. Missed pieces often mean §1 was
too thin; say so.

## Show, don't describe — ASCII diagrams, inline, terminal only

A picture buys depth per minute only where the content is spatial or sequential. Three
places in the walkthrough are:

- **§1 mechanism**: boxes for the pieces, arrows for what flows, the changed piece marked.
- **§3 before/after**: the same diagram twice, or one diagram with the old path struck
  and the new path marked.
- **§5 rebuild path**: an ordered flow or a small decision tree.

Draw when the change involves **three or more interacting parts** or **crosses a boundary**
(build→deploy, config→runtime, client→server, request→queue→worker). Below that, prose is
faster. Never draw for the reasoning, assumptions, verification, or uncertainty sections.

Rules for the drawing:

- Plain ASCII in a fenced code block. Boxes, `-->`, `|`, labels. No mermaid, no SVG.
- Everything stays in this conversation. Never publish an artifact, open a browser, or
  write a file for the reader to go look at — leaving the terminal is a cost this skill
  does not spend.
- Mark the changed element visibly: `[*]`, `<-- changed`, or a `NEW`/`OLD` label.
- Keep it under about twelve lines wide and eight tall; if it does not fit, the diagram is
  showing too much — cut to the path the change touches.

Example shape (mechanism with the changed piece marked):

```
push to main --> GitHub Actions runner --> setup Hugo [0.163.3]  <-- changed
                                              |
                                              v
                                     hugo --minify --> public/ --> Pages deploy
```

## Asking — a question must carry what is needed to answer it

Whenever a question is put to the user, whether via AskUserQuestion or in prose, it carries:

- **The question**, one sentence, concrete.
- **Why it has come up now**: what triggered it, what work is waiting on it.
- **The mechanism that makes it a real choice**: the background a stranger to this corner
  needs, glossed, in a few sentences. If I cannot explain why the options differ in effect,
  I should not be asking; I should go find out first.
- **Each option**: what it means concretely, what changes downstream, how reversible it is
  and what reversal costs.
- **My recommendation and the one-line reason.** "No recommendation" needs a stated reason.
- **What happens by default** if they do not decide.
- **A decision heuristic**: "pick A if you care more about X, B if Y" — so the reader can
  choose from their own priorities rather than from my framing.

If the reader's answer is a hedge, do not proceed on it. Say which part of the above was
missing for them, fill it, and ask again.

## Anti-patterns — if the output has any of these, it is not done

- A diff summary with no mechanism ("updated the config, bumped the version").
- A named tool or acronym with no gloss on first use.
- "Changed X" with no way for the reader to observe the effect.
- An alternatives section that is empty without saying why.
- Assumptions that only become visible when they turn out wrong.
- Shortening to be polite. The reader asked for depth; give it, layered.

## Guardrails

- Read-only. This skill explains and asks; it does not make further changes. If the
  walkthrough reveals a mistake, name it under §7 and let the user decide.
- Never invent a mechanism to fill a section. If I do not know how something works, that
  is the finding, and it goes in §7 with how I would find out.
