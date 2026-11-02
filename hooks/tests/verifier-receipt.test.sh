#!/usr/bin/env bash
# Pipes fixture SubagentStop payloads into the hook and asserts allow/block/INVALID.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
hook="$here/../verifier-receipt-subagentstop.sh"
export TMPDIR; TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
fail=0

good=$'CMD         bundle exec rspec a\nEXIT        0\nTAIL        ok\nVERDICT     PASS - fine\n\nOVERALL: PASS (1 of 1 checks passed)'
no_exit=$'CMD         rspec a\nTAIL        ok\nVERDICT     PASS\n\nOVERALL: PASS'
no_overall=$'CMD         rspec a\nEXIT        0\nTAIL        ok\nVERDICT     PASS'
contradiction=$'CMD         rspec a\nEXIT        1\nTAIL        boom\nVERDICT     FAIL\n\nOVERALL: PASS'
incomplete=$'CMD         rspec a\nEXIT        1\nTAIL        boom\nVERDICT     FAIL\n\nOVERALL: FAIL (incomplete)'

payload() { jq -n --arg t "$1" --arg id "$2" --arg m "$3" '{hook_event_name:"SubagentStop",agent_type:$t,agent_id:$id,last_assistant_message:$m}'; }
check() { # name expected-substring-or-empty actual
  if [ -z "$2" ] && [ -z "$3" ]; then echo "PASS $1"
  elif [ -n "$2" ] && [[ "$3" == *"$2"* ]]; then echo "PASS $1"
  else echo "FAIL $1: expected '$2' got '$3'"; fail=1; fi
}

check "valid receipt allows"            ""                 "$(payload verifier a1 "$good" | "$hook" 2>&1)"
check "FAIL(incomplete) with EXIT allows" ""               "$(payload verifier a1b "$incomplete" | "$hook" 2>&1)"
check "missing EXIT blocks"             '"decision":"block"' "$(payload verifier a2 "$no_exit" | "$hook" 2>&1)"
check "missing OVERALL blocks"          '"decision":"block"' "$(payload verifier a3 "$no_overall" | "$hook" 2>&1)"
check "PASS with EXIT 1 blocks"         'contradiction'    "$(payload verifier a4 "$contradiction" | "$hook" 2>&1)"
payload verifier a5 "$no_overall" | "$hook" >/dev/null 2>&1
check "second stop allowed with INVALID" 'RECEIPT INVALID'  "$(payload verifier a5 "$no_overall" | "$hook" 2>&1)"
check "non-verifier allows"             ""                 "$(payload Explore a6 "$no_overall" | "$hook" 2>&1)"

# transcript fallback: empty last_assistant_message, receipt in the agent transcript JSONL
tr="$TMPDIR/agent-a7.jsonl"
{ jq -nc '{type:"user",message:{role:"user",content:"run it"}}'
  jq -nc --arg m "$good" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$m}]}}'; } > "$tr"
check "transcript fallback allows" "" "$(jq -n --arg p "$tr" '{agent_type:"verifier",agent_id:"a7",agent_transcript_path:$p}' | "$hook" 2>&1)"

# SubagentHandback: PreToolUse carries the report in tool_input.message
hb() { jq -n --arg t "$1" --arg id "$2" --arg m "$3" '{hook_event_name:"PreToolUse",tool_name:"SubagentHandback",agent_type:$t,agent_id:$id,tool_input:{message:$m},last_assistant_message:"done"}'; }
stop_after() { jq -n --arg id "$1" '{hook_event_name:"SubagentStop",agent_type:"verifier",agent_id:$id,last_assistant_message:"Report delivered."}'; }
check "handback valid allows"           ""                 "$(hb verifier h1 "$good" | "$hook" 2>&1)"
check "stop after valid handback allows" ""                "$(stop_after h1 | "$hook" 2>&1)"
check "handback invalid denies"         '"permissionDecision":"deny"' "$(hb verifier h2 "$no_exit" | "$hook" 2>&1)"
check "handback contradiction denies"   'contradiction'    "$(hb verifier h3 "$contradiction" | "$hook" 2>&1)"
hb verifier h4 "$no_overall" | "$hook" >/dev/null 2>&1
check "handback second try INVALID context" 'RECEIPT INVALID' "$(hb verifier h4 "$no_overall" | "$hook" 2>&1)"
check "stop after forced handback allows" ""               "$(stop_after h4 | "$hook" 2>&1)"
check "handback non-verifier allows"    ""                 "$(hb Explore h5 "$no_overall" | "$hook" 2>&1)"
check "other PreToolUse tool allows"    ""                 "$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Bash",agent_type:"verifier",agent_id:"h6",tool_input:{command:"ls"}}' | "$hook" 2>&1)"
check "stop without handback still blocks" '"decision":"block"' "$(stop_after h7 | "$hook" 2>&1)"

# transcript with a trailing thinking-only assistant line still yields the text receipt
tr2="$TMPDIR/agent-a9.jsonl"
{ jq -nc --arg m "$good" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$m}]}}'
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"thinking",thinking:"x"}]}}'; } > "$tr2"
check "transcript skips thinking-only tail" "" "$(jq -n --arg p "$tr2" '{agent_type:"verifier",agent_id:"a9",agent_transcript_path:$p}' | "$hook" 2>&1)"

# no jq on PATH: symlink only the tools the hook needs
bin="$TMPDIR/nojq"; mkdir -p "$bin"
for t in cat sed head grep mkdir printf tr; do ln -s "$(command -v $t)" "$bin/$t" 2>/dev/null; done
check "no jq blocks" 'receipt unverifiable' "$(payload verifier a8 "$good" | PATH="$bin" "$BASH" "$hook" 2>&1)"

exit $fail
