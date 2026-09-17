# Profile: gitlab-org/customers-gitlab-com (CustomersDot)

Verified against the local clone on 2026-09-07; Postgres/mise note added 2026-09-08; worktree variant added 2026-09-09. Re-verify a fact before relying on it if
the file it names has moved.

## Identity

- Remote: `git@gitlab.com:gitlab-org/customers-gitlab-com.git`. API project path
  `gitlab-org%2Fcustomers-gitlab-com`.
- Default branch `main`. Rails 8, Ruby 3.4, PostgreSQL 16, Vue 2.7 + Vite, Jest, RSpec.
- Repo instructions: `CLAUDE.md` (never `--no-verify`, no DB commands without confirmation).
- Domain knowledge to ground in: `doc/agents/PROJECT_MAP.md` (system map),
  `doc/agents/INDEX.md` (per-domain deep dives), `doc/agents/orbit-queries.md` (history
  queries over MRs and issues via the Orbit MCP).

## Review conventions that already exist here

- **Duo instructions**: `.gitlab/duo/mr-review-instructions.yaml`. Conventional Comments,
  and these are **blocking** by the repo's own rule: an internal service returning
  `ServiceResponse` instead of dry-monads; a new foreign key without `on_delete`; a
  controller action without `authorize!`; a controller or job without `feature_category`;
  `:vcr`/`:zuora` metadata outside `spec/system/`; a VCR cassette containing a live secret
  (grep new cassettes for `Authorization:` and `Basic `); a new Rails fixture file; any
  edit to a migration that has already run.
- **Skill routing** (this repo's own skills, symlinked into `.claude/skills/`):
  - Ruby under `app/`, `lib/`, `db/migrate/` → `.agents/skills/rails/SKILL.md`; review
    checklist `references/review.md`, migrations `references/migrations.md`, security
    `references/security.md`.
  - `spec/**/*.rb` → `.agents/skills/rspec/SKILL.md` and its `references/*-specs.md`.
  - `app/frontend/**`, `spec/frontend/**`, `*.vue` → `.agents/skills/frontend/SKILL.md`.
- **MR template**: `.gitlab/merge_request_templates/Default.md` — sections "What does this
  MR do and why?", "Screenshots or screen recordings" (Before/After table), "How to set up
  and validate locally" (feature flags + numbered test steps), acceptance checklist.

## Danger and roles

- `Dangerfile` category map: `db/**` → database (except `db/clickhouse/`), `*.rb` →
  backend, `*.vue|js|scss` → frontend, `app/views/**` → both, `spec/system/**` → test,
  `qa/**` → qa, `doc/**` → documentation, everything else backend.
- `danger/database/Dangerfile`: warns when a migration is added without a
  `db/structure.sql` change; reminds about column comments; when `~database` is set or
  any `db/` file changed it posts "This merge request requires a database review" and
  adds `~"database::review pending"`. `~"database::approved"` silences it.
- Roulette comment: posted by a project bot user (`project_2670515_bot_…`), heading
  `## Reviewer roulette`, table `Category | Reviewer | Maintainer`. Ownership page:
  handbook engineering projects, anchor `#customers-app`. Workload dashboard:
  `https://gitlab-org.gitlab.io/gitlab-roulette/?currentProject=customers-app`.
- Domain experts: `danger/reviewer_data.json` lists `business_systems`, `lr_support`,
  `zuora_architects` reviewers (pinged by the business-system roulette). Fulfillment
  group ownership for a feature: `doc/team-ownership.md`.

## Branch and specs

**Worktree variant** (use when the user says "in a new worktree" or the main tree is dirty and they do
not want a stash): `git fetch origin <branch>:<branch>` (fast-forwards the local branch when it is not
checked out anywhere), `git worktree add ~/repo/customers-gitlab-com-review-<iid> <branch>`, then copy the
gitignored `.env` and `config/database.yml` from the main tree into it (never print them). Gems are shared,
so `bundle check` is enough. The dev DB is shared with the main tree: for a console-only MR skip
`db:migrate` (runner and rspec work with base migrations pending) and record the deviation; for an MR that
needs puma, migrate after `pg_dump` as usual and roll back in Phase 8 from inside the worktree. Restore =
`git worktree remove --force <dir> && git worktree prune`; the main tree's branch, status and stash never
change, verify them anyway. Verified 2026-09-09 on !17051 round 2.


```sh
glab mr checkout <iid>
bundle check || bundle install   # ALWAYS check: the MR base (main) is usually newer than the user's branch
yarn install              # only if yarn.lock changed vs the baseline branch
bin/rails db:migrate      # if db/migrate changed; then the rollback check below
bin/rspec <spec files>    # spring-backed; fine for up to a few dozen files
bin/parallel_rspec <dir>  # larger targeted sets
yarn jest <path>          # frontend
bin/rubocop <changed .rb> ; yarn lint:eslint ; yarn lint:prettier ; bin/haml-lint <changed .haml>
```

Mapping changed files to specs: `app/x/y.rb` → `spec/x/y_spec.rb`; also
`grep -rl "<ClassName>" spec/` for indirect coverage. Frontend `app/frontend/…/Foo.vue` →
`spec/frontend/…/foo_spec.js`. There is no predictive-test tool in this repo.

Spec metadata worth knowing when reading failures: `:vcr`/`:zuora` (system specs hit
recorded Zuora cassettes), `quarantine:` (skipped by default), `inline_jobs`,
`freeze_time`. Flaky-spec guidance: `doc/testing/rails.md`.

Migration rollback check (Phase 3 step 3), while on the MR branch:

```sh
bin/rails db:migrate && git diff --stat db/structure.sql     # must show only the MR's change
bin/rails db:rollback STEP=<n> && bin/rails db:migrate       # n = migrations the MR adds
```

## Database review specifics

- Every new column carries a JSON comment built by a private `comment` method with
  `owner`, `data_classification`, `description` (see
  `.agents/skills/rails/references/migrations.md`).
- This repo has **none of gitlab.com's DB tooling**: no postgres.ai, no Database Lab, no
  `db:gitlabcom-database-testing` job, no `db/docs` dictionary, no batched background
  migration framework. The upstream checklist items that depend on those are `n/a` here
  and the intent behind them is met as follows:
  - **Query plans** come from the production read-only replica via Teleport (the
    access broker for staging/production DB and console; `doc/setup/teleport.md`):

    ```sh
    tsh login --proxy=production.teleport.gitlab.net \
      --request-roles=prdsub-customersdot-database-rw \
      --request-reason="DB review of !<iid>"          # approval needed, 12h window
    tsh db login --db-user=teleport-cloudsql@gitlab-subscriptions-prod.iam \
      --db-name=CustomersDot_production db-customersdot-gprd-ro
    tsh db connect db-customersdot-gprd-ro
    -- then: EXPLAIN (ANALYZE, BUFFERS) <query with real parameter values>;
    ```

    Staging replica `db-customersdot-gstg-ro` needs no approval but is not
    representative of production volume; say which one a plan came from. Plans are
    pasted into the MR inside a collapsed `<details>` block. If shared via
    explain.depesz.com, anonymize first.
  - **Timing**: no formal table exists here. Use the upstream thresholds as the bar
    (query < 100 ms, migration transaction comfortably < 15 s) and ask the author for the
    replica measurement when a migration touches a large table. Table sizes: run
    `select relname, pg_size_pretty(pg_total_relation_size(oid)), n_live_tup from pg_class
    join pg_stat_user_tables using (relname) order by 2 desc` on the replica.
  - **New tables**: the load conversation (Phase 4, `references/database.md` § New tables)
    is the whole check. There is no dictionary file to inspect.
- Local load simulation: dev DB `payment_app_development` is small (~27 MB). To test a
  query against realistic distribution, generate rows with a console script or
  `bin/rails db:seed_fu FILTER=<seed>` and record the counts; `references/database.md`
  § Simulating load locally has the procedure.

## Health check after setting up the MR branch (Phase 3 step 3b)

```sh
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5000/                 # 200 or 302, never 500
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5000/graphql-explorer  # 200 (dev only)
curl -s -H 'Content-Type: application/json' --data '{"query":"{ __typename }"}' http://localhost:5000/graphql  # JSON, not HTML
bin/rails runner 'puts Rails.application.class.name'                             # boots
```

Rails dev mode reloads `app/` on the next request, so the running puma serves the MR's code
without a restart. A restart (user's go) is needed only for `config/`, `lib/`, initializers,
or gem changes. A 500 here after migrations and gems are in place is the MR's problem:
capture the exception from the HTML (`<h1>` of the debug page) or `log/development.log`.

## Running the app and reproducing

- **Postgres may be down entirely** (seen 2026-09-08): `psql` fails with "No such file or directory" on
  `/tmp/.s.PGSQL.5432`. Start it the way the repo does, `mise run database-start` (runs `pg_ctl start -D
  ./db/postgresql`; that dir is gitignored — an untracked `db/postgresql-16/` is a stray copy, not the data
  dir). Stop with `mise run database-stop` in Phase 8. Record it in `artifacts/baseline/processes_started`.
  A console-only MR (no routes, no views rendered by ActionView) needs Postgres only; do not start `bin/dev`
  for it — run the runner boot check instead of the curl checks and say so in § 3.
- Start: `./bin/dev` (Procfile via hivemind/foreman: web on `localhost:5000`, `redis`,
  `sidekiq`, `vite` on 3036, `clickhouse` on 8123/9000). Check what is already up with
  `lsof -nP -iTCP -sTCP:LISTEN`. If the user's own `bin/dev` is running, do not kill it;
  Rails dev mode reloads `app/` code, so a restart is only needed for `config/`, `lib/`,
  initializers, or gem changes, and then only with the user's go.
- Console: `bin/rails c` (`--sandbox` for read-only checks). Remote debugger docs:
  `doc/development/debugging.md`.
- Login and GitLab pairing: `doc/setup/gitlab.md` (local GitLab on 3000 pairs with
  CustomersDot on 5000). Zuora sandbox users: `doc/setup/zuora_sandbox_users.md`.
- Test data: `doc/testing/creating_test_data.md` (ZDot for end-to-end customer /
  subscription setups; `zuora_products` fixtures; `rake db:seed_fu`). Impersonation:
  `doc/testing/impersonating.md`.
- Chrome: drive `http://localhost:5000` through the `chrome-devtools` MCP tools. If the MCP
  reports the profile is already in use, do not kill the browser; fall back to `curl` and
  the runner.
- **Pending migrations break the user's running server.** If the MR's base has migrations
  the local DB has not run, every request to the already-running puma returns
  `ActiveRecord::PendingMigrationError` (500) while the MR branch is checked out.
  `bin/rails runner` and `bin/rspec` are unaffected. Phase 3 applies them (after a
  `pg_dump` snapshot) so the app runs; Phase 8 rolls them back, but only once the user says
  the review is done. The local DB also carries an orphan version `20260309120000` that
  exists on no branch; it makes `db/structure.sql` drift after any dump and is not ours to
  fix.
- **GraphQL without a browser:** `bin/rails runner` with
  `PaymentAppSchema.execute(query, context: { current_user: customer, current_ability: customer.ability })`
  runs the full resolver/type/model stack for the SaaS path. `GraphqlController#current_user`
  is `current_customer || current_admin || gitlab_customer_from_jwt`; customers have no
  password (GitLab OAuth), admins cannot resolve subscriptions (`SubscriptionsFinder` needs
  `zuora_account_id`), so a Customer is the only workable `current_user`.
- **Local credits data pitfalls** (as of 2026-09-07): seeded consumer ids are 11 digits and
  exceed GraphQL `Int` (`userIds` rejects them); for the `A-S000*` subscriptions the
  ClickHouse `Subject` and `consumers.entity_id` are zero-padded strings, so per-user
  ClickHouse reads keyed by `user_id.to_s` return empty. Use the model layer for non-empty
  results or seed events with a small Subject. `Consumer#user_id` is `entity_id.to_i`, not a
  column. ClickHouse HTTP: `curl 'http://localhost:8123/?database=customersdot_development' --data-binary "<sql>"`.

## Feature flags (Unleash, not Flipper)

- Code reads `Unleash.enabled?(:flag)`. Flags live on gitlab.com:
  `https://gitlab.com/gitlab-org/customers-gitlab-com/-/feature_flags`. `Feature.enabled?`
  (Flipper) is only for maintenance-mode health flags.
- Local scope is `customers-development-<UNLEASH_APP_NAME>` when `UNLEASH_APP_NAME` is set
  in `.env` (it is, on this machine; do not print the value), otherwise
  `customers-development`. Confirm in console: `Unleash.configuration.app_name`.
- **Read state (baseline):**
  `glab api projects/gitlab-org%2Fcustomers-gitlab-com/feature_flags/<name>` → look at
  `active` and `strategies[].scopes[].environment_scope`. Save the JSON verbatim.
- **Change state:** the flag object is shared by every developer; adding or removing a
  strategy scope for the local dev scope only affects this machine, but it is still an
  API write on a shared object. Show the user the exact change (UI steps or the `PUT
  projects/:id/feature_flags/<name>` body) and get a go before doing it. The Unleash
  client polls; wait for the refresh interval or restart the web process before trusting
  `Unleash.enabled?`.
- **Restore:** re-apply the saved JSON's strategies for the dev scope, re-read, diff.
- Unleash setup doc: `doc/setup/unleash.md`.

## Database snapshot for restore

```sh
pg_dump -Fc payment_app_development > "$B/payment_app_development.dump"    # ~27 MB, seconds
# restore
dropdb payment_app_development && createdb payment_app_development \
  && pg_restore -d payment_app_development "$B/payment_app_development.dump"
```

Stop the web and sidekiq processes this review started before `dropdb`; if the user's
own processes hold connections, ask before terminating them. Schema version check:
`psql -d payment_app_development -Atc "select max(version) from schema_migrations"`.

## Pipeline

`glab ci status` on the checked-out branch, or
`glab api projects/gitlab-org%2Fcustomers-gitlab-com/merge_requests/<iid>/pipelines`
then `glab api projects/:id/pipelines/<id>/jobs?per_page=100` for job names and states.
Retry flakes are documented in `doc/testing/index.md` (quarantine, `RETRY_SPECS`).
