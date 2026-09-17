---
These reference files distill GitLab's public developer documentation (docs.gitlab.com) into a portable review checklist — freely readable, sourced, and not specific to any one project's private code. The distillation is pinned at docs commit `<sha>` — refresh this file when the docs change and record the new commit here. Source of truth is those docs, not this file: when an item fires during a review, open the doc it cites and read that section in full before recording a verdict. Where the project under review differs, the profile says so — see "Applicability" at the end.
---

# Database Review — Reviewer Checklist (distilled from public developer docs)

**Source of truth:** the upstream project's public `doc/development/` tree, read in full at a pinned commit. Nothing below is invented; where the docs are silent, this document is silent. Each item cites its source path and public URL so it can be re-read.

**Notation:** each checklist item ends with a `Source:` line giving the repo path + heading anchor and the public URL. Thresholds are quoted as written in the docs.

---

## 1. Roles and process

### 1.1 When a database review is required (trigger list)

A database review is required for:

- Changes that touch the database schema or perform data migrations, including files in:
  - `db/`
  - the background-migration job directory
- Changes to the database tooling. For example:
  - the project's migration or ActiveRecord helper modules
  - load balancing
- Changes that produce SQL queries that are beyond the obvious. It is generally up to the author of a merge request to decide whether or not complex queries are being introduced and if they require a database review.
- Changes in Service Data metrics that use `count`, `distinct_count`, `estimate_batch_distinct_count`, and `sum`. These metrics could have complex queries over large tables.
- Changes that use `update`, `upsert`, `delete`, `update_all`, `upsert_all`, `delete_all`, or `destroy_all` methods on an ActiveRecord object. (Danger comments on the MR diff when these are used; they are also incompatible with CTE statements.)

A database reviewer is expected to look out for overly complex queries in the change and review those closer. If the author does not point out specific queries for review and there are no overly complex queries, it is enough to concentrate on reviewing the migration only.

Source: `doc/development/database_review.md#general-process` — https://docs.gitlab.com/development/database_review/#general-process
Source: `doc/development/database_review.md#preparation-when-using-bulk-update-operations` — https://docs.gitlab.com/development/database_review/#preparation-when-using-bulk-update-operations

### 1.2 Required artifacts (review is reassigned to the author if missing)

**Migrations.** If new migrations are introduced, database reviewers must review the output of both migrating (`db:migrate`) and rolling back (`db:rollback`) for all migrations. The `db:check-migrations` pipeline job provides this output in the CI job logs; the author is not required to paste it into the MR description, but may. The bot also checks that migrations are correctly reversible.

**Queries.** If new queries have been introduced or existing queries have been updated, the author is **required to provide**:

- Query plans for each raw SQL query included in the MR along with the link to the query plan following each raw SQL snippet.
- Raw SQL for all changed or added queries (as translated from ActiveRecord queries).
  - In case of updating an existing query, the raw SQL of both the old and the new version of the query should be provided together with their query plans.

Source: `doc/development/database_review.md#required` — https://docs.gitlab.com/development/database_review/#required

### 1.3 Roles

**Author**:
- Decide whether a database review is needed.
- If database review is needed, add the `~database` label.
- Prepare the merge request for a database review (section 1.5).
- Provide the required artifacts prior to submitting the MR.

**Database reviewer**:
- Ensure the required artifacts are provided and in the proper format. If they are not, reassign the merge request back to the author.
- Perform a first-pass review on the MR and suggest improvements to the author.
- Once satisfied, relabel the MR with `~"database::reviewed"`, approve it, and request a review from the database **maintainer** suggested by Reviewer Roulette.

**Database maintainer**:
- Perform the final database review on the MR.
- Discuss further improvements or other relevant changes with the database reviewer and the MR author.
- Finally approve the MR and relabel the MR with `~"database::approved"`.
- Merge the MR if no other approvals are pending or pass it on to other maintainers as required (frontend, backend, documentation).

Source: `doc/development/database_review.md#roles-and-process` — https://docs.gitlab.com/development/database_review/#roles-and-process

The reviewer guidelines add: the database reviewer is tasked with reviewing the database-specific updates and making sure that any queries or modifications perform without issues at production scale. Reviewers are expected to review assigned change requests in a timely manner or let the author know as soon as possible and help them find another reviewer or maintainer; if at capacity, notify the author with a comment on the change request and reassign the review using whatever reviewer-assignment tooling the project has.

Source: `doc/development/database/database_reviewer_guidelines.md#scope-of-work-done-by-a-database-reviewer` — https://docs.gitlab.com/development/database/database_reviewer_guidelines/#scope-of-work-done-by-a-database-reviewer
Source: `doc/development/database/database_reviewer_guidelines.md#what-to-do-if-you-feel-overwhelmed` — https://docs.gitlab.com/development/database/database_reviewer_guidelines/#what-to-do-if-you-feel-overwhelmed

### 1.4 Labels and workload distribution

| Label | Who applies | When |
|---|---|---|
| `~database` | Author | When a DB review is needed. If the reviewer-assignment tooling did not suggest a database reviewer and maintainer, make sure the label is applied and rerun the job that produces the suggestions, or pick someone from the project's database-reviewer group. |
| the project's "database reviewed" label | Reviewer | After first-pass review and approval; then request the suggested database maintainer. |
| `~"database::approved"` | Maintainer | After final approval. |
| `~data-deletion` | Author | If the migration deletes data. |
| `pipeline:skip-check-migrations` | Author | Only for `db:check-migrations` false positives (see 2.1). |

Review workload is distributed by the project's reviewer-assignment tooling. The author should request a review from the suggested database **reviewer**; when they sign off, they hand over to the suggested database **maintainer**.

Source: `doc/development/database_review.md#distributing-review-workload` — https://docs.gitlab.com/development/database_review/#distributing-review-workload
Source: `doc/development/database_review.md#preparation-when-adding-data-migrations` — https://docs.gitlab.com/development/database_review/#preparation-when-adding-data-migrations
Source: `doc/development/database/dbcheck-migrations-job.md#false-positives` — https://docs.gitlab.com/development/database/dbcheck-migrations-job/#false-positives

### 1.5 How to prepare the merge request for a database review (author's exact list)

Source for all of 1.5: `doc/development/database_review.md#how-to-prepare-the-merge-request-for-a-database-review` — https://docs.gitlab.com/development/database_review/#how-to-prepare-the-merge-request-for-a-database-review

#### Preparation when adding migrations

- Ensure `db/structure.sql` is updated as documented, and additionally ensure that the relevant version files under `db/schema_migrations` were added or removed.
- Ensure that the Database Dictionary is updated as documented.
- Make migrations reversible by using the `change` method or include a `down` method when using `up`.
  - Include either a rollback procedure or describe how to rollback changes.
- Check that the `db:check-migrations` pipeline job has run successfully and the migration rollback behaves as expected.
  - Ensure the `db:check-schema` job has run successfully and no unexpected schema changes are introduced in a rollback. This job may only trigger a warning if the schema was changed.
  - Verify that the previously mentioned jobs continue to succeed whenever you modify the migrations during the review process.
- Add tests for the migration in `spec/migrations` if necessary.
- Lock retries are enabled by default for all transactional migrations. For non-transactional migrations review the relevant documentation for use cases and solutions.
- Ensure RuboCop checks are not disabled unless there's a valid reason to.
- When adding an index to a large table (list in `rubocop/rubocop-migrations.yml`), test its execution using `CREATE INDEX CONCURRENTLY` in Database Lab and add the execution time to the MR description:
  - Execution time largely varies between the plan service's clone and production, but an elevated execution time from Database Lab can give a hint that execution in production is also considerably high.
  - If the execution from Database Lab is longer than `10 minutes`, the index should be moved to a post-migration. Keep in mind that in this case you may need to split the migration and the application changes in separate releases to ensure the index is in place when the code that needs it is deployed.
- Manually trigger the database testing job (the migration-testing CI job) in the `test` stage.
  - This job runs migrations in a Database Lab clone and posts to the MR its findings (queries, runtime, size change).
  - Review migration runtimes and any warnings.

Anchor: `#preparation-when-adding-migrations`

#### Preparation when adding data migrations

Data migrations are inherently risky. Include in the MR description:

- If the migration itself is not reversible, details of how data changes could be reverted in the event of an incident. For example, in the case of a migration that deletes records (an operation that most of the times is not automatically reversible), how could the deleted records be recovered.
- If the migration deletes data, apply the label `~data-deletion`.
- Concise descriptions of possible user experience impact of an error; for example, "Issues would unexpectedly go missing from Epics".
- Relevant data from the query plans that indicate the query works as expected; such as the approximate number of records that are modified or deleted.

Anchor: `#preparation-when-adding-data-migrations`

#### Preparation when adding or modifying queries

See section 3 (Query plans) for the full Raw SQL and Query Plans requirements.

Anchor: `#preparation-when-adding-or-modifying-queries`

#### Preparation when adding foreign keys to existing tables

- Include a migration to remove orphaned rows in the source table before adding the foreign key.
- Remove any instances of `dependent: ...` that may no longer be necessary.

Anchor: `#preparation-when-adding-foreign-keys-to-existing-tables`

#### Preparation when adding tables

- Order columns based on the Ordering Table Columns guidelines.
- Add foreign keys to any columns pointing to data in other tables, including an index.
- Add indexes for fields that are used in statements such as `WHERE`, `ORDER BY`, `GROUP BY`, and `JOIN`s.
- New tables must be seeded by a file in `db/fixtures/development/`. These fixtures are also used to ensure that upgrades complete successfully, so it's important that new tables are always populated.
- Ensure that you do not use database tables to store static data. Use a fixed items model instead.
- New tables and columns are not necessarily risky, but over time some access patterns are inherently difficult to scale. To identify these risky patterns in advance, we must document expectations for access and size. Include in the MR description answers to these questions:
  - What is the anticipated growth for the new table over the next 3 months, 6 months, 1 year? What assumptions are these based on?
  - How many reads and writes per hour would you expect this table to have in 3 months, 6 months, 1 year? Under what circumstances are rows updated? What assumptions are these based on?
  - Based on the anticipated data volume and access patterns, does the new table pose an availability risk to the hosted service or customer-operated instances? Does the proposed design scale to support the needs of both hosted and customer-operated deployments?

Anchor: `#preparation-when-adding-tables`

#### Preparation when removing columns, tables, indexes, or other structures

- Follow the guidelines on dropping columns.
- Generally it's best practice (but not a hard rule) to remove indexes and foreign keys in a post-deployment migration.
  - Exceptions include removing indexes and foreign keys for small tables.
- When dropping indexes, verify that composite indexes can serve as replacements by checking composite index column order requirements.
- If you're adding a composite index, another index might become redundant, so remove that in the same migration. For example adding `index(column_A, column_B, column_C)` makes the indexes `index(column_A, column_B)` and `index(column_A)` redundant.

Anchor: `#preparation-when-removing-columns-tables-indexes-or-other-structures`

#### Preparation when using bulk update operations

Using `update`, `upsert`, `delete`, `update_all`, `upsert_all`, `delete_all`, or `destroy_all` requires extra care because they modify data and can perform poorly, or they can destroy data if improperly scoped. Follow the preparation for adding or modifying queries to add the raw SQL query and query plan to the MR description, and request a database review.

Anchor: `#preparation-when-using-bulk-update-operations`

---

## 2. Reviewer checklist

Grouped as `database_review.md#how-to-review-for-database` groups them, with supporting rules from the linked guides folded into each group.

### 2.1 Basic migration requirements

- [ ] **Database testing job passing.** Make sure the project's migration-testing CI job is passing.
  Source: `doc/development/database_review.md#basic-migration-requirements` — https://docs.gitlab.com/development/database_review/#basic-migration-requirements

- [ ] **`db/structure.sql` only contains related changes.** Verify that `db/structure.sql` contains only changes related to migrations in this merge request — no unrelated schema modifications. Columns must not be manually reordered for existing tables. For an async index, the schema change is committed in the *second* MR (the one with `add_concurrent_index`).
  Source: `doc/development/database_review.md#basic-migration-requirements`; `doc/development/migration_style_guide.md#schema-changes` — https://docs.gitlab.com/development/migration_style_guide/#schema-changes

- [ ] **Reversible with `#down`.** Check migrations are reversible and implement a `#down` method. Migrations **must be** reversible. If changes cannot be reversed (e.g. data loss), a `down` method with `# no-op` and a comment explaining why is still required, so the migration itself can be reversed. The migration should carry a comment describing how reversibility was tested. Note: many production environments use a roll-forward strategy, not `db:rollback`; `down` is primarily for development.
  Source: `doc/development/migration_style_guide.md#reversibility` — https://docs.gitlab.com/development/migration_style_guide/#reversibility

- [ ] **Transaction vs. `disable_ddl_transaction!`.** Ensure migrations are either run within a transaction (Rails default) or use only concurrent operations with `disable_ddl_transaction!`. `disable_ddl_transaction!` means "Do not execute this migration in a single PostgreSQL transaction." Required for `CREATE INDEX CONCURRENTLY` / `add_concurrent_index`, `add_concurrent_foreign_key`, `with_lock_retries`, batched DML, non-PostgreSQL targets (e.g. Redis), or multi-database targets. Subtransactions are disallowed.
  Source: `doc/development/migration_style_guide.md#disable-transaction-wrapped-migration` — https://docs.gitlab.com/development/migration_style_guide/#disable-transaction-wrapped-migration; `#atomicity-and-transaction`

- [ ] **`db/schema_migrations` checksum files.** Check that the relevant version files under `db/schema_migrations` were added or removed. File name = timestamp portion; content = SHA256 of the timestamp. Added when a migration is created; removed if deleted; regenerated if the timestamp changes; unchanged if only content changes.
  Source: `doc/development/migration_style_guide.md#migration-checksum-file` — https://docs.gitlab.com/development/migration_style_guide/#migration-checksum-file

- [ ] **`db:check-migrations` job.** Runs in the `test` stage and checks (1) schema dump after rollback matches target branch, (2) schema dump matches the committed `db/structure.sql`, (3) `db/schema_migrations` diff. Not allowed to fail. Known false positives: a dropped-then-rolled-back column is re-added at the end of the column list; `pg_dump` ordering changes after minor PostgreSQL upgrades (report in `#database`). In those cases the `pipeline:skip-check-migrations` label may be added. Rollback comparison failure often means the branch is behind target — rebase.
  Source: `doc/development/database/dbcheck-migrations-job.md` — https://docs.gitlab.com/development/database/dbcheck-migrations-job/; `#false-positives`; `#schema-dump-comparison-fails-after-rollback`

- [ ] **Migration tests present where required.** Post migrations (`/db/post_migrate`) and background migrations **must** have migration tests. Data migrations **must** have a migration test. Tests are not enforced on post migrations that only perform schema changes. Expect in `spec/migrations`: `require_migration!`, `table(:name)` (not FactoryBot), `migrate!`, `reversible_migration`, `have_scheduled_batched_migration`, `be_finalize_background_migration_of`. Specs run under the migration tag; a spec touching a non-default database declares which one. No transaction is present (deletion cleanup strategy).
  Source: `doc/development/testing_guide/testing_migrations_guide.md#when-to-write-a-migration-test` — https://docs.gitlab.com/development/testing_guide/testing_migrations_guide/#when-to-write-a-migration-test; `#test-helpers`

### 2.2 Style and standards compliance

- [ ] **Follows the migration style guide.** Migrations inherit from the latest `Gitlab::Database::Migration[x.y]` (look up in `MIGRATION_CLASSES`); do not include `Gitlab::Database::MigrationHelpers` directly.
  Source: `doc/development/migration_style_guide.md#migration-helpers-and-versioning` — https://docs.gitlab.com/development/migration_style_guide/#migration-helpers-and-versioning

- [ ] **Milestone declared.** All new migrations must specify a milestone (`milestone '16.6'`).
  Source: `doc/development/migration_style_guide.md#milestone` — https://docs.gitlab.com/development/migration_style_guide/#milestone

- [ ] **Timestamp age.** A new migration's timestamp should never be before the previous required upgrade stop (hard rule). Best practice: within three weeks of anticipated merge; run `scripts/refresh-migrations-timestamps` if in review > 3 weeks or rebasing old branches.
  Source: `doc/development/migration_style_guide.md#migration-timestamp-age` — https://docs.gitlab.com/development/migration_style_guide/#migration-timestamp-age

- [ ] **Naming.** Names for database objects (tables, indexes, views) must be lowercase. Indexes created with `where`, `using`, `order`, `length`, `type`, or `opclass` **must** have an explicit `name:`. Custom index/constraint names follow the constraint naming convention. Long index names: prefix `i_`, skip redundant prefixes, or name by purpose. Temporary indexes are prefixed `tmp_`, with a follow-up removal issue and a comment in the migration.
  Source: `doc/development/migration_style_guide.md#naming-conventions` — https://docs.gitlab.com/development/migration_style_guide/#naming-conventions; `doc/development/database/adding_database_indexes.md#requirements-for-naming-indexes` — https://docs.gitlab.com/development/database/adding_database_indexes/#requirements-for-naming-indexes; `#temporary-indexes`

- [ ] **Index existence checks use the name.** Conditional logic must test for index existence by name (`index_name_exists?` or `index_exists?(..., name:)`), because `index_exists?` without a name matches any index on the same table+columns. Concurrent helpers already check internally.
  Source: `doc/development/database/adding_database_indexes.md#testing-for-existence-of-indexes` — https://docs.gitlab.com/development/database/adding_database_indexes/#testing-for-existence-of-indexes

- [ ] **Column ordering.** Columns of new tables are ordered to use the least amount of space: type size descending, variable-size types (`text`, `varchar`, arrays, `json`, `jsonb`) at the end. See section 5 for the size table.
  Source: `doc/development/database/ordering_table_columns.md` — https://docs.gitlab.com/development/database/ordering_table_columns/

- [ ] **Indexes present for foreign keys.** Indexes are required for all foreign keys and must be added before the foreign key (earlier step in same migration or an earlier migration). FKs must be removed before removing their supporting indexes. A composite index counts only if the FK column is in the first position; partial indexes like `BTREE (project_id) WHERE user_id IS NULL` can never serve as the FK index.
  Source: `doc/development/database/foreign_keys.md#indexes` — https://docs.gitlab.com/development/database/foreign_keys/#indexes

- [ ] **Every FK has `ON DELETE`.** Every foreign key must define an `ON DELETE` clause, and in 99% of the cases this should be set to `CASCADE`.
  Source: `doc/development/database/foreign_keys.md#cascading-deletes` — https://docs.gitlab.com/development/database/foreign_keys/#cascading-deletes

- [ ] **FK columns are `bigint`.** New foreign keys must be defined as `bigint`, even if the referenced PK is `integer`.
  Source: `doc/development/database/foreign_keys.md#use-bigint-for-foreign-keys` — https://docs.gitlab.com/development/database/foreign_keys/#use-bigint-for-foreign-keys

- [ ] **`_id` suffix has an FK.** `spec/db/schema_spec.rb` checks all `_id` columns have an FK; exceptions go in `ignored_fk_columns_map` only for: cross-schema references, Loose Foreign Key replacements, polymorphic relationships (should not be used), or columns not referencing a table (e.g. `partition_id`). Third-party IDs use `_xid`.
  Source: `doc/development/database/foreign_keys.md#naming-foreign-keys` — https://docs.gitlab.com/development/database/foreign_keys/#naming-foreign-keys

- [ ] **No `dependent: :destroy` / `dependent: :delete`, no `before_destroy`/`after_destroy` unless approved by a database specialist.**
  Source: `doc/development/database/foreign_keys.md#dependent-removals` — https://docs.gitlab.com/development/database/foreign_keys/#dependent-removals

- [ ] **Timestamps with time zone.** Use `add_timestamps_with_timezone`, `timestamps_with_timezone`, `datetime_with_timezone` — not `timestamps`, `add_timestamps`, or `:datetime`.
  Source: `doc/development/migration_style_guide.md#timestamp-column-type` — https://docs.gitlab.com/development/migration_style_guide/#timestamp-column-type

- [ ] **Integer sizing.** Default `integer` is 4 bytes (max 2,147,483,647); use `limit: 8` for byte sizes etc.
  Source: `doc/development/migration_style_guide.md#integer-column-type` — https://docs.gitlab.com/development/migration_style_guide/#integer-column-type

- [ ] **JSONB.** `JSONB` columns must use `JsonSchemaValidator` with a `size_limit` (**64 KB** recommended maximum; `JsonbSizeLimit` cop). Schemas with `additionalProperties: false` need the multi-step add/remove-property process.
  Source: `doc/development/migration_style_guide.md#storing-json-in-database` — https://docs.gitlab.com/development/migration_style_guide/#storing-json-in-database; `doc/development/database/avoiding_downtime_in_migrations.md#changing-jsonjsonb-columns-with-schema-validation`

- [ ] **Encrypted attributes are `:jsonb`, not `:text`**, with a length validation (510 max is usually enough).
  Source: `doc/development/migration_style_guide.md#encrypted-attributes` — https://docs.gitlab.com/development/migration_style_guide/#encrypted-attributes

- [ ] **Data migrations prefer Arel/plain SQL** over ActiveRecord; plain SQL inputs quoted via `quote_string`. Models local to the migration inherit `MigrationRecord`, set `self.table_name` explicitly, and call `reset_column_information`. Application code in migrations is discouraged. Batch modifications with `each_batch_range` / `BATCH_SIZE`.
  Source: `doc/development/migration_style_guide.md#data-migration` — https://docs.gitlab.com/development/migration_style_guide/#data-migration; `#modifying-existing-data`; `#using-application-code-in-migrations-discouraged`

- [ ] **Database dictionary updated.** New table: a dictionary entry in the same commit as the migration, recording the table name, owning feature category, milestone, which database/schema it belongs to, its expected size, and its tenant-partitioning key where applicable. Dropped table: move file to `deleted_tables/` and add `removed_by_url` + `removed_in_milestone`. Same for views (`views/`, `deleted_views/`).
  Source: `doc/development/database/database_dictionary.md#adding-tables` — https://docs.gitlab.com/development/database/database_dictionary/#adding-tables; `#dropping-tables`; `#adding-views`; `#dropping-views`

- [ ] **RuboCop not disabled without valid reason** (including `Database/AvoidScopeTo`, `PreventIndexCreation`, `AddColumnsToWideTables`, `Migration::UnfinishedDependencies`). Large-table cop disables must link the approved exception issue.
  Source: `doc/development/database_review.md#preparation-when-adding-migrations`; `doc/development/database/large_tables_limitations.md#requesting-an-exception` — https://docs.gitlab.com/development/database/large_tables_limitations/#requesting-an-exception

### 2.3 Large table and size restrictions

- [ ] **Size thresholds.** Verify that indexes and columns are not added to pre-existing tables over the size threshold. Limitations (maximum size after the action, including indexes and column size), as applied in one large production environment:

  | Limitation | Maximum size after the action (including indexes and column size) |
  |---|---|
  | Cannot add an index | 50 GB |
  | Cannot add a column with foreign key | 50 GB |
  | Cannot add a new column | 100 GB |

  Exceptions should only be granted for: migrating a table's columns from `int4` to `int8`; adding a sharding key to support cells; modifying a table to assist in partitioning or data retention efforts; replacing an existing index to provide better query performance. Exception request via the `schema_change_exception` issue template; the approval issue is linked when disabling the cop.
  Source: `doc/development/database/large_tables_limitations.md#table-size-restrictions` — https://docs.gitlab.com/development/database/large_tables_limitations/#table-size-restrictions; `#exceptions`; `#requesting-an-exception`

- [ ] **Index on large table with elevated execution time (> 1h in Database Lab).** Make sure to follow the steps to add it asynchronously. **Maintainer:** after the MR is merged, notify Release Managers on `#f_upcoming_release` Slack.
  Source: `doc/development/database_review.md#large-table-and-size-restrictions` — https://docs.gitlab.com/development/database_review/#large-table-and-size-restrictions

- [ ] **Index creation > 20 minutes in the migration-testing CI job → async.** When the pipeline reports an index creation taking longer than 20 minutes, create the index asynchronously. The clone can underestimate production times, so this threshold is intentionally conservative.
  Source: `doc/development/migration_style_guide.md#how-long-a-migration-should-take` — https://docs.gitlab.com/development/migration_style_guide/#how-long-a-migration-should-take

- [ ] **Index > 10 minutes in Database Lab → post-migration.** (Author preparation rule; see 1.5.)
  Source: `doc/development/database_review.md#preparation-when-adding-migrations`

- [ ] **Async index/FK process is two MRs.** MR 1: post-deploy `prepare_async_index` (or `prepare_partitioned_async_index`, `prepare_async_index_removal`, `prepare_async_foreign_key_validation`) with a follow-up issue linked in a comment. Verify the async operation actually ran in production (the project's deploy-status tooling), allow for its schedule, and confirm on the replica that the resulting index is not `invalid`. MR 2: synchronous `add_concurrent_index` / `remove_concurrent_index_by_name` / `validate_foreign_key` plus the schema-dump change. Warning: if MR 2 deploys before the async op completes, the op runs synchronously. Local testing output of async removal must be in the MR description. No-op outside the hosted production environment.
  Source: `doc/development/database/adding_database_indexes.md#create-indexes-asynchronously` — https://docs.gitlab.com/development/database/adding_database_indexes/#create-indexes-asynchronously; `#drop-indexes-asynchronously`; `doc/development/database/foreign_keys.md#validate-the-foreign-key-asynchronously`

- [ ] **Index-count limit.** One large production project enforces a limit of **15 indexes** per table. If already at 15: remove unused indexes, combine existing indexes, or use a composite index. Wide or hot tables often carry linter rules that block further index or column additions (lock-manager contention). Tables with more than 16 indexes affect query planning.
  Source: `doc/development/database/adding_database_indexes.md#index-limitations` — https://docs.gitlab.com/development/database/adding_database_indexes/#index-limitations; `#some-tables-should-not-have-any-more-indexes`; `doc/development/database/layout_and_access_patterns.md#data-model-trade-offs`

- [ ] **High-traffic tables.** `with_lock_retries` is advised for migrations touching high-traffic tables (the project's linter config usually lists them; identified by read volume, record count, size over about 10 GB). Columns purely for analytics or reporting are discouraged on high-traffic tables. Triggers on high-traffic tables go in a post-deployment migration with `with_lock_retries`, idempotent (`replace: true`, `if_exists: true`).
  Source: `doc/development/migration_style_guide.md#high-traffic-tables` — https://docs.gitlab.com/development/migration_style_guide/#high-traffic-tables; `#creating-triggers`; `#when-to-use-the-helper-method`

- [ ] **Alternatives to widening a large table** were considered: separate `has_one` table, Elasticsearch, simplified filtering/sorting (e.g. `id` instead of `created_at`).
  Source: `doc/development/database/large_tables_limitations.md#alternatives-to-table-modifications` — https://docs.gitlab.com/development/database/large_tables_limitations/#alternatives-to-table-modifications; `#using-has_one-relationships`

- [ ] **`ANALYZE` in migrations** only in post-deployment migrations and not on large tables (ask in `#database` otherwise). Needed for expression indexes that must be used immediately by a BBM.
  Source: `doc/development/database/adding_database_indexes.md#analyzing-a-new-index-before-a-batched-background-migration` — https://docs.gitlab.com/development/database/adding_database_indexes/#analyzing-a-new-index-before-a-batched-background-migration

### 2.4 Timing and performance standards

- [ ] **Migration timing guidelines** (see section 4 for the verbatim table): regular `<= 3 minutes`, post-deploy `<= 10 minutes`, background `> 10 minutes`; all migrations for a single deploy shouldn't take longer than 1 hour in production. Durations are measured against production.
  Source: `doc/development/migration_style_guide.md#how-long-a-migration-should-take` — https://docs.gitlab.com/development/migration_style_guide/#how-long-a-migration-should-take

- [ ] **Transaction budget.** In a single transaction, cumulative query time executed in a migration needs to fit comfortably in 15 seconds — preferably much less than that — in production.
  Source: `doc/development/database_review.md#timing-and-performance-standards` — https://docs.gitlab.com/development/database_review/#timing-and-performance-standards

- [ ] **Query timing.** General guideline is for queries to come in below 100ms execution time. Full table in section 4: general `100ms`; queries in a migration `100ms`; concurrent operations in a migration `5min`; concurrent operations in a post migration `20min`; background migrations `1s`; Service Ping `1s`. Guidelines apply for both cold and warm cache.
  Source: `doc/development/database/query_performance.md#timing-guidelines-for-queries` — https://docs.gitlab.com/development/database/query_performance/#timing-guidelines-for-queries

- [ ] **Statement timeout.** a typical production `statement_timeout` is `15s`. Helpers such as `add_concurrent_index` disable it internally; raw SQL that may exceed 15s needs `disable_statement_timeout` (per-connection for `CREATE INDEX CONCURRENTLY`; per-transaction for `ALTER TABLE ... VALIDATE CONSTRAINT`) — rarely needed; consult DB reviewers/maintainers. Migrations connect directly to the primary, bypassing PgBouncer.
  Source: `doc/development/migration_style_guide.md#heavy-operations-in-a-single-transaction` — https://docs.gitlab.com/development/migration_style_guide/#heavy-operations-in-a-single-transaction; `#temporarily-turn-off-the-statement-timeout-limit`

- [ ] **Lock retries.** Transactional migrations have lock-retry enabled by default. Non-transactional migrations use `with_lock_retries` (cannot be used inside `change`; needs explicit `up`/`down`; RuboCop restricts contents — `add_concurrent_index` is not allowed inside). Worst case: 50 iterations over 40 minutes, then runs without `lock_timeout`; fails with statement timeout if a 40+ minute transaction holds the table. Acquire all needed locks up front or split the migration so only one lock is needed at a time.
  Source: `doc/development/migration_style_guide.md#retry-mechanism-when-acquiring-database-locks` — https://docs.gitlab.com/development/migration_style_guide/#retry-mechanism-when-acquiring-database-locks; `#usage-with-non-transactional-migrations`; `#how-the-helper-method-works`

- [ ] **One FK per transaction.** Only one foreign key should be created per transaction (needs `SHARE ROW EXCLUSIVE` on the referenced table). New table with two FKs = three migrations (table+indexes, FK 1, FK 2). Avoid `add_foreign_key`/`add_concurrent_foreign_key` more than once per migration file unless source and target tables are identical. Multiple FK removals: each in its own migration.
  Source: `doc/development/migration_style_guide.md#creating-a-new-table-when-we-have-two-foreign-keys` — https://docs.gitlab.com/development/migration_style_guide/#creating-a-new-table-when-we-have-two-foreign-keys; `doc/development/database/foreign_keys.md#adding-the-fk-constraint-not-valid`; `doc/development/migration_style_guide.md#dropping-a-database-table`

- [ ] **FK on existing column is multi-milestone.** (1) `N.M`: add `NOT VALID` FK (`add_concurrent_foreign_key ... validate: false`); (2) `N.M`: data migration to fix/clean up records — regular/post-deploy if within timing guidelines, otherwise BBM (data volume > 1000 records suggests BBM); MR gets `~data-deletion`; (3) validate — same milestone if data fix was regular/post-deploy; only after BBM is finalized otherwise. Consider 2-step validation (`prepare_async_foreign_key_validation`) for high-traffic and especially partitioned tables.
  Source: `doc/development/database/foreign_keys.md#on-an-existing-column` — https://docs.gitlab.com/development/database/foreign_keys/#on-an-existing-column; `#data-migration-to-fix-existing-records`; `doc/development/migration_style_guide.md#minimizing-lock-contention-with-2-step-foreign-key-validation`

- [ ] **`reverse_lock_order`.** `add_concurrent_foreign_key`, `add_concurrent_partitioned_foreign_key`, `remove_foreign_key_if_exists`, `remove_partitioned_foreign_key` default to `reverse_lock_order: true`; opt-out only for parent→child FKs (e.g. `merge_requests.latest_merge_request_diff_id`).
  Source: `doc/development/database/foreign_keys.md#reverse_lock_order` — https://docs.gitlab.com/development/database/foreign_keys/#reverse_lock_order

- [ ] **Concurrent index ops.** Populated tables require `add_concurrent_index` / `remove_concurrent_index` (name required for removal). Small table (empty or < `1,000` records): `remove_index` / `add_index` in a single-transaction migration is recommended. Partitioned tables: `add_concurrent_partitioned_index` / `remove_concurrent_partitioned_index_by_name`; only the parent index can be dropped; no async removal path for partitioned indexes. Disabling an index is not safe.
  Source: `doc/development/migration_style_guide.md#removing-indexes` — https://docs.gitlab.com/development/migration_style_guide/#removing-indexes; `doc/development/database/adding_database_indexes.md#indexes-for-partitioned-tables`; `#dropping-unused-indexes`

- [ ] **Avoid `change_column`** (re-defines whole column type). `change_column_default` is safe in a single transaction (metadata only) but requires the `SafelyChangeColumnDefault` two-release process.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#changing-column-constraints` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#changing-column-constraints; `#changing-column-defaults`; `doc/development/migration_style_guide.md#changing-the-column-default`

- [ ] **`update_column_in_batches` on a large table** is acceptable only when updating a small subset of rows, and only after validating on a staging environment with production-like data (or asking someone to).
  Source: `doc/development/migration_style_guide.md#updating-an-existing-column` — https://docs.gitlab.com/development/migration_style_guide/#updating-an-existing-column

- [ ] **Autovacuum wraparound.** Migration filename should include the complete table name(s) (e.g. `add_foreign_key_between_ci_builds_and_ci_job_artifacts`) so the PDM pipeline can halt on wraparound vacuum; omit the full name when the migration has no conflicting locks.
  Source: `doc/development/migration_style_guide.md#autovacuum-wraparound-protection` — https://docs.gitlab.com/development/migration_style_guide/#autovacuum-wraparound-protection

### 2.5 Migration placement and timing

- [ ] **Establish a time estimate for execution in production** (from the migration-testing CI job output).
  Source: `doc/development/database_review.md#migration-placement-and-timing` — https://docs.gitlab.com/development/database_review/#migration-placement-and-timing

- [ ] **Appropriate migration type.** Regular (`db/migrate`, runs before Canary; "no more than a few minutes"; exception: absolutely critical for app to operate, else feature flag + post-deploy). Post-deployment (`db/post_migrate`; run daily at release manager discretion; for non-critical schema changes or data migrations of at most a few minutes; clean-ups, non-critical indices on high-traffic tables, long-running non-critical indices). **Must always be regular, never post-deploy:** `create_table`, `add_column` to an existing table. Batched background (data only; must not change the schema). `NOT NULL` add → post-deploy; `NOT NULL` remove → regular. Removing a default for a non-nullable column → post-deploy (after adding with default in a regular migration).
  Source: `doc/development/migration_style_guide.md#choose-an-appropriate-migration-type` — https://docs.gitlab.com/development/migration_style_guide/#choose-an-appropriate-migration-type; `doc/development/database/post_deployment_migrations.md#use-cases`; `doc/development/database/avoiding_downtime_in_migrations.md#changing-column-constraints`; `doc/development/migration_style_guide.md#removing-the-column-default-for-non-nullable-columns`

- [ ] **Index placement.** Index to improve existing queries → post-deploy. Index for new/updated queries: if queries don't time out or breach timings without it → post-deploy, same MR as the code. If slow in production → two MRs (PDM first; code MR merges only after PDM confirmed executed via the release docs procedure) or one MR behind a feature flag. Application must not assume a PDM schema shipped in the same release for customer-operated deployments; a regular migration is acceptable only when very fast (new/very small table), otherwise at least two releases.
  Source: `doc/development/database/adding_database_indexes.md#migration-type-to-use` — https://docs.gitlab.com/development/database/adding_database_indexes/#migration-type-to-use; `#new-or-updated-queries-perform-slowly-on-gitlabcom`; `#new-or-updated-queries-might-be-slow-on-a-large-gitlab-instance`

- [ ] **Unique index on existing table.** Unless absolutely guaranteed tiny, multiple post-deploy migrations over multiple releases (remove/fix duplicates, then add index). A unique index cannot be introduced non-validated; use a partial unique index + application validation in the interim. All unique indexes need to be scoped to the tenant-partitioning key, if the project has one. `nulls_not_distinct: true` when NULLs must be unique.
  Source: `doc/development/database/adding_database_indexes.md#add-a-unique-index-acting-as-a-constraint-to-an-existing-table` — https://docs.gitlab.com/development/database/adding_database_indexes/#add-a-unique-index-acting-as-a-constraint-to-an-existing-table; `#unique-indexes-on-nullable-columns`

- [ ] **Data migrations reversible or commented.** Data migrations should be reversible or should come with a comment on why it's no-oped or non-reversible. This applies to all types of migrations (regular, post-deploy, background migrations).
  Source: `doc/development/database_review.md#migration-placement-and-timing`

- [ ] **Multi-database.** Where the app connects to more than one database, check the migration declares which one it targets, so it is not run against the wrong schema.
  Source: `doc/development/migration_style_guide.md#decide-which-database-to-target` — https://docs.gitlab.com/development/migration_style_guide/#decide-which-database-to-target

### 2.6 Background migration specifics

- [ ] **Time estimates.** Take note of the time estimates provided from the migration-testing job's comment (titled **Database Migrations (on the main database)** etc.) to make sure they adhere to the query performance guidelines (BBM query `1s`, cold cache). Formula: `interval * number of records / max batch size`. Estimates are affected by the optimization mechanism (batch size auto-tuned on last 20 jobs).
  Source: `doc/development/database_review.md#background-migration-specifics` — https://docs.gitlab.com/development/database_review/#background-migration-specifics; `doc/development/database/batched_background_migrations.md#calculate-overall-time-estimation-of-a-batched-background-migration`

- [ ] **When BBMs are used.** For data migrations exceeding post-deploy time limits; high-traffic tables; numerous single-row queries over a large dataset. Not for schema migrations.
  Source: `doc/development/database/batched_background_migrations.md#when-to-use-batched-background-migrations` — https://docs.gitlab.com/development/database/batched_background_migrations/#when-to-use-batched-background-migrations

- [ ] **Structure.** Class in the project's background-migration namespace and directory, subclass of its batched-job base class, defines `perform`, `operation_name`, `feature_category`; uses the generator (creates `db/post_migrate/..._queue_*.rb`, `spec/migrations/...`, `lib/...`, `spec/lib/...`, and a dictionary entry for the background migration). Cursor-based iteration (`cursor :id`) is the default/recommended strategy. Queued in a **post-deployment** migration via `queue_batched_background_migration`; job argument count must match `job_arguments`. `down` uses `delete_batched_background_migration`.
  Source: `doc/development/database/batched_background_migrations.md#how-batched-background-migrations-work` — https://docs.gitlab.com/development/database/batched_background_migrations/#how-batched-background-migrations-work; `#generate-a-batched-background-migration`; `#use-cursor-based-iteration-default`; `#enqueue-a-batched-background-migration`; `#use-job-arguments`

- [ ] **Idempotent and isolated.** Jobs must be idempotent (Sidekiq retries). Must not use application code (models in `app/models`, except `ApplicationRecord` classes); inline models use the correct `ApplicationRecord`/`Ci::ApplicationRecord` — `ActiveRecord::Base` and `ActiveRecord::Base.connection` are disallowed.
  Source: `doc/development/database/batched_background_migrations.md#idempotence` — https://docs.gitlab.com/development/database/batched_background_migrations/#idempotence; `#isolation`; `#access-data-for-multiple-databases`

- [ ] **Review batch sizes and queries.** Review queries (for example, make sure batch sizes are fine). Prefer updating a whole sub-batch in one query with a limit guard in a `MATERIALIZED` CTE (avoids plan flips); avoid `pluck` without limit and per-row `update!`. Do not silently rescue exceptions (re-raise).
  Source: `doc/development/database_review.md#background-migration-specifics`; `doc/development/database/batched_background_migrations.md#best-practices` — https://docs.gitlab.com/development/database/batched_background_migrations/#best-practices

- [ ] **`scope_to` only with a covering index.** Only when the scoped conditions are indexed and the batching query filters out no rows; the plan should show an index-only scan without additional filters. `Database/AvoidScopeTo` cop disabled with the supporting index definition in the comment. `scope_to` is ignored by `LooseIndexScanBatchingStrategy`/`distinct_each_batch`. Non-distinct batching columns need `batch_class_name: 'LooseIndexScanBatchingStrategy'`.
  Source: `doc/development/database/batched_background_migrations.md#apply-selection-using-scope_to` — https://docs.gitlab.com/development/database/batched_background_migrations/#apply-selection-using-scope_to; `#batch-over-non-distinct-columns`

- [ ] **Supporting index precedes the queue migration** (separate, earlier post-deploy migration; often `tmp_`).
  Source: `doc/development/database/batched_background_migrations.md#add-indexes-to-support-batched-background-migrations` — https://docs.gitlab.com/development/database/batched_background_migrations/#add-indexes-to-support-batched-background-migrations

- [ ] **`tables_to_check_for_vacuum`** set when the migration writes to a table other than the one it iterates. Throttling pauses for 10 minutes on: WAL archival queue threshold, active autovacuum on the tables (default on since 18.0), Patroni apdex below SLO, WAL rate threshold.
  Source: `doc/development/database/batched_background_migrations.md#configure-tables-to-check-for-vacuum` — https://docs.gitlab.com/development/database/batched_background_migrations/#configure-tables-to-check-for-vacuum; `#throttling-batched-migrations`

- [ ] **Do not depend on BBM data until finalized.** Finalize with `ensure_batched_background_migration_is_finished` only after the BBM is completed in production and was added in or before the last required stop; arguments and target schema must exactly match the enqueue (even if the table's schema has since changed); update `finalized_by` in the dictionary; early finalization raises unless `skip_early_finalization_validation: true`. Dependent migrations declare `DEPENDENT_BATCHED_BACKGROUND_MIGRATIONS` (checked by `Migration::UnfinishedDependencies`). Cleanup (e.g. dropping the migrated column) only in a later major/minor release, never a patch release.
  Source: `doc/development/database/batched_background_migrations.md#finalize-a-batched-background-migration` — https://docs.gitlab.com/development/database/batched_background_migrations/#finalize-a-batched-background-migration; `#depending-on-migrated-data`; `#establish-dependencies`; `#cleaning-up-a-batched-background-migration`

- [ ] **Re-queue / stop.** Re-queue: no-op the original `up`/`down`, new PDM that calls `delete_batched_background_migration` first, update dictionary (`milestone`, `queued_migration_version`), clear `finalized_by` if previously finalized. Stop: no-op scheduling migration, PDM deleting the BBM, delete class + specs (single MR).
  Source: `doc/development/database/batched_background_migrations.md#re-queue-batched-background-migrations` — https://docs.gitlab.com/development/database/batched_background_migrations/#re-queue-batched-background-migrations; `#stop-and-remove-batched-background-migrations`

- [ ] **Tests required** for the queueing migration, the BBM itself, and the cleanup migration (use `spy` doubles with `have_received`).
  Source: `doc/development/database/batched_background_migrations.md#testing` — https://docs.gitlab.com/development/database/batched_background_migrations/#testing

- [ ] **Upgrade notes** required when the migration operates on large tables, exposes configuration for scope, or has dependencies. Release-post announcement if part of an important upgrade. A licensed-tier-only background migration needs a matching empty class on the base side, if the project separates the two.
  Source: `doc/development/database/batched_background_migrations.md#writing-upgrade-notes-for-customers` — https://docs.gitlab.com/development/database/batched_background_migrations/#writing-upgrade-notes-for-customers; `#notes`; `#batched-background-migrations-for-ee-only-features`

- [ ] **Partitioned parallelization patterns** (per-partition or view-based) apply to the hosted environment only, not to customer-operated ones; require Database team consultation.
  Source: `doc/development/database/batched_background_migrations.md#partitioned-tables` — https://docs.gitlab.com/development/database/batched_background_migrations/#partitioned-tables

### 2.7 New table and column reviews

- [ ] **Relational modeling and design choices** reviewed; access patterns and data layout considered (see section 5).
  Source: `doc/development/database_review.md#new-table-and-column-reviews` — https://docs.gitlab.com/development/database_review/#new-table-and-column-reviews

- [ ] **Stated access patterns and volume are reasonable**; assumptions sound; patterns don't pose stability risks.
  Source: same.

- [ ] **Columns ordered to conserve space.**
  Source: `doc/development/database/ordering_table_columns.md`

- [ ] **Foreign keys for references to other tables**, with indexes.
  Source: `doc/development/database_review.md#new-table-and-column-reviews`; `doc/development/database/foreign_keys.md`

- [ ] **Fixture in `db/fixtures/development/`** for every new table; no static data in tables (fixed items model instead).
  Source: `doc/development/database_review.md#preparation-when-adding-tables`

- [ ] **Empty new table may use blocking `add_index`** in a single-transaction migration. New table referencing one table: `t.references ... foreign_key: true`. Two FKs: split into three migrations.
  Source: `doc/development/migration_style_guide.md#atomicity-and-transaction`; `doc/development/database/foreign_keys.md#on-a-new-table`

- [ ] **`has_one` tables may drop `id`** and use the parent's ID as PK (`id: false`, `t.references ..., primary_key: true, default: nil, index: false`); consider Service Ping batch counting impact.
  Source: `doc/development/database/foreign_keys.md#alternative-primary-keys-with-has_one-associations` — https://docs.gitlab.com/development/database/foreign_keys/#alternative-primary-keys-with-has_one-associations

- [ ] **Column removals: column was ignored in a previous release.**
  Source: `doc/development/database_review.md#new-table-and-column-reviews`; `doc/development/database/avoiding_downtime_in_migrations.md#dropping-columns`

- [ ] **New column with default** uses standard `add_column` (PostgreSQL 11+). Adding a column to a wide table: consider splitting to a new one-to-one table if the new columns are accessed by themselves.
  Source: `doc/development/migration_style_guide.md#adding-columns-with-default-values`; `doc/development/database/layout_and_access_patterns.md#wide-tables`

### 2.8 Query performance analysis

- [ ] **Overly complex queries** and any the author points out are reviewed.
  Source: `doc/development/database_review.md#query-performance-analysis` — https://docs.gitlab.com/development/database_review/#query-performance-analysis

- [ ] **Every new/modified query has SQL + Database Lab plan** in the MR description.
  Source: same.

- [ ] **Parameters reflect data distribution** (the representative ids described in section 3).
  Source: same.

- [ ] **Plans checked and improvements suggested** (restructure query, add/remove indexes). Open questions go to `#database_maintainers`.
  Source: same.

- [ ] **N+1 avoided; query count minimized.**
  Source: same.

- [ ] **Index necessity justified.** Do new queries re-use existing indexes? Is there enough data that an index beats iterating rows? Is maintenance overhead worth it? An index may not be required if the table is small (less than `1,000` records) and not expected to grow exponentially, existing indexes filter enough rows, or the timing reduction is not significant. Partial indexes preferred for selective conditions. Index and application code should ship in the same MR if possible.
  Source: `doc/development/database/adding_database_indexes.md` — https://docs.gitlab.com/development/database/adding_database_indexes/; `#partial-indexes`; `#maintenance-overhead`; `#add-index-and-make-application-code-change-together-if-possible`

- [ ] **Filtered list views/APIs.** Not every filter/sort combination can be made performant; accept timeouts for some combinations rather than adding too many indexes.
  Source: `doc/development/database/query_performance.md#slow-list-views-and-apis` — https://docs.gitlab.com/development/database/query_performance/#slow-list-views-and-apis

- [ ] **Slow existing query.** If an existing query is not performing well, the author should make an effort to improve it; if too complex, a follow-up is created.
  Source: `doc/development/database/query_performance.md#timing-guidelines-for-queries`

### 2.9 Removals (columns, tables, indexes, FKs)

- [ ] **Dropping a column is three releases.** M: `ignore_column :col, remove_with: 'M+2', remove_after: '<date after M+1 release>'` in the model (on the licensed side only if the model itself is licensed-only), remove all code references including validations; views referencing the column also get `ignore_columns`. M+1: post-deployment migration `remove_column` — transactional if no indexes/constraints belong to the column; otherwise `disable_ddl_transaction!` with `add_column(..., if_not_exists: true)` + `add_concurrent_index` in `down`; if referenced by a view, recreate the view without the column first (reverse order in `down`). M+2: remove the ignore rule — only with the `remove_with` release and after `remove_after`. Ignoring and dropping must not happen in the same release.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#dropping-columns` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#dropping-columns

- [ ] **Renaming a column** (small tables only): regular migration `rename_column_concurrently` + ignore column (M), post-deploy `cleanup_concurrent_column_rename` (M), remove ignore (M+1). Large tables use BBMs over multiple milestones.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#renaming-columns` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#renaming-columns

- [ ] **Changing column type**: `change_column_type_concurrently` (regular) then `cleanup_concurrent_column_type_change` (post-deploy); large tables via background migration.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#changing-column-types` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#changing-column-types; `#changing-the-schema-for-large-tables`

- [ ] **Dropping a table.** No records and no FKs: `drop_table` in a regular migration. Records but no FKs: remove app code, then `drop_table` in a post-deploy migration. Has FKs: remove app code (release M); in release M+1, remove each FK in its own post-deployment migration with `with_lock_retries` (FK to a high-traffic table takes `ACCESS EXCLUSIVE`; `remove_foreign_key_if_exists` defaults to `reverse_lock_order: true`), then `drop_table` in another post-deploy migration. Move dictionary file to `db/docs/deleted_tables`.
  Source: `doc/development/migration_style_guide.md#dropping-a-database-table` — https://docs.gitlab.com/development/migration_style_guide/#dropping-a-database-table; `doc/development/database/avoiding_downtime_in_migrations.md#dropping-tables`; `#remove-foreign-keys-before-dropping-the-table`

- [ ] **Renaming a table** requires downtime unless the multi-release rename process is followed; if not in use yet, drop and recreate.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#renaming-tables` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#renaming-tables

- [ ] **Dropping an index.** Verify unused in the hosted environment **and** in customer-operated ones: metrics for `pg_stat_user_indexes_idx_scan` over at least the last 6 months; an unused-index report from the plan service (only counts since the stats were reset); the auto-explain artifact from the test suite, if the project produces one; query logs (usually a short retention window); manual codebase search; index origin history. For partitioned tables, all child indexes must be unused. Check composite index column order before assuming a replacement exists. Large tables: consider async drop. Automated unused-index cleanup proposals are proposals, not verdicts; the project usually keeps an explicit keep-list to opt individual indexes out.
  Source: `doc/development/database/adding_database_indexes.md#dropping-unused-indexes` — https://docs.gitlab.com/development/database/adding_database_indexes/#dropping-unused-indexes; `#verifying-that-an-index-is-unused`; `#composite-index-column-order`; `#automated-detection-and-removal`

- [ ] **Removing a FK.** Post-deployment migration, particularly for large tables; `with_lock_retries`; deadlock avoidance by locking `parent,child` order (or `reverse_lock_order`); partitioned tables use `remove_partitioned_foreign_key`. Replacing a FK (e.g. `CASCADE`→`SET NULL`): add new FK first, then remove old — PostgreSQL honors the most recent so protection is never lost.
  Source: `doc/development/migration_style_guide.md#removing-a-foreign-key-constraint` — https://docs.gitlab.com/development/migration_style_guide/#removing-a-foreign-key-constraint; `doc/development/database/foreign_keys.md#removing-foreign-keys`; `#updating-foreign-keys-in-migrations`

- [ ] **Dropping a sequence** via `drop_sequence`; `add_sequence` only allowed in `down` for FK columns. Truncate via `truncate_tables!`. Swapping PK via `swap_primary_key` with the new index created beforehand in a separate migration.
  Source: `doc/development/migration_style_guide.md#dropping-a-sequence` — https://docs.gitlab.com/development/migration_style_guide/#dropping-a-sequence; `#truncate-a-table`; `#swapping-primary-key`

- [ ] **`integer` → `bigint` PK conversion** follows the N / N+1 / N+2 / N+3 process (`initialize_conversion_of_integer_to_bigint`, `backfill_conversion_of_integer_to_bigint`, `ensure_backfill_conversion_of_integer_to_bigint_is_finished`, swap, `cleanup_conversion_of_integer_to_bigint`, remove ignores). Do not edit `db/integer_ids_not_yet_initialized_to_bigint.yml` manually; do not push `structure.sql` changes for the bigint columns. Remove temporary FKs before temporary indexes, each FK removal in its own migration.
  Source: `doc/development/database/avoiding_downtime_in_migrations.md#migrating-integer-primary-keys-to-bigint` — https://docs.gitlab.com/development/database/avoiding_downtime_in_migrations/#migrating-integer-primary-keys-to-bigint

---

## 3. Query plans

### 3.1 What the author must provide

**Raw SQL** (`database_review.md#raw-sql` — https://docs.gitlab.com/development/database_review/#raw-sql):

- Write the raw SQL in the MR description. Preferably formatted nicely with pgFormatter or paste.depesz.com and using regular quotes (for example, `"projects"."id"`) and avoiding smart quotes.
- In case of queries generated dynamically by using parameters, there should be one raw SQL query for each variation. No need to exhaustively add all permutations: the one with all parameters included and one for each type of query generated (e.g. versions without the optional `GROUP BY` and with fewer joins, keeping the appropriate filters for the remaining tables).
- If a query is always used with a limit and an offset, those should always be included with the maximum allowed limit used and a non 0 offset.
- Tips for finding the actual SQL: performance bar `pg` section; `log/development.log` (excludes Sidekiq); `ActiveRecord::Base.logger = Logger.new($stdout)` in specs — correct only in integration tests.

**Query plans** (`database_review.md#query-plans` — https://docs.gitlab.com/development/database_review/#query-plans):

- The query plan for each raw SQL query, with the link to the plan following each raw SQL snippet.
- Provide a link to the plan generated using the `explain` command in the postgres.ai chatbot. The `explain` command runs `EXPLAIN ANALYZE` (Database Lab runs `explain (analyze, buffers)` and returns a shareable console report).
  - If it's not possible to get an accurate picture in Database Lab, seed a development environment and provide `EXPLAIN ANALYZE` output via explain.depesz.com or explain.dalibo.com — paste both the plan and the query.
- **The plan must hit enough data.** Use the ids of the largest real records of each kind the query touches — the biggest tenant/group, the biggest project or account, a user with a long history. The upstream docs name specific production ids for this; **the profile names the equivalents for the project under review**, and the review says which ids were used.
  - No query plan should return 0 records or fewer records than the provided limit (if a limit is included). If a query is used in batching, a proper example batch with adequate included results should be identified and provided.
- **`UPDATE` always returns 0 records.** To identify the rows it updates, check the lines below the `ModifyTable` node: the row count on the child `-> Index Scan` (e.g. `rows=1`) shows how many rows were updated.
- New feature with no production data: analyze from a local environment, or use postgres.ai `exec` to update data (`exec UPDATE issues SET ...`) and create tables/columns (`exec ALTER TABLE issues ADD COLUMN ...`).
- **Changed queries: provide both old and new SQL and plans**, to spot differences quickly. Include data showing the performance improvement, preferably a benchmark.
- Evaluate the **final** query executed against the database, not intermediate `ActiveRecord::Relation`s; plans depend on all final parameters including limits. Check `log/development.log` to be sure.
- Data migrations: include relevant plan data showing the query works as expected, such as the approximate number of records modified or deleted.

**Database Lab mechanics** (`database/database_lab.md` — https://docs.gitlab.com/development/database/database_lab/):

- Console: the plan service's web UI (the profile names it and how to sign in). Pick the clone matching the database the table lives in — a multi-database app has one clone per database, and the same index name can exist in more than one.
- `explain <query>` → plan + link. `exec <DDL or DML>` → runs the statement and returns only the execution time (this is how index-creation timing for the MR description is obtained; also `exec ANALYZE <table>`, `exec SET max_parallel_workers_per_gather = 0`). `reset` → fresh clone. `\d <index_name>` → index status; `invalid` suffix means the index is invalid; missing index → `Did not find any relation` error.
- CLI: the plan service usually ships a CLI that takes a SQL string and a project/clone name, with a short default wait budget and a follow-up command to fetch the result by id. The profile records the exact invocation.
- Snapshot roughly every 4 hours; Database Lab has a delay of a few hours. Clones are removed after 12 hours. `psql` access requires `AllFeaturesUser` + an access request.
- Guarantees a structurally identical plan and the same overall buffer count as production, but cache state and I/O speed may differ, so timings differ.

Source: `doc/development/database/understanding_explain_plans.md#database-lab-engine` — https://docs.gitlab.com/development/database/understanding_explain_plans/#database-lab-engine; `#tips-and-tricks`

### 3.2 Reviewer's method for reading a plan

Source: `doc/development/database/understanding_explain_plans.md` — https://docs.gitlab.com/development/database/understanding_explain_plans/ (anchors noted inline); `doc/development/database/query_performance.md#cold-and-warm-cache`.

1. **Confirm it is `EXPLAIN (ANALYZE, BUFFERS)`**, not plain `EXPLAIN` (estimates only). Database Lab includes both automatically. Writing queries should be wrapped in `BEGIN; ... ROLLBACK;` when run manually. (`#understanding-explain-plans` intro)
2. **Read nodes inside-out.** Innermost node executes first; `->` marks each node; `Filter:` is applied to that node's output. (`#nodes`)
3. **Node statistics.** `cost=STARTUP..TOTAL` (arbitrary units); `rows=` estimated vs `actual ... rows=` — compare estimated vs actual to spot mis-estimates; `width` in bytes; `loops=`. Actual time and actual rows are **per-loop averages**; buffers (`shared hit/read/dirtied/written`) and I/O read/write time are **totals**. Multiply per-loop values by `loops` (e.g. `rows=1 loops=888` = 888 rows; `0.025ms * 888` = 22.2ms). Each buffer is 8 KB; `208846` buffers = 1.6 GB. `Rows Removed by Filter` shows wasted work. (`#node-statistics`)
4. **Node types to recognize.** `Seq Scan` (avoid on large tables); `Index Only Scan` (check `Heap Fetches:`); `Index Scan`; `Bitmap Index Scan` + `Bitmap Heap Scan` (between seq and index); `Limit`; `Sort`; `Nested Loop` (child executed once per outer row — slow when children keep producing many rows). (`#node-types`)
5. **Cold vs warm cache.** Warm: only `shared hit`. Cold: `read` present (Database Lab: "reads: N from the OS file cache, including disk I/O"). Timing guidelines apply to both. For batched queries, vary range and batch size. (`query_performance.md#cold-and-warm-cache`)
6. **Compare on buffers, not only timing.** Timing is volatile (cache state); optimization means reducing buffers (read and hit); reduced timing follows. (`#optimizing-queries`)
7. **Before recommending an index**: check existing indexes (`\d table`), whether the query can reuse or slightly alter one; only add a new one if none can be used. A `Filter` on an index scan may mean the index is not partial enough. Selectivity matters — an index present does not guarantee use; a query returning 98% of a table cannot be indexed into speed and may need rewriting. (`#optimizing-queries`, `#queries-that-cant-be-optimized`, `#cardinality-and-selectivity`, `#rewriting-queries`)
8. **What makes a bad plan** (`#what-makes-a-bad-plan`): sequential scans on large tables; filters that remove a lot of rows; a step requiring *a lot* of buffers (for example, an index scan that requires more than 512 MB). Aim for a query that:
   1. Takes no more than 10 milliseconds (target time in SQL per request is around 100 milliseconds).
   2. Does not use an excessive number of buffers relative to the workload (retrieving ten rows shouldn't require 1 GB).
   3. Does not spend a long time in disk IO (`track_io_timing` must be enabled for this data).
   4. Applies a `LIMIT` when retrieving rows without aggregating them.
   5. Doesn't use a `Filter` to filter out too many rows, especially without `LIMIT`; filters can usually be removed by a (partial) index.
   These are guidelines; the only *rule* is you *must always measure* with `EXPLAIN (ANALYZE, BUFFERS)` on a production-like database.
9. **Planner mis-estimates on `IN (...)`** choosing a seq scan: see the LATERAL join rewrite. (`#further-reading`; `query_performance.md`)
10. **Rails console alternative:** `.explain(:analyze, :buffers, :verbose)`. (`#rails-console`)

---

## 4. Timing guidelines tables (verbatim)

### 4.1 Migration duration — `migration_style_guide.md#how-long-a-migration-should-take`

https://docs.gitlab.com/development/migration_style_guide/#how-long-a-migration-should-take

In general, all migrations for a single deploy shouldn't take longer than 1 hour in production. The following guidelines are not hard rules, they were estimated to keep migration duration to a minimum. All durations should be measured against production.

| Migration Type             | Recommended Duration | Notes |
|----------------------------|----------------------|-------|
| Regular migrations         | `<= 3 minutes`       | A valid exception are changes without which application functionality or performance would be severely degraded and which cannot be delayed. |
| Post-deployment migrations | `<= 10 minutes`      | A valid exception are schema changes, since they must not happen in background migrations. Concurrent operations such as index creation have a separate `20 minute` limit. |
| Background migrations      | `> 10 minutes`       | Since these are suitable for larger tables, it's not possible to set a precise timing guideline, however, any single query must stay below `1 second` execution time with cold caches. |

When the migration-testing CI job reports an index creation taking longer than 20 minutes, create the index asynchronously. The testing pipeline runs on a database clone that can underestimate actual production execution times, so this threshold is intentionally conservative.

### 4.2 Query timing — `database/query_performance.md#timing-guidelines-for-queries`

https://docs.gitlab.com/development/database/query_performance/#timing-guidelines-for-queries

| Query Type                                | Maximum Query Time | Notes |
|-------------------------------------------|--------------------|-------|
| General queries                           | `100ms`            | This is not a hard limit, but if a query is getting above it, it is important to spend time understanding why it can or cannot be optimized. |
| Queries in a migration                    | `100ms`            | This is different than the total migration time. |
| Concurrent operations in a migration      | `5min`             | Concurrent operations do not block the database, but they block the application update. This includes operations such as `add_concurrent_index`, `add_concurrent_foreign_key`, and validate constraint (for example, adding text limit via `add_text_limit`). |
| Concurrent operations in a post migration | `20min`            | Concurrent operations do not block the database, but they block the application's post-update process. This includes operations such as `add_concurrent_index`, `add_concurrent_foreign_key`, and validate constraint (for example, adding text limit via `add_text_limit`). If index creation exceeds 20 minutes, consider async index creation. |
| Background migrations                     | `1s`               | |
| Service Ping                              | `1s`               | See the Metrics Instrumentation docs for more details. |

### 4.3 Other numeric thresholds referenced by the review docs

| Threshold | Meaning | Source |
|---|---|---|
| 15 seconds | Cumulative query time in a single migration transaction must fit comfortably within this in production; also the production `statement_timeout` | `database_review.md#timing-and-performance-standards`; `migration_style_guide.md#heavy-operations-in-a-single-transaction` |
| 10 minutes | Database Lab `CREATE INDEX CONCURRENTLY` runtime above which the index moves to a post-migration | `database_review.md#preparation-when-adding-migrations` |
| 1h | Database Lab index execution time above which the index must be created asynchronously (+ maintainer notifies Release Managers) | `database_review.md#large-table-and-size-restrictions` |
| 20 minutes | the migration-testing CI job index creation time above which async creation is required | `migration_style_guide.md#how-long-a-migration-should-take` |
| 50 GB / 50 GB / 100 GB | Max table size after adding an index / FK column / column | `large_tables_limitations.md#table-size-restrictions` |
| 15 indexes | Per-table index limit | `adding_database_indexes.md#index-limitations` |
| 1,000 records | "Small table" — index may be unnecessary; `remove_index` acceptable in a transaction; >1000 invalid records suggests BBM for FK cleanup | `adding_database_indexes.md`; `migration_style_guide.md#removing-indexes`; `foreign_keys.md#data-migration-to-fix-existing-records` |
| 512 MB | Buffers for a single index scan considered "a lot" | `understanding_explain_plans.md#what-makes-a-bad-plan` |
| 10 ms / 100 ms | Per-query aim / per-request SQL target | `understanding_explain_plans.md#what-makes-a-bad-plan` |
| 64 KB | Recommended max `size_limit` for JSONB schema validation | `migration_style_guide.md#storing-json-in-database` |
| 3 weeks | Migration timestamp best-practice freshness | `migration_style_guide.md#migration-timestamp-age` |
| 50 retries / 40 minutes | `with_lock_retries` worst case | `migration_style_guide.md#how-the-helper-method-works` |
| 10 minutes | BBM pause duration on a throttling stop signal | `batched_background_migrations.md#throttling-batched-migrations` |
| 2 / 4 | Default / hosted-environment parallel BBMs | `batched_background_migrations.md#execution-mechanism` |
| 4 hours / 12 hours | Database Lab snapshot cadence / clone lifetime | `database_lab.md` |

---

## 5. New table review

### 5.1 Questions the author must answer in the MR description (verbatim)

- What is the anticipated growth for the new table over the next 3 months, 6 months, 1 year? What assumptions are these based on?
- How many reads and writes per hour would you expect this table to have in 3 months, 6 months, 1 year? Under what circumstances are rows updated? What assumptions are these based on?
- Based on the anticipated data volume and access patterns, does the new table pose an availability risk to the hosted service or customer-operated instances? Does the proposed design scale to support the needs of both hosted and customer-operated deployments?

Reviewer counterpart: Are the stated access patterns and volume reasonable? Do the assumptions they're based on seem sound? Do these patterns pose risks to stability?

Source: `doc/development/database_review.md#preparation-when-adding-tables`; `#new-table-and-column-reviews`

### 5.2 Access-pattern anti-patterns to check for

Source: `doc/development/database/layout_and_access_patterns.md` — https://docs.gitlab.com/development/database/layout_and_access_patterns/

- **High-frequency updates, especially to the same row.** Transactions queue on the row lock; connection pools saturate → application-wide downtime; each update creates a new row version → vacuum and WAL pressure. Typical cause: running tallies/aggregates. Alternative: running total in one row + small working set of increments (inserts don't contend), combine at read time, periodic job folds the working set in. (`#high-frequency-updates-especially-to-the-same-row`)
- **Wide tables.** 8 KB pages; narrower rows improve seq/bitmap scan, vacuum, and update performance (non-HOT updates touch every index). When adding columns, if the new columns are accessed by themselves in a one-to-one relationship, split to a new table (examples: `search_data` from `issues`, `project_pages_metadata` from `projects`, `merge_request_diff_details` from `merge_request_diffs`). (`#wide-tables`)
- **Data model trade-offs.** Central wide tables (`users`, `namespaces`, `projects`): > 16 indexes affects planning and may cause LWLock contention; updates copy every column (WAL); frequently-updated columns force whole-row copies. Extract very-frequently-updated (e.g. `last_activity_at`) or rarely-used (tokens, OTP, confirmation) columns into one-to-one tables. Trade-off: index-only scans lost; extra join/query. Extraction is a 5-release process (create + dual-read + backfill; finalize after required stop; read/write new only + ignore; drop; remove ignore). (`#data-model-trade-offs`, `#example`)

### 5.3 Column ordering and size classes

Source: `doc/development/database/ordering_table_columns.md` — https://docs.gitlab.com/development/database/ordering_table_columns/

Rule: columns of new tables are ordered to use the least amount of space — type size in descending order, variable-size types at the end. Do **not** reorder columns of existing tables in `structure.sql`.

| Type | Size | Alignment needed |
|:---|:---|:---|
| `smallint` | 2 bytes | 1 word |
| `integer` | 4 bytes | 1 word |
| `bigint` | 8 bytes | 8 bytes |
| `real` | 4 bytes | 1 word |
| `double precision` | 8 bytes | 8 bytes |
| `boolean` | 1 byte | not needed |
| `text` / `string` | variable, 1 byte plus the data | 1 word |
| `bytea` | variable, 1 or 4 bytes plus the data | 1 word |
| `timestamp` | 8 bytes | 8 bytes |
| `timestamptz` | 8 bytes | 8 bytes |
| `date` | 4 bytes | 1 word |

Word = 8 bytes on 64-bit. Tuple header is 24 bytes. Variable-size columns always go last (may be stored externally with a 1-word pointer). Worked example: reordering `events` saves 8 bytes/row (48 → 40), ≈ 610 MB at 80,000,000 rows. Rails 5.1+ default ID type is `bigint`.

### 5.4 Table size classes (`db/docs` `table_size`)

`unknown`, `small` (< 10 GB), `medium` (< 50 GB), `large` (< 100 GB), `over_limit` (above 100 GB). Size includes indexes; for partitioned tables it is the largest partition. New tables are usually `small`; updated automatically monthly. `large`/`over_limit` tables get async index removals from housekeeper rather than direct drops.

Source: `doc/development/database/database_dictionary.md#schema` — https://docs.gitlab.com/development/database/database_dictionary/#adding-tables; `doc/development/database/adding_database_indexes.md#automated-detection-and-removal`

### 5.5 Size-reduction techniques to suggest

Archiving; retention/cleanup jobs; partitioning (date range, list); column optimization (`smallint`, `NULL` over empty strings/zeros, `text` over `varchar`, remove redundant indexes); normalization (`has_one` split, junction tables, vertical partitioning); external storage (object storage, Elasticsearch, Redis). Goal: all tables under 100 GB.

Source: `doc/development/database/large_tables_limitations.md#techniques-to-reduce-table-size` — https://docs.gitlab.com/development/database/large_tables_limitations/#techniques-to-reduce-table-size

---

## 6. Ready-to-use questions for the author

Each question is derived from a statement in the docs that the reviewer should verify with the author; the source is noted in brackets.

**Artifacts and process**
1. The MR description is missing raw SQL and/or Database Lab plan links for the new or changed queries — can you add them (one per query variation, plan link directly after each SQL snippet)? If not, I'll reassign the MR back to you per process. [`database_review.md#required`, `#roles-and-process`]
2. For the changed query, can you provide the raw SQL and plan for both the old and the new version? [`database_review.md#queries`]
3. Is this the final executed SQL (with limits, offsets, pagination, scopes), e.g. from `log/development.log` or the performance bar, rather than an intermediate relation? [`database_review.md#query-plans`, `#tips-for-finding-the-sql-executed-by-the-application`]
4. Have you run the project's migration-testing CI job? Can you link the results and comment on migration runtimes and any warnings? [`database_review.md#preparation-when-adding-migrations`]
5. `db:check-migrations` / `db:check-schema` are failing — is this one of the known false positives (column reordering after rollback, `pg_dump` ordering), or does the branch need a rebase? [`dbcheck-migrations-job.md#troubleshooting`]
6. Which database does this migration target, and does it declare that target so it is not run against the wrong schema? [`migration_style_guide.md#decide-which-database-to-target`]

**Query plans and data**
7. The plan returns 0 rows (or fewer than the `LIMIT`) — can you regenerate it against representative data (`namespace_id = 9970`, `project_id = 13083` or `278964`, `project_namespace_id = 15846663`/`15846626`, `user_id = 1614863`) or a proper example batch? [`database_review.md#query-plans`]
8. This feature has no production data yet — did you use `exec` in postgres.ai to seed/alter the clone, or a local environment, and is the plan representative? [`database_review.md#query-plans`]
9. Is this plan warm- or cold-cache (does it show `shared read`)? Have you checked the timing under both? [`query_performance.md#cold-and-warm-cache`]
10. For the batched query, how does timing change as you vary the range and batch size? [`query_performance.md#timing-guidelines-for-queries`]
11. The plan shows a `Seq Scan` / large `Rows Removed by Filter` / high buffer count — what fraction of the table does this query select, and can an existing index be reused or slightly adjusted before adding a new one? [`understanding_explain_plans.md#optimizing-queries`, `#what-makes-a-bad-plan`]
12. For the `UPDATE`/`DELETE`, how many rows does the child `Index Scan` node show as affected, and does that match expectations? [`database_review.md#query-plans`]
13. The query exceeds 100ms (or 1s for a BBM / Service Ping) — why can or can't it be optimized, and if it's too complex, is there a follow-up issue? [`query_performance.md#timing-guidelines-for-queries`]
14. Can you include a benchmark or other data showing the performance improvement from the query change? [`database_review.md#query-plans`]
15. Does this introduce an N+1 or increase query count per request? [`database_review.md#query-performance-analysis`]
16. Which combinations of filter/sort options in this finder are expected to time out, and is that acceptable? [`query_performance.md#slow-list-views-and-apis`]

**Migrations — general**
17. What is the estimated execution time in production, and which migration type did you choose based on that (regular ≤ 3 min, post-deploy ≤ 10 min, BBM otherwise)? [`database_review.md#migration-placement-and-timing`; `migration_style_guide.md#how-long-a-migration-should-take`]
18. Is this schema change critical for the application to operate? If not, why is it a regular migration rather than post-deploy (and vice versa for `create_table`/`add_column`, which must be regular)? [`migration_style_guide.md#choose-an-appropriate-migration-type`]
19. How did you test reversibility? Can you add the comment describing that, and (for a non-reversible data migration) a `down` no-op with an explanation plus a description of how the data could be recovered in an incident? [`migration_style_guide.md#reversibility`; `database_review.md#preparation-when-adding-data-migrations`]
20. What is the user-facing impact if this data migration goes wrong (e.g. "Issues would go missing from Epics")? Roughly how many records are modified/deleted per the plan? Does the MR need `~data-deletion`? [`database_review.md#preparation-when-adding-data-migrations`]
21. Does the cumulative query time in this single-transaction migration fit comfortably within 15 seconds in production? [`database_review.md#timing-and-performance-standards`]
22. Why is `disable_ddl_transaction!` present/absent — is there a concurrent operation, `with_lock_retries`, batching, or a non-PostgreSQL/multi-database target that requires it? [`migration_style_guide.md#disable-transaction-wrapped-migration`]
23. This touches a high-traffic table — is `with_lock_retries` used, and are all locks acquired before DDL (or the migration split so only one lock is needed at a time)? [`migration_style_guide.md#when-to-use-the-helper-method`, `#transactional-migrations`]
24. This migration adds/removes more than one FK — can you split them into separate migrations? [`migration_style_guide.md#creating-a-new-table-when-we-have-two-foreign-keys`; `foreign_keys.md#adding-the-fk-constraint-not-valid`]
25. Why is this RuboCop cop disabled? For a large-table cop, can you link the approved `schema_change_exception` issue? [`database_review.md#preparation-when-adding-migrations`; `large_tables_limitations.md#requesting-an-exception`]
26. Is the migration timestamp after the last required stop and within ~3 weeks of expected merge? Is `milestone` set? [`migration_style_guide.md#migration-timestamp-age`, `#milestone`]
27. Do you need the full table name in the migration filename so the PDM pipeline can check for wraparound vacuum? [`migration_style_guide.md#autovacuum-wraparound-protection`]
28. Have you added a `spec/migrations` test (required for post-migrations, data migrations, and background migrations)? [`testing_migrations_guide.md#when-to-write-a-migration-test`]

**Indexes**
29. Is this index necessary — does the query reuse existing indexes, is the table > 1,000 rows or growing, and is the write overhead worth the read gain? [`adding_database_indexes.md`]
30. What was the `CREATE INDEX CONCURRENTLY` execution time in Database Lab? (> 10 min → post-migration; > 20 min in the testing pipeline or > 1h in Database Lab → async.) [`database_review.md#preparation-when-adding-migrations`, `#large-table-and-size-restrictions`; `migration_style_guide.md#how-long-a-migration-should-take`]
31. How many indexes does the table have now (limit 15)? Could an existing one be removed, combined, or made composite? [`adding_database_indexes.md#index-limitations`]
32. Would a partial index (`WHERE ...`) cover this query with a smaller footprint? [`adding_database_indexes.md#partial-indexes`]
33. This composite index makes `index(A, B)` / `index(A)` redundant — can you drop them in the same migration? [`database_review.md#preparation-when-removing-columns-tables-indexes-or-other-structures`]
34. Does this index have `where`/`using`/`order`/`length`/`type`/`opclass`? It then needs an explicit `name:`. [`adding_database_indexes.md#requirements-for-naming-indexes`]
35. For the temporary index: is it prefixed `tmp_`, is there a follow-up removal issue, and is it referenced in a migration comment? [`adding_database_indexes.md#temporary-indexes`]
36. For the async index: is the follow-up "Synchronous Database Index" issue created and linked in a comment? Is the `structure.sql` change deferred to the second MR? [`adding_database_indexes.md#schedule-the-index-to-be-created`; `migration_style_guide.md#schema-changes`]
37. Before dropping this index: what do the 6-month Grafana `pg_stat_user_indexes_idx_scan` stats show, which queries used it (auto-explain logs, Kibana, codebase search), can other indexes serve them given composite column order, and is it used on Self-Managed or by infrequent cron jobs? [`adding_database_indexes.md#verifying-that-an-index-is-unused`, `#composite-index-column-order`]
38. Is this index for the PDM shipped in the same MR as the code that needs it, or (if slow in production) in a separate first change request / behind a feature flag? Does the app work without it in the same release for customer-operated deployments? [`adding_database_indexes.md#add-an-index-to-support-new-or-updated-queries`]
39. Unique index on an existing table: have duplicates been removed/fixed first, across multiple post-deploy migrations and releases? Is it scoped to the tenant-partitioning key, if the project has one? [`adding_database_indexes.md#add-a-unique-index-acting-as-a-constraint-to-an-existing-table`]

**Foreign keys**
40. Is there an index whose leading column is the FK column, added before the FK? [`foreign_keys.md#indexes`]
41. What `ON DELETE` behavior is set, and if not `CASCADE`, why? [`foreign_keys.md#cascading-deletes`]
42. Is the new FK column `bigint`? [`foreign_keys.md#use-bigint-for-foreign-keys`]
43. For the FK on an existing column: is it added `NOT VALID` first, is there a data migration removing orphaned rows, and is validation deferred until after that (or after the BBM is finalized)? [`foreign_keys.md#on-an-existing-column`; `database_review.md#preparation-when-adding-foreign-keys-to-existing-tables`]
44. Can the `dependent: ...` option / `before_destroy`/`after_destroy` callbacks be removed now that the FK exists? Was any remaining use approved by a database specialist? [`database_review.md#preparation-when-adding-foreign-keys-to-existing-tables`; `foreign_keys.md#dependent-removals`]
45. The FK points parent→child — is `reverse_lock_order: false` warranted? [`foreign_keys.md#opting-out`]

**New tables and columns**
46. What is the anticipated growth at 3/6/12 months, reads and writes per hour, and update circumstances — and what assumptions underlie those numbers? [`database_review.md#preparation-when-adding-tables`]
47. Does the design pose an availability risk to the hosted service or to customer-operated deployments, and does it scale for both? [`database_review.md#preparation-when-adding-tables`]
48. Will any single row be updated by many transactions concurrently (running tallies, counters)? [`layout_and_access_patterns.md#high-frequency-updates-especially-to-the-same-row`]
49. Are the new columns accessed on their own in a one-to-one relationship — should they be a separate table instead of widening this one? [`layout_and_access_patterns.md#wide-tables`; `large_tables_limitations.md#using-has_one-relationships`]
50. Are columns ordered by descending type size with variable-size columns last? [`ordering_table_columns.md`]
51. Is there a development seed and a table-dictionary entry (target schema, owning feature category, milestone, expected size, tenant-partitioning key)? [`database_review.md#preparation-when-adding-tables`; `database_dictionary.md#adding-tables`]
52. Is this static data that belongs in a fixed items model rather than a table? [`database_review.md#preparation-when-adding-tables`]
53. Is this column purely for analytics or reporting on a high-traffic table? [`migration_style_guide.md#high-traffic-tables`]
54. Does the JSONB column have a `JsonSchemaValidator` with `size_limit` (64 KB recommended)? If the schema uses `additionalProperties: false`, is the property change split across deployments/releases? [`migration_style_guide.md#storing-json-in-database`; `avoiding_downtime_in_migrations.md#changing-jsonjsonb-columns-with-schema-validation`]
55. Do timestamps use the `_with_timezone` helpers? Is `integer` sufficient or is `limit: 8` needed? [`migration_style_guide.md#timestamp-column-type`, `#integer-column-type`]

**Removals and defaults**
56. Was this column ignored (`ignore_column ... remove_with:, remove_after:`) in a previous release, with all code references removed? Are `remove_with`/`remove_after` set to M+2 and a date after the M+1 release? Is any database view referencing it handled? [`avoiding_downtime_in_migrations.md#dropping-columns`]
57. The `down` re-adds an index/constraint — does the migration use `disable_ddl_transaction!` and `if_not_exists: true`? [`avoiding_downtime_in_migrations.md#the-removed-column-has-an-index-or-constraint-that-belongs-to-it`]
58. Dropping this table: has all application code been removed in a prior release, are FKs removed in separate post-deploy migrations first, and has the dictionary file moved to `deleted_tables` with `removed_by_url`/`removed_in_milestone`? [`avoiding_downtime_in_migrations.md#dropping-tables`; `migration_style_guide.md#dropping-a-database-table`; `database_dictionary.md#dropping-tables`]
59. Changing/removing this default: is `SafelyChangeColumnDefault` + `columns_changing_default` on the model, with cleanup scheduled for the next minor release? [`avoiding_downtime_in_migrations.md#changing-column-defaults`]
60. Removing a default for a non-nullable column: is that in a post-deploy migration after the add-with-default regular migration? [`migration_style_guide.md#removing-the-column-default-for-non-nullable-columns`]
61. Is this rename on a small table (otherwise BBM over multiple milestones), and do indexes containing the old column name exist that would break `rename_column_concurrently`? [`avoiding_downtime_in_migrations.md#renaming-columns`]

**Batched background migrations**
62. How much data is involved, what's the estimated total runtime (`interval * records / max batch size`), and have you discussed the numbers with a database specialist / measured on staging? [`batched_background_migrations.md#best-practices`, `#calculate-overall-time-estimation-of-a-batched-background-migration`]
63. Is every query in the job below 1 second with cold caches? [`migration_style_guide.md#how-long-a-migration-should-take`]
64. Is the job idempotent, and does it avoid application models (using inline `ApplicationRecord`/`Ci::ApplicationRecord` subclasses, never `ActiveRecord::Base`)? [`batched_background_migrations.md#idempotence`, `#isolation`, `#access-data-for-multiple-databases`]
65. If using `scope_to`, which index covers it, and does the plan show an index-only scan without filters? [`batched_background_migrations.md#apply-selection-using-scope_to`]
66. Is the batching column distinct (else `LooseIndexScanBatchingStrategy`), and is any supporting index created in an earlier post-deploy migration (with `ANALYZE` for expression indexes)? [`batched_background_migrations.md#batch-over-non-distinct-columns`, `#add-indexes-to-support-batched-background-migrations`]
67. Does the job write to a table other than the one it iterates — should `tables_to_check_for_vacuum` be set? [`batched_background_migrations.md#configure-tables-to-check-for-vacuum`]
68. Does the sub-batch update run as a single query with a limit guard in a `MATERIALIZED` CTE, and are exceptions re-raised rather than swallowed? [`batched_background_migrations.md#best-practices`]
69. How is newly created data handled during the migration (trigger, model/service, or dual writes)? [`batched_background_migrations.md#enqueue-a-batched-background-migration`, `#cleaning-up-a-batched-background-migration`]
70. Does any code in this MR depend on the migrated data before the BBM is finalized? Is `DEPENDENT_BATCHED_BACKGROUND_MIGRATIONS` declared where needed? [`batched_background_migrations.md#depending-on-migrated-data`, `#establish-dependencies`]
71. For the finalization: was the BBM added in or before the last required stop, is it complete in production, do arguments and target schema exactly match the enqueue, and is `finalized_by` updated in the dictionary? [`batched_background_migrations.md#finalize-a-batched-background-migration`]
72. Are tests present for the queue migration, the job, and the cleanup? Are upgrade notes needed (large table, config options, dependencies), and should the release post mention it? [`batched_background_migrations.md#testing`, `#writing-upgrade-notes-for-customers`, `#notes`]

---

# Applying the checklist in this skill

The sections above are the upstream project's public developer documentation, distilled.
This part is the skill's own guidance on using them in a review: what applies to the project
under review, the local checks a reviewer runs, and what to do when a production plan is not
available.

## Applicability to the project under review

The checklist above assumes a large Rails monolith with a dedicated database-review process:
a committed schema dump, per-migration checksum files, a table dictionary, a managed
query-plan service, and post-deploy migrations as a distinct type. **A smaller project has
some of that and not the rest.** The profile declares which, and each item the project does
not have is recorded as `n/a` with the reason — never skipped.

Worked example of how a profile narrows it (a project whose profile declares a single Rails
app, one deploy target with no release train, a committed schema dump, no checksum files, no
table dictionary, no managed plan service, and a read-only production replica reachable
through the profile's access path):

| Area | Upstream (as documented above) | How this profile narrows it |
|---|---|---|
| Migration reversibility, `down`, transaction vs `disable_ddl_transaction!` | as written | as written (the profile's rollback command) |
| Schema dump contains only this change's changes | as written | as written; the CI policy bot warns if the dump was not updated |
| Per-migration checksum files | required | `n/a` (the framework's default migrations table only) |
| Table dictionary file per table | required, same commit | `n/a`; a structured comment on the table or column (owner, data classification, description) is the equivalent record |
| Dedicated migration-testing CI jobs | required | `n/a`; the reviewer runs migrate / rollback / migrate locally and records timings |
| Managed query-plan service | required for every new or changed query | `n/a`; plans come from the production read-only replica (see profile), a staging replica as fallback with the caveat stated |
| Large-table size limits, index-count limit | as written | no formal limits; ask for the table's size and row count from the replica and apply the same reasoning |
| Timing table (regular ≤ 3 min, post-deploy ≤ 10 min, query < 100 ms, transaction < 15 s) | as written | use as the bar; with no post-deploy migration type, anything that would be post-deploy upstream needs a deliberate deploy plan and a question to the author |
| Batched background migrations | as written | `n/a`; long data changes run as a background job or task, reviewed under the "data migration" items |
| Column ordering, foreign-key indexes, `ON DELETE`, `bigint` foreign keys, timestamps with time zone, JSONB size limit | as written | as written |
| Dropping columns over three releases with `ignore_column` | as written | one deploy target, not a release train; still require the ignore-column deploy first, then the drop, because the running app must not reference a column mid-deploy |
| Query plans run against representative row ids | as written | pick the largest real record of each kind on the replica and say which |

Every `n/a` is recorded with the project's name and the reason in the Phase 4 table, not skipped.

## Local migration checks (Phase 3 step 3)

Run on the author's branch with the baseline snapshot already taken. The commands below are
the single-database Rails shape; the profile gives the project's own (a multi-database app
scopes each task to one database, and the schema dump may be named differently):

```sh
time bin/rails db:migrate                        # record wall time per migration from the output
git diff --stat db/schema.rb                     # only this change's tables/columns/indexes may appear
time bin/rails db:rollback STEP=<n>              # n = number of migrations the change adds
git diff --quiet db/schema.rb && echo "schema back to base"
bin/rails db:migrate                             # leave it migrated for Phase 5
```

Then, for each migration file, read it against § 2.1–2.5 above and answer: which lock does
each statement take, on which table, and for how long on production-sized data? Local
timing on a small dev database says nothing about that; it only proves the migration runs
and reverses. Say so in the record.

Lint the migration files with the project's linter. Some projects ship migration-specific
cops that encode many items above; where only generic rules run, the items must be checked
by reading. The profile says which.

## Query plans: what to demand and how to read one

1. For every new or changed query (including a new `scope`, a `where`/`joins` change, a
   finder change, a GraphQL resolver, a `update_all`/`delete_all`), the MR must show the
   final SQL and an `EXPLAIN (ANALYZE, BUFFERS)` from representative data. Changed query:
   old and new. Not present and the user is the DB reviewer: **blocking question**, drafted
   from § 6 items 1–3 and 7.
2. Read the plan with § 3.2. Record: node types on the large tables, estimated vs actual
   rows on the driving node, total buffers, whether it is warm or cold, and the timing
   against the § 4.2 table. Write the numbers in the record; the verdict follows from them.
3. The `database` subagent may be asked to read a plan and propose an index or rewrite.
   Its proposal is checked against § 2.8 (does an existing index already serve it, is the
   table over the index limit, is a partial index enough) before it becomes a suggestion.

## Simulating load locally

Use when a production plan cannot be obtained in time, or for a new table that has no
production data yet. The goal is a plan whose shape (node types, index choice) matches what
production would do, not identical timings.

1. **Agree the distribution with the author before generating anything.** Draft the
   questions from § 5.1 and § 6 items 46–49, plus these concrete ones, and queue them:
   - Which tables does the query touch, and roughly how many rows does each have in
     production today (replica: `select relname, n_live_tup from pg_stat_user_tables`)?
   - What is the cardinality of each filtered column (how many distinct values, how skewed;
     replica: `select <col>, count(*) from <t> group by 1 order by 2 desc limit 20`)?
   - What fraction of rows match the typical filter, and what does the worst realistic
     caller look like (the biggest customer, the oldest namespace)?
   - For a new table: expected rows at 3 / 6 / 12 months, writes per hour, update pattern.
2. **Generate to that shape, not to a round number.** A console script that inserts in
   batches with `insert_all`, using the agreed skew (e.g. 80% of rows on 5% of parents).
   Record the script under `artifacts/load/` and the resulting counts. Do not use
   FactoryBot for volume; it is too slow and fires callbacks.
3. **`ANALYZE` the tables**, then run `EXPLAIN (ANALYZE, BUFFERS)` for the query with the
   worst realistic parameters. Save the plan to `artifacts/load/<query>.plan`.
4. **State the limits of the simulation** in the record: skew guessed vs measured, size
   ratio to production, cache warm. A local plan can rule an approach *out* (a sequential
   scan on the big table at 1/10th scale will not become an index scan at full scale); it
   cannot rule it *in* on its own. If it looks fine, the finding is "no local red flags;
   production plan still required" unless the user, as DB reviewer, decides otherwise.
5. Everything generated is inside the baseline snapshot's scope and is removed in Phase 8
   by the restore.

## New tables: the load conversation is the review

For a new table, § 2.7 and § 5 are mostly questions rather than checks. Draft them all
(§ 6 items 46–55), send with the understanding-confirmation comment so the author answers
once, and hold the DB verdict until the answers are in. Meanwhile verify what can be
verified from the migration alone: column order (§ 5.3), FK + index + `ON DELETE`,
`bigint` FKs, timestamps with time zone, `NOT NULL` and limits on text columns, and any
equivalent table-documentation record the profile names.
