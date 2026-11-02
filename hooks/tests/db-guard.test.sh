#!/usr/bin/env bash
# Tests for the db-guard hook and bin/db-lock.
# Uses only fake commands (sleep/echo/sh); never touches a real database.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
guard="$here/db-mutation-guard-pretooluse.sh"
dblock="$here/../bin/db-lock"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS  $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1${2:+ — $2}"; }

fixture() { jq -n --arg c "$1" '{session_id:"t",tool_name:"Bash",tool_input:{command:$c}}'; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null <<<"$1"; }

expect() { # expect <allow|deny> <command> [env...]
  local want="$1" cmd="$2"; shift 2
  local out; out="$(fixture "$cmd" | env "$@" "$guard")"; local rc=$?
  local got; got="$( [ -z "$out" ] && echo allow || decision "$out")"
  if [ "$rc" -eq 0 ] && [ "$got" = "$want" ]; then ok "guard $want (rc=$rc): $cmd"
  else bad "guard $want: $cmd" "got $got rc=$rc out=$out"; fi
  if [ "$want" = deny ] && [ -n "$out" ] && ! grep -q 'db-lock --' <<<"$out"; then
    bad "deny reason names fix: $cmd" "$out"
  fi
}

echo "== guard"
expect deny  'bin/rails db:migrate'
expect allow 'db-lock -- bin/rails db:migrate'
expect allow 'bundle exec rspec spec/x_spec.rb'
expect deny  'pg_restore -d foo x.dump'
expect deny  'cd /tmp && RAILS_ENV=test bundle exec rake db:test:prepare'
expect allow 'cd /tmp && RAILS_ENV=test db-lock -- bin/rails db:test:prepare'
expect allow "db-lock -- sh -c 'bin/rails db:migrate && bin/rails db:seed'"
expect deny  'db-lock -- echo hi && bin/rails db:migrate'
expect allow 'bin/rails db:migrate:status'
extra="$(mktemp)"; printf '# comment\n\nmytool[[:space:]]+wipe\n' > "$extra"
expect deny  'mytool wipe' DB_GUARD_PATTERNS="$extra"
expect allow 'db-lock -- mytool wipe' DB_GUARD_PATTERNS="$extra"
expect allow 'mytool wipe' DB_GUARD_PATTERNS=/nonexistent/patterns.txt
rm -f "$extra"
expect allow 'git log --oneline'
# jq missing: point the hook at a nonexistent jq (macOS ships /usr/bin/jq, so PATH tricks don't work).
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"bin/rails db:migrate"}}' | DB_GUARD_JQ=/nonexistent/jq "$guard")"; rc=$?
if [ "$rc" -eq 0 ] && grep -q '"permissionDecision":"deny"' <<<"$out"; then ok "guard deny without jq (rc=$rc)"; else bad "guard deny without jq" "rc=$rc $out"; fi
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | DB_GUARD_JQ=/nonexistent/jq "$guard")"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok "guard allow ls without jq (rc=$rc)"; else bad "guard allow ls without jq" "$out"; fi

echo "== db-lock"
root="$(mktemp -d)"; export DB_LOCK_ROOT="$root"
cd "$here"
"$dblock" -- sleep 3 & holder=$!
sleep 0.5
err="$("$dblock" -- echo hi 2>&1)"; rc=$?
if [ "$rc" -eq 75 ] && grep -q "pid=$holder" <<<"$err"; then ok "busy lock exits 75 naming holder pid=$holder"; else bad "busy lock" "rc=$rc $err"; fi
out="$(DB_LOCK_WAIT=5 "$dblock" -- echo hi 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = hi ]; then ok "DB_LOCK_WAIT=5 succeeds after holder exits (rc=$rc)"; else bad "wait" "rc=$rc $out"; fi
wait "$holder" 2>/dev/null
"$dblock" -- sleep 30 & holder=$!
sleep 0.5
orphan="$(pgrep -P "$holder")"
kill -9 "$holder"; wait "$holder" 2>/dev/null
out="$("$dblock" -- echo hi 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q 'recovered stale lock' <<<"$out" && grep -q '^hi$' <<<"$out"; then ok "stale lock after kill -9 recovered (rc=$rc)"; else bad "stale" "rc=$rc $out"; fi
"$dblock" -- sh -c 'exit 7'; rc=$?
if [ "$rc" -eq 7 ]; then ok "exit code propagated (rc=$rc)"; else bad "exit code" "rc=$rc"; fi
left="$(ls -A "$root")"
if [ -z "$left" ]; then ok "lock root empty after runs"; else bad "lock root not empty" "$left"; fi
[ -n "$orphan" ] && kill "$orphan" 2>/dev/null
rm -rf "$root"; unset DB_LOCK_ROOT

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
