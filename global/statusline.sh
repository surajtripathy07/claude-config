#!/usr/bin/env bash
# Claude Code status line: model · context used / window · session cost.
# Install: see README (settings.json "statusLine" block). Reads JSON on stdin.
input=$(cat)
python3 - "$input" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
model = (d.get("model") or {}).get("display_name") or (d.get("model") or {}).get("id") or "?"
cw = d.get("context_window") or {}
size = cw.get("context_window_size") or 200000
used = None
if cw.get("used_percentage") is not None:
    pct = float(cw["used_percentage"]); used = int(size * pct / 100)
else:
    cu = cw.get("current_usage") or {}
    used = int(cu.get("input_tokens", 0) + cu.get("cache_creation_input_tokens", 0) + cu.get("cache_read_input_tokens", 0))
    pct = used * 100.0 / size if size else 0
cost = (d.get("cost") or {}).get("total_cost_usd")
flag = "🟢" if used < 100_000 else ("🟡" if used < 150_000 else "🔴 HANDOFF")
line = f"{model} │ {flag} ctx {used/1000:.0f}k/{size/1000:.0f}k ({pct:.0f}%)"
if cost is not None: line += f" │ ${cost:.2f}"
print(line)
PY
