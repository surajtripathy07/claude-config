#!/usr/bin/env bash
# SubagentStop guard for the verifier agent: a receipt must carry a real EXIT per CMD and
# exactly one OVERALL line, and must not say PASS while any EXIT is non-zero.
# Blocks (sends the verifier back to work) once per agent_id; a second stop is let through
# with a loud "RECEIPT INVALID" systemMessage so the brain treats the run as FAIL.
# Fail closed: unparseable input or missing jq blocks once with "receipt unverifiable".
# Other agent types: exit 0, no output. Tunable: VERIFIER_GUARD=off disables.
# Also handles PreToolUse on the SubagentHandback tool (Claude Code >= 2.1.271): there the report
# is tool_input.message, and a deny makes Claude Code ask the subagent to re-deliver (up to 3 times).
set -u
[ "${VERIFIER_GUARD:-on}" = "off" ] && exit 0

input="$(cat)"
marker_dir="${TMPDIR:-/tmp}/verifier-guard"
have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=0

# Without jq the fields are scraped with sed; good enough to key the marker and gate on type.
field() {
  if [ "$have_jq" = 1 ]; then printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null
  else printf '%s' "$input" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

agent_type="$(field agent_type)"
case "$agent_type" in verifier|*:verifier) ;; *) exit 0 ;; esac
agent_id="$(field agent_id)"
agent_id="${agent_id//[^A-Za-z0-9_-]/_}"; agent_id="${agent_id:-unknown}"
marker="$marker_dir/$agent_id"

event="$(field hook_event_name)"
handback=0
[ "$event" = "PreToolUse" ] && [ "$(field tool_name)" = "SubagentHandback" ] && handback=1
[ "$event" = "PreToolUse" ] && [ "$handback" = 0 ] && exit 0
delivered="$marker_dir/$agent_id.delivered"
# A handback verifier's last_assistant_message is only closing text; its report was already judged at the tool call.
[ "$event" = "SubagentStop" ] && [ -e "$delivered" ] && exit 0

block() {
  mkdir -p "$marker_dir" 2>/dev/null
  if [ -e "$marker" ]; then
    printf 'verifier receipt still invalid on second stop (%s): RECEIPT INVALID - treat as FAIL\n' "$1" >&2
    if [ "$handback" = 1 ]; then
      : > "$delivered"
      printf '{"systemMessage":"RECEIPT INVALID — treat as FAIL (verifier %s: %s)","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"RECEIPT INVALID — treat as FAIL (verifier report: %s)"}}\n' "$agent_id" "$1" "$1"
    else
      printf '{"systemMessage":"RECEIPT INVALID — treat as FAIL (verifier %s: %s)"}\n' "$agent_id" "$1"
    fi
    exit 0
  fi
  : > "$marker"
  if [ "$handback" = 1 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Receipt rejected: %s. Call SubagentHandback again with the receipt: one block per command with CMD, EXIT <integer>, TAIL, VERDICT, then exactly one line OVERALL: PASS or OVERALL: FAIL. Re-run any command whose EXIT you lack. If out of turns, report OVERALL: FAIL (incomplete)."}}\n' "$1"
    exit 0
  fi
  printf '{"decision":"block","reason":"Receipt rejected: %s. Re-send the receipt: one block per command with CMD, EXIT <integer> (the command'"'"'s own exit code, never a pipe'"'"'s), TAIL, VERDICT, then exactly one line OVERALL: PASS or OVERALL: FAIL. Re-run any command whose EXIT you lack. If out of turns, report OVERALL: FAIL (incomplete)."}\n' "$1"
  exit 0
}

[ "$have_jq" = 1 ] || block "receipt unverifiable (jq missing)"

if [ "$handback" = 1 ]; then
  msg="$(printf '%s' "$input" | jq -r '.tool_input.message // empty' 2>/dev/null)" \
    || block "receipt unverifiable (input not JSON)"
else
  msg="$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)" \
    || block "receipt unverifiable (input not JSON)"
fi

# Transcript shape is not documented; observed (2.1.316): one JSONL line per content block, so the
# last assistant line can be a thinking block; read the last assistant line that has text.
if [ -z "$msg" ] && [ "$handback" = 0 ]; then
  tpath="$(field agent_transcript_path)"; tpath="${tpath/#\~/$HOME}"
  [ -n "$tpath" ] && [ -r "$tpath" ] && msg="$(jq -rs '
    [.[] | select((.message.role // .type) == "assistant")
         | (.message.content // []) | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end
         | select(. != null and . != "")] | last // empty
  ' "$tpath" 2>/dev/null)"
fi
[ -n "$msg" ] || block "receipt unverifiable (no final message)"

cmds="$(printf '%s\n' "$msg" | grep -cE '^[[:space:]]*CMD[[:space:]]')"
exits="$(printf '%s\n' "$msg" | grep -cE '^[[:space:]]*EXIT[[:space:]]+-?[0-9]+[[:space:]]*$')"
exit_lines="$(printf '%s\n' "$msg" | grep -cE '^[[:space:]]*EXIT([[:space:]]|$)')"
overall="$(printf '%s\n' "$msg" | grep -cE '^[[:space:]]*OVERALL:')"
overall_ok="$(printf '%s\n' "$msg" | grep -cE '^[[:space:]]*OVERALL:[[:space:]]*(PASS|FAIL)([[:space:]].*)?$')"
nonzero="$(printf '%s\n' "$msg" | grep -E '^[[:space:]]*EXIT[[:space:]]+-?[0-9]+[[:space:]]*$' | grep -cvE 'EXIT[[:space:]]+0[[:space:]]*$')"

[ "$cmds" -ge 1 ] || block "no CMD block"
[ "$exit_lines" -eq "$exits" ] || block "an EXIT line is not an integer"
[ "$exits" -ge "$cmds" ] || block "missing EXIT ($cmds CMD, $exits EXIT)"
[ "$overall" -eq 1 ] && [ "$overall_ok" -eq 1 ] || block "need exactly one 'OVERALL: PASS|FAIL' line (found $overall)"
if [ "$nonzero" -gt 0 ] && printf '%s\n' "$msg" | grep -qE '^[[:space:]]*OVERALL:[[:space:]]*PASS'; then
  block "contradiction: OVERALL: PASS with $nonzero non-zero EXIT"
fi
[ "$handback" = 1 ] && { mkdir -p "$marker_dir" 2>/dev/null; : > "$delivered"; }
exit 0
