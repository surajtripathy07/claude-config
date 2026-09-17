#!/usr/bin/env bash
# PreToolUse backstop for the orchestrate skill. Main session only: subagents pass through.
# Denies (a) Read of a long file with no offset/limit, (b) direct Read/Grep/Glob past a
# per-session budget. Exit 0 with no output = allow. Tunables:
#   ORCHESTRATE_HOOK=off                    disable for this launch
#   ORCHESTRATE_MAX_DIRECT_READ_LINES=200   (a) in strict mode
#   ORCHESTRATE_INTERACTIVE_MAX_LINES=400   (a) in interactive mode; (b) is off there
#   ORCHESTRATE_DIRECT_READ_BUDGET=15       (b)
# Mode comes from ~/.claude/experiments/orchestrate.mode (bin/orchestrate-mode): strict
# (default) | interactive | off.
set -u
[ "${ORCHESTRATE_HOOK:-on}" = "off" ] && exit 0
mode="$(cat "$HOME/.claude/experiments/orchestrate.mode" 2>/dev/null || echo strict)"
[ "$mode" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0   # no jq: never block

input="$(cat)"
agent_id="$(printf '%s' "$input" | jq -r '.agent_id // empty')"
[ -n "$agent_id" ] && exit 0               # inside a subagent: allow everything

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
case "$tool" in Read|Grep|Glob) ;; *) exit 0 ;; esac

session="$(printf '%s' "$input" | jq -r '.session_id // "nosession"')"
max_lines="${ORCHESTRATE_MAX_DIRECT_READ_LINES:-200}"
[ "$mode" = "interactive" ] && max_lines="${ORCHESTRATE_INTERACTIVE_MAX_LINES:-400}"
budget="${ORCHESTRATE_DIRECT_READ_BUDGET:-15}"
counter="${TMPDIR:-/tmp}/orchestrate-${session}.count"

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# (a) long file, no window
if [ "$tool" = "Read" ]; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
  has_window="$(printf '%s' "$input" | jq -r '(.tool_input.offset // .tool_input.limit) // empty')"
  if [ -n "$path" ] && [ -z "$has_window" ] && [ -f "$path" ]; then
    lines="$(wc -l < "$path" 2>/dev/null | tr -d ' ')"
    if [ "${lines:-0}" -gt "$max_lines" ]; then
      deny "orchestrate[$mode]: $path is $lines lines (> $max_lines). Main session must not read it whole. Delegate to a scout agent (haiku) with a specific question, or pass offset/limit for a ≤${max_lines}-line window."
    fi
  fi
fi

# (b) budget — strict mode only
[ "$mode" = "interactive" ] && exit 0
n=0; [ -f "$counter" ] && n="$(cat "$counter" 2>/dev/null || echo 0)"
n=$((n + 1)); printf '%s' "$n" > "$counter"
if [ "$n" -gt "$budget" ]; then
  deny "orchestrate: direct $tool #$n exceeds the main-session budget of $budget. Delegate lookups to scout agents (haiku); the brain reads receipts, not files. For a tight interactive loop, tell the user and run: orchestrate-mode interactive. Set ORCHESTRATE_DIRECT_READ_BUDGET to change the budget."
fi
exit 0
