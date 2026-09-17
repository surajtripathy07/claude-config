# Phase 0 § Baseline and Phase 8 — Leave the machine as it was found

A review checks out someone else's branch, migrates their schema, seeds data, flips flags,
and starts processes. All of that is undone at the end, and the undo is verified against a
baseline captured before anything was touched. "Restored" is a comparison, not a feeling.

## Baseline (Phase 0, before checking the branch out)

Write to the record's Setup section and to `artifacts/baseline/`:

```sh
B=~/.claude/reviews/<project>/<iid>/artifacts/baseline; mkdir -p "$B"
git rev-parse --abbrev-ref HEAD            > "$B/branch"      # e.g. main or my-feature
git rev-parse HEAD                         > "$B/head"
git status --porcelain                     > "$B/status"      # non-empty => dirty tree, STOP and ask
git stash list | wc -l                     > "$B/stash_count"
lsof -nP -iTCP -sTCP:LISTEN | awk 'NR>1{print $1, $9}' | sort -u > "$B/listeners"
```

Then, per the profile:

- **Database.** Preferred: a snapshot. `pg_dump -Fc <db> > "$B/<db>.dump"`. Record the
  current schema version too (`select max(version) from schema_migrations`). If the profile
  says the database is too large to dump in reasonable time, record the schema version and
  the row counts of every table the change's migrations or test steps will touch, and plan to
  restore by rollback plus targeted deletes.
- **Feature flags.** For every flag the diff reads (grep the diff for the profile's flag
  API), record its current local state the profile's way, verbatim, into `$B/flags/<name>`.
- **Running processes.** From `$B/listeners`, note which of the profile's app processes are
  already up (the web server, the asset server, the job runner, caches, datastores, and any
  local development-environment services). Whatever was up stays up at the end; whatever
  this review starts gets stopped.
- **Scratch files.** Anything the review creates outside `~/.claude/reviews/` is listed in
  `$B/created_files` as it is created (e.g. `Procfile.dev`, seed scripts, `.rspec-local`).

If `$B/status` is non-empty, stop and ask the user: stash (and I will pop it in Phase 8),
or abort until they commit. Never stash without the go.

## Restore (Phase 8), in this order

**Gate:** Phase 8 starts only on the user's explicit "we're done" / "revert". Before that,
the change request's branch stays checked out and migrated so the user can test or debug with me. Ask
once after posting; do not restore on your own initiative.

The order exists because each step needs something the next one removes.

1. **Stop what this review started.** Compare current listeners with `$B/listeners`. Kill
   only processes that were not there at baseline (by PID from `lsof`), and only the
   profile's known app processes. Close Chrome pages this review opened via the
   `chrome-devtools` MCP `close_page`.
2. **Roll back every migration this review applied while still on the change request's
   branch.** That is the change's own migrations plus any from its base that Phase 3 applied to make the app
   runnable (list in `artifacts/baseline/migrations_applied`). The rollback needs the
   migration files, which vanish when the branch is switched.
   Use the profile's migration rollback command, stepping back by the number of versions in
   that list. Verify the schema version (the profile's migration-status command) equals the
   baseline version, and that the profile's schema-diff command shows the checked-in schema
   file back at the baseline's dirty state (or clean).
3. **Restore the database.** If a snapshot exists:
   `dropdb <db> && createdb <db> && pg_restore -d <db> "$B/<db>.dump"` (the profile gives
   the exact connection flags). No snapshot: delete the records the reproduction created
   (the record's Phase 5 log lists every record created, by table and id) and re-verify
   the row counts captured at baseline. The rollback in step 2 already reverted the
   schema, so this step is about data.
4. **Feature flags** back to the captured state, using the profile's method. Verify by
   reading the state again and diffing against `$B/flags/<name>`.
5. **Remove scratch files** listed in `$B/created_files`. Look before deleting: if a file
   in that list was modified by someone else since, say so instead of deleting.
6. **Switch back.** `git switch <baseline branch>`; verify `git rev-parse HEAD` equals
   `$B/head`. Pop the stash only if one was taken in Phase 0 and only with the user's go;
   verify `git stash list | wc -l` equals `$B/stash_count`.
7. **Restart what was running at baseline** if step 1 or a migration restart brought it
   down (e.g. the web process needed a restart to pick up the branch). Verify listeners
   match `$B/listeners` for the profile's app ports.
8. **Delete the checked-out branch locally** only if it did not exist at baseline
   (`git branch --list <source_branch>` recorded in Phase 3) and the user has not said
   they want to keep it.

## Verification block (goes in the record, section 8)

| Item | Baseline | After | Status |
|---|---|---|---|
| branch | main @ abc123 | main @ abc123 | restored |
| working tree | clean | clean | restored |
| stash count | 0 | 0 | restored |
| schema version | 2026090112345 | 2026090112345 | restored |
| db rows: `<a table the change modifies>` | 1,204 | 1,204 | restored |
| flag allow_x (dev scope) | off | off | restored |
| listeners :5000 :3036 :6379 | up up up | up up up | restored |
| scratch files | none | none | restored |

Any row that is not `restored` reads `could not restore: <reason>` and the reason is
repeated in the final message to the user. A dirty tree the user chose to keep dirty is
recorded as `left as found (user's choice)`.
