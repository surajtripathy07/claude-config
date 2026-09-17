# Phase 5 — Reproduce the author's testing

The standard is: do what the author says they did, as literally as the local environment
allows, and record where reality diverged. Reading the diff and reasoning about behaviour is
Phase 4. This phase is about observing behaviour.

## 1. Extract the author's steps

From the MR description's "How to set up and validate locally" (both repos' templates have
it). Copy the steps verbatim into the record's Reproduction section as the left column of
the table. Also copy the "Feature flags to enable before testing" list.

If there are no steps: derive a minimal path from the diff (which controller / mutation /
job / view changed, what input reaches it), write it down labelled **derived, not
author's**, and draft a request to the author for their steps (queue). If there are no
Before/After screenshots and the change is visible in the UI, add that to the same
request.

## 2. Prepare the environment (profile-specific)

The profile gives the exact commands for: starting the app, the local URL, enabling a
feature flag locally, opening a Rails console, seeding a customer / subscription / project
in the state the steps need. Record every record created (table, id) so Phase 8 can remove
it.

Before starting anything, check the baseline listeners: if the web process is already up,
it is running the branch's code only after a restart when Ruby files changed (Rails dev
mode reloads app code but not initializers, gems, or config). Restart it if the diff
touches `config/`, `lib/`, `Gemfile`, or initializers, and record that a restart happened.

## 3. Drive the UI with the chrome-devtools MCP

Tools are `mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`. Typical loop:

```
new_page(url)                       open the local URL
take_snapshot()                     accessibility tree with element uids, cheaper than screenshots
click(uid) / fill(uid, text) / fill_form(...)
wait_for(text)                      wait for the page to settle on visible text
take_screenshot(filePath=artifacts/05-<step>.png)
list_console_messages() / list_network_requests()   errors and the GraphQL calls the step fired
```

Rules:

- One screenshot per author step that has a visible result, saved as
  `artifacts/05-<n>-<slug>.png`; reference the path in the record.
- After each step, pull console errors and any failed network request (4xx/5xx). A JS error
  the author's screenshot does not show is a finding.
- For GraphQL-driven UIs, capture the request body of the mutation the step fires with
  `get_network_request(id)` and check it matches what the backend change expects.
- Compare with the author's After screenshot side by side and state match / mismatch in
  words (what differs, not "looks different").

## 4. Console checks with `bin/rails c`

For behaviour that the UI does not show (a validation now passing, a flag gating a path,
a service returning a different result), run it in the console and paste the exact input
and output into the record. Prefer the same objects the UI steps created so the two views
agree. Use `--sandbox` when the check only reads.

## 5. Negative check

Where cheap, also show the change doing the work: turn the flag off (or use the base
branch state) and repeat the key step, expecting the old behaviour. A change that behaves
the same with and without its flag is a finding.

## 6. Record

| Author's step | What I did (command / click) | What I saw (artifact) | Match |
|---|---|---|---|

Followed by: records created (for Phase 8), flags changed (for Phase 8), and anything I
could not do locally with the reason (external sandbox, missing seed, permission).
