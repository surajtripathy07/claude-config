# Profile: gitlab-org/gitlab under GDK

Verified against `~/repo/gitlab-development-kit/gitlab` on 2026-09-07 (docs and tooling
read from the clone). Facts marked **(first use)** have not been exercised in a real review
yet; confirm them the first time and drop the marker.

## Identity

- Repo: `~/repo/gitlab-development-kit/gitlab`. GDK root: `~/repo/gitlab-development-kit`
  (`gdk.yml`, `GDK_ROOT`). API project path `gitlab-org%2Fgitlab`.
- Default branch `master`. App URL `http://gdk.test:3000`.
- This machine's `gdk.yml` sets `GITLAB_SIMULATE_SAAS: "1"` (instance behaves as
  GitLab.com; affects feature availability and flag checks), Vite on, webpack off,
  `license.customer_portal_url: http://localhost:5000` (pairs with local CustomersDot).
- `gdk start` / `gdk stop` / `gdk status` / `gdk restart`; partial `gdk start db`.
  Console: `gdk rails c` or `bin/rails c` from the gitlab dir. `gdk psql` for SQL.

## Review conventions that already exist here

- **Duo instructions**: `.gitlab/duo/mr-review-instructions.yaml` (~140 KB). Key
  reviewer-relevant rules: CE code must not reference `EE::` directly (use `prepend_mod` /
  `Gitlab.ee?`); any new or changed query or scope needs a database reviewer with raw SQL
  and plans in the MR description, under 100 ms, plan covering the full chained query
  (scopes, pagination, ordering); N+1 avoidance; conditions on `update_all` /
  `delete_all` / `destroy_all`; spec placement mirrors app placement, EE specs under
  `ee/spec/`.
- **Code review guidelines**: `doc/development/code_review.md` (acceptance checklist,
  approval guidelines table: which change types need database / frontend / backend / UX /
  security / docs specialists).
- **Ownership**: `.gitlab/CODEOWNERS` sections (`[Database] @gitlab-org/maintainers/database`
  and many others). Reviewer dashboard `https://gitlab-org.gitlab.io/gitlab-roulette/`.

## Danger and roles

- Roulette comment posted by `gitlab-bot`, heading `## Reviewer roulette suggestions`,
  table `| Category | Reviewer | Maintainer |` (the Reviewer column may be hidden by an
  A/B experiment; then `| Category | Maintainer |`).
- DB review is required when `~database` is set or `tooling/danger/database.rb` finds
  changes: any `db/**` (not click_house/fixtures), `db/docs/*.yml`,
  `lib/gitlab/{database,background_migration,sql}`, `app/finders/`, `spec/migrations`,
  `rubocop/cop/migration`, and **any `app/models/` change whose changed lines contain
  `scope :`, `where(`, or `joins(`**, plus any `app|lib` line adding `update_all`,
  `upsert`, `upsert_all`, `delete_all`, `destroy_all`.
- `danger/database/Dangerfile` also fails the MR when a migration is added without the
  `database-testing-automation` label (the `db:gitlabcom-database-testing` job, ~30 min),
  warns on migrations older than 21 days, and warns when `db/structure.sql` was not
  updated. `~"database::approved"` silences it.

## Branch and specs

```sh
glab mr checkout <iid>
bundle install ; yarn install                              # only if lockfiles changed
bundle exec rake db:migrate RAILS_ENV=development           # if migrations present
bundle exec rake db:migrate RAILS_ENV=test
bin/rspec <spec files>                                      # spring-backed; :line and -e work
yarn jest <path>                                            # frontend
bundle exec rubocop <changed .rb>                           # 43 Migration/* cops live in rubocop/cop/migration/
```

Finding the specs for a change (prints a space-separated list, no trailing newline):

```sh
bin/rspec $(tooling/bin/predictive_tests --changed-files "$(git diff --name-only master...HEAD)")
```

Jest equivalent: `scripts/frontend/find_jest_predictive_tests.js` **(first use)**.
Frontend fixtures must be current for fixture-backed Jest specs:
`bin/rspec spec/frontend/fixtures/<area>.rb` or `rake frontend:fixtures`.

EE-touching MR: also run as FOSS. Feature specs need matching backend and frontend
editions: `export FOSS_ONLY=1 && gdk start && bin/rspec spec/features/...`; unit specs
and Jest: `FOSS_ONLY=1 bin/rspec …`, `FOSS_ONLY=1 yarn jest …`. Unset afterwards and
restart GDK (Phase 8).

Migration rollback check, database-scoped, while on the MR branch:

```sh
VERSION=<ts> bundle exec rails db:migrate:down:main      # or :ci / :sec per gitlab_schema
VERSION=<ts> bundle exec rails db:migrate:main
```

`db/structure.sql` and the checksum file `db/schema_migrations/<timestamp>` must both be
in the diff for every new migration. `scripts/regenerate-schema` rebuilds the structure
file (forces `RAILS_ENV=test`, applies every migration on disk).

## Database review specifics

- Full checklist: `references/database.md`, which is distilled from
  `doc/development/database_review.md` and `doc/development/database/*.md` in this clone.
  When an item fires, open the local doc file rather than fetching the website.
- New table → `db/docs/<table_name>.yml` in the **same commit** with `table_name`,
  `feature_categories`, `milestone`, `gitlab_schema`, `table_size` (`small` default;
  `unknown|small|medium|large|over_limit`), optional `description`, `introduced_by_url`,
  `sharding_key` when the column is `NOT NULL`.
- Data migrations need a spec under `spec/migrations/` (`require_migration!`, no
  FactoryBot); schema-only post-migrations are exempt.
- **Query plans** come from Database Lab through the postgres.ai CLI
  (`doc/development/database/database_lab.md`):

  ```sh
  npm install -g postgresai && postgresai login && postgresai set-default-project gitlab-production-main
  postgresai joe explain "<SQL with real ids>"        # explain (analyze, buffers) on a prod clone, shareable link
  postgresai joe result <command-id>                  # when the 25 s budget is exceeded
  postgresai joe describe <table_or_index>            # \d substitute
  ```

  Web console: `https://console.postgres.ai/gitlab/joe-instances`. Database Lab lags
  production by a few hours. `exec` runs DDL for timing an index build.
- High-traffic table list for cops: `rubocop/rubocop-migrations.yml`. Table sizes:
  `scripts/database/table_sizes.rb` **(first use)**.

## Running the app and reproducing

- `gdk status`, then `gdk start` if needed. Record which services were already up.
- Feature flags are Flipper-style, in console: `Feature.enable(:name)`,
  `Feature.disable(:name)`, `Feature.enabled?(:name)`; per-actor
  `Feature.enable(:name, Project.find(id))`. Non-default types need `type:`. Definition
  files `config/feature_flags/<type>/<name>.yml` must exist for the flag to be read
  (keys: `name`, `description`, `feature_issue_url`, `introduced_by_url`,
  `rollout_issue_url`, `milestone`, `group`, `type`, `default_enabled`; `gitlab_com_derisk`
  and `wip` cannot be `default_enabled: true`).
  - **Baseline:** `Feature.persisted_name?(:name)` and `Feature.enabled?(:name)` per flag,
    saved verbatim (verified on !254717). **Restore:** `Feature.remove(:name)` if it was not
    persisted at baseline, otherwise re-set to the captured value.
- Seed data: `doc/development/data_seeder.md` **(first use)**; simplest is creating
  records in `gdk rails c` and recording ids.
- Chrome: `http://gdk.test:3000`, login `root` / GDK default password from `gdk.yml` or
  the GDK docs.

## Database snapshot for restore

GDK runs PostgreSQL 17 on a socket in `<gdk>/postgresql`; the `pg_dump` on `PATH` is 16
and refuses. Use the version-matched binaries:

```sh
PG=~/.local/share/mise/installs/postgres/17/bin
H=~/repo/gitlab-development-kit/postgresql
for db in $(psql -h $H -Atc "select datname from pg_database where datname like 'gitlabhq_development%'"); do
  $PG/pg_dump -Fc -h $H $db > "$B/$db.dump"        # gitlabhq_development ≈ 26 MB, ~7 s
done
# restore each
gdk stop rails-web rails-background-jobs   # release connections; record what was stopped
$PG/dropdb -h $H $db && $PG/createdb -h $H $db && $PG/pg_restore -h $H -d $db "$B/$db.dump"
```

Schema version: `psql -h $H -d gitlabhq_development -Atc "select max(version) from schema_migrations"`.

## Pipeline

`glab api projects/gitlab-org%2Fgitlab/merge_requests/<iid>/pipelines` then jobs. The
pipeline is very large; look specifically for `rspec` failures matching the changed area,
`db:gitlabcom-database-testing`, `danger-review`, `rubocop`, `jest`, `eslint`.

## Reviewing from a worktree (verified on !254129, 2026-09-09)

When the GDK checkout is dirty or on the user's own branch, do not `glab mr checkout` it. Instead:
`git fetch origin merge-requests/<iid>/head:refs/remotes/origin/mr-<iid>` and
`git worktree add -b review/mr-<iid> <gitlab>/.claude/worktrees/review-<iid> origin/mr-<iid>`
(`.claude/` is gitignored). Copy the gitignored runtime config from the main checkout
(`config/{cable,database,gitlab,resque,secrets,session_store}.yml`, `config/redis.*.yml`,
`config/puma.rb`, `config/vite.gdk.json`) and `.bundle/`, then `bundle install`. Also copy the built Vite manifest (`public/assets/vite/.vite/manifest*.json`, gitignored) into the worktree, or every request spec fails with `Vite Ruby can't find styles/emoji_sprites.css in the manifests` (seen on !254717). `gdk start
postgresql redis` is enough for `bin/rails runner` and `bin/rspec`; `spec_helper`'s
`maintain_test_schema!` rebuilds the test DB, and the first spec run builds Gitaly under
`tmp/tests/` (~45 min). The GDK web process keeps serving the main checkout; exercise GraphQL
with `GITLAB_SIMULATE_SAAS=1 bin/rails runner` + `GitlabSchema.execute(..., context: { current_user: })`
and say in § 5 that GitLab's HTTP layer was covered by the request spec. Remove the worktree in
Phase 8 (`git worktree remove --force` + `git branch -D review/mr-<iid>`).
