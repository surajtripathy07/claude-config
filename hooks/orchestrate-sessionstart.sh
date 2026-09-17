#!/usr/bin/env bash
# SessionStart: label this session for the cost experiment so bin/session-cost can join
# transcripts with "was headroom on?" and "what mode?". Appends one TSV row.
set -u
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
session="$(printf '%s' "$input" | jq -r '.session_id // empty')"
[ -z "$session" ] && exit 0
dir="$HOME/.claude/experiments"; mkdir -p "$dir"
f="$dir/sessions.tsv"
[ -f "$f" ] || printf 'started_at\tsession_id\tcwd\tbase_url\theadroom\tlabel\n' > "$f"
base="${ANTHROPIC_BASE_URL:-}"
hr="off"; case "$base" in *8787*|*headroom*) hr="on" ;; esac
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session" "$(pwd)" "$base" "$hr" "${ORCHESTRATE_LABEL:-}" >> "$f"
exit 0
