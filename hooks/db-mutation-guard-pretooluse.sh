#!/usr/bin/env bash
# PreToolUse (Bash): deny database-mutating commands (db:migrate, pg_restore, ...) unless
# run through `db-lock --`, so parallel worktree sessions can't corrupt or deadlock each
# other on the shared local Postgres. Only enforces the wrapper; db-lock does the waiting.
# rspec is not touched: test DBs are expected to be per worktree.
# Fails closed: without jq, any Bash call whose input matches a pattern is denied.
#   DB_GUARD_HOOK=off       disable for this launch
#   DB_GUARD_JQ=jq          jq binary (tests point it at a missing path)
#   DB_GUARD_PATTERNS=path  extra EREs, one per line, # comments
#                           (default: db-guard-patterns.local.txt next to this hook)
set -u
[ "${DB_GUARD_HOOK:-on}" = "off" ] && exit 0

pattern='db:(migrate|rollback|test:prepare|schema:load|drop|create|reset|setup|seed|structure:load|prepare)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_-])(pg_restore|dropdb|createdb)([^A-Za-z0-9_-]|$)'
extra="${DB_GUARD_PATTERNS:-$(dirname "$0")/db-guard-patterns.local.txt}"
if [ -r "$extra" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    pattern="$pattern|$line"
  done < "$extra"
fi
# Read-only task that the db:migrate prefix would otherwise catch.
readonly_tasks='db:migrate:status'
fix='prefix with db-lock -- (e.g. `db-lock -- bin/rails db:migrate`); it takes the per-repo DB lock shared by all worktrees. Set DB_LOCK_WAIT=<seconds> to wait for a peer instead of failing.'

deny_json() {
  local r="${1//\\/\\\\}"; r="${r//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$r"
  exit 0
}

input="$(cat)"
jq_bin="${DB_GUARD_JQ:-jq}"
if ! command -v "$jq_bin" >/dev/null 2>&1; then
  if printf '%s' "$input" | sed "s/$readonly_tasks//g" | grep -Eq "$pattern"; then
    deny_json "db-guard: jq is missing so this command cannot be parsed; it looks like a database mutation, so it is denied (fail closed). Install jq, or set DB_GUARD_HOOK=off for this launch."
  fi
  exit 0
fi

tool="$(printf '%s' "$input" | "$jq_bin" -r '.tool_name // empty')"
[ "$tool" = "Bash" ] || exit 0
cmd="$(printf '%s' "$input" | "$jq_bin" -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | sed "s/$readonly_tasks//g" | grep -Eq "$pattern" || exit 0

# Split on top-level ; & | and newlines only, so `db-lock -- sh -c 'a && b'` stays one
# segment owned by db-lock. Records are 0x1F-separated to survive embedded newlines.
segments() {
  awk -v sq="'" -v sep="$(printf '\037')" 'BEGIN { RS = "\001"; q = "" }
  {
    s = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (q != "") { s = s c; if (c == q) q = ""; else if (c == "\\" && q == "\"") { i++; s = s substr($0, i, 1) } continue }
      if (c == "\\") { s = s c substr($0, i + 1, 1); i++; continue }
      if (c == sq || c == "\"") { q = c; s = s c; continue }
      if (c == ";" || c == "&" || c == "|" || c == "\n") { printf "%s%s", s, sep; s = ""; continue }
      s = s c
    }
    printf "%s%s", s, sep
  }'
}

while IFS= read -r -d $'\037' seg; do
  printf '%s' "$seg" | sed "s/$readonly_tasks//g" | grep -Eq "$pattern" || continue
  # Strip leading whitespace, subshell parens, VAR=value assignments and `env`.
  lead="$(printf '%s' "$seg" | sed -E -e 's/^[[:space:](]*//' \
    -e ':a' -e 's/^(env[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)//' -e 'ta')"
  case "$lead" in
    db-lock[[:space:]]--[[:space:]]*|*/db-lock[[:space:]]--[[:space:]]*) continue ;;
  esac
  op="$(printf '%s' "$seg" | sed "s/$readonly_tasks//g" | grep -Eo "$pattern" | head -1 | sed -E 's/^[^A-Za-z]+//; s/[^A-Za-z0-9:_-]+$//')"
  deny_json "db-guard: \`$op\` mutates the shared local Postgres and is not run through db-lock. Fix: $fix"
done < <(printf '%s' "$cmd" | segments)
exit 0
