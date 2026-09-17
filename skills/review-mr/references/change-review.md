# Phase 4a — Review the change against the problem it solves

This is the part of the review that no checklist covers: does this diff solve the ask from
Phase 1, is it the right place and shape for the fix, and is the logic correct on the inputs
production will actually send it. The standard is the author's own: for every hunk, be able
to say why it is there, what breaks without it, and what would go wrong if it is subtly
wrong. Every conclusion below is written into the record's section 4 before the checklists
start.

## 1. Root cause or symptom?

Take the Understanding section's "ask" and "mechanism" and answer, with file:line evidence:

- Where does the bug or gap actually originate in the code path (the earliest point where
  state or control flow goes wrong)? Trace it: entry point → the branch that misbehaves.
- Does the diff change *that* point, or a point downstream that masks it? A downstream
  patch is not automatically wrong (it may be the safe minimal fix), but it must be named
  as such, and the question "why not at the source?" goes to the author unless the MR
  already answers it.
- Are there other callers of the same faulty path that the fix does not reach? Grep for
  the class, method, scope or API field, and use whatever history/callers tooling the
  profile names (an MCP query template, a code-search service) for blast radius. List them; each one either is covered, is out of scope by the
  author's stated reasoning, or is a finding.

## 2. Does the mechanism hold?

For each hunk, in causal order, write one line each:

| hunk | what it changes | why it is needed for the ask | what breaks if it is left out |
|---|---|---|---|

A hunk with no entry in the third column is scope creep or a refactor riding along; name
it. A hunk whose fourth column is "nothing observable" is either dead or needs a test that
proves it matters. Then check the joints between hunks: a new value produced in one place
and consumed in another (a normalized symbol, a new enum member, a new flag), is every
consumer updated, and does every producer emit the new shape?

## 3. Inputs the code will actually see

Enumerate the input space the changed code faces and walk each through the new logic by
hand or in the console (Phase 5 reproduces the happy path; this is the rest):

- **Existing data.** Rows that predate the change: nil columns, legacy values, records in
  states the new validation would reject. The acceptance checklist's "existing data may be
  surprisingly varied" item (see `backend.md`) is this check. Query the dev database or ask for a count from
  the replica.
- **Boundaries.** Empty collections, zero quantities, the first and last element, maximum
  sizes, unicode and whitespace in strings, time zones and month ends for dates, the
  moment a flag flips mid-request.
- **Every branch of the new conditionals**, including the `else` that was already there:
  is the old behaviour preserved for the inputs that used to take it?
- **Both flag states.** With the flag off, is the diff a no-op for every caller? With it on,
  does anything outside the intended audience change (whatever segments this product has —
  deployment types, sales channels, plan tiers, trial versus paid)?
- **Concurrency and retries.** Two requests at once, a background-job retry, a webhook replay:
  does the change create a duplicate, a lost update, or a half-applied state?
- **Failure paths.** A call to any external system the change depends on fails (a billing
  provider, a CRM, another service's API): what does the user see, what is logged, is the
  error swallowed?

Each input either produces the expected result (say how you know), produces a wrong result
(finding, with the reproduction), or could not be determined (question).

## 4. Consequences outside the diff

- **Callers and dependents** of changed public methods, scopes, serializers, GraphQL
  fields: found by grep and whatever history/callers tooling the profile names, each
  checked for the new contract.
- **Persisted or cached shapes.** A changed enum, JSON column, cache key, or Sidekiq
  argument: old values in the database or queue must still be readable by the new code, and
  new values by the old code during deploy.
- **API and UI contracts.** Anything a client reads (this project's own frontend, another
  service, a script): is the change additive, or does it rename or remove?
- **Security boundary.** Does the change widen who can do or see something? Follow the
  authorization from the entry point to the data.
- **Operational.** New log lines or metrics needed to know the change works in
  production; a rollout and a rollback plan for a flagged change.

## 5. Do the tests prove the claim?

For each behaviour the change claims, name the spec example that fails without it. Run
the changed specs against the base branch's application code when cheap (stash the app
hunk, run the spec, expect red) for the one or two central claims. Tests that pass with and
without the change are a finding. Also note what the tests assume: stubbed collaborators
that hide a real integration, factories that never produce the legacy data from § 3.

## 6. Alternatives

State the one or two other ways this could have been done and why the author's choice is
better or worse for this ask. If you cannot name an alternative, you have not understood
the design space yet; go back to § 1. If the description already discusses alternatives,
check the reasoning rather than repeating it.

## Output

Section 4a of the record:

```
### 4a Change review
**Root cause vs fix location:** ...
**Hunk table:** ...
**Inputs walked:** table of input → expected → observed / reasoned → verdict
**Outside the diff:** callers, persisted shapes, contracts, authz, ops
**Tests prove:** claim → spec example → red without change? (yes / no / not checked)
**Alternatives:** ...
**Findings from this section:** F1, F2 ... (each with file:line and reproduction)
**Questions from this section:** Q1, Q2 ... (each with what was tried before asking)
```

Only then move to 4b, the domain checklists.
