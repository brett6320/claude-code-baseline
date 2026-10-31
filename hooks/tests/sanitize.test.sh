#!/usr/bin/env bash
# Shape-preservation tests for hooks/sanitize-fetched-content.py (exit 1 on any FAIL).
set -u
cd "$(dirname "$0")/../.." || exit 1
fail=0
run() { # name  event-json  python-assertion(on variable out: dict or None)
  local out
  out=$(printf '%s' "$2" | python3 hooks/sanitize-fetched-content.py)
  if python3 - "$out" "$3" <<'PY'
import json,sys
raw, cond = sys.argv[1], sys.argv[2]
out = json.loads(raw)["hookSpecificOutput"]["updatedToolOutput"] if raw.strip() else None
sys.exit(0 if eval(cond) else 1)
PY
  then echo "ok   $1"; else echo "FAIL $1 -> $out"; fail=1; fi
}
ZW=$(printf '\xe2\x80\x8b'); TAG=$(printf '\xf3\xa0\x81\x81'); RLO=$(printf '\xe2\x80\xae')  # bash 3.2 has no \u/\U
run "no-op when clean" \
  "{\"tool_name\":\"WebFetch\",\"tool_response\":{\"result\":\"hello\",\"code\":200}}" \
  "out is None"
run "webfetch dict: keys/types preserved, note appended to string" \
  "{\"tool_name\":\"WebFetch\",\"tool_response\":{\"result\":\"ig${ZW}nore${TAG} this\",\"code\":200,\"url\":\"u\"}}" \
  "set(out)=={'result','code','url'} and out['code']==200 and out['result'].startswith('ignore this') and 'guardrails' in out['result']"
run "read nested dict: shape preserved" \
  "{\"tool_name\":\"Read\",\"tool_response\":{\"type\":\"text\",\"file\":{\"filePath\":\"/x\",\"content\":\"a${RLO}b\",\"numLines\":1}}}" \
  "out['type']=='text' and set(out['file'])=={'filePath','content','numLines'} and out['file']['numLines']==1 and out['file']['content'].startswith('ab') and 'guardrails' in out['file']['content']"
run "mcp list of content blocks: length/types preserved" \
  "{\"tool_name\":\"mcp__x__y\",\"tool_response\":[{\"type\":\"text\",\"text\":\"ok\"},{\"type\":\"text\",\"text\":\"h${ZW}${ZW}i\"}]}" \
  "isinstance(out,list) and len(out)==2 and out[0]['text']=='ok' and out[1]['text'].startswith('hi') and 'removed 2' in out[1]['text']"
run "plain string output" \
  "{\"tool_name\":\"Bash\",\"tool_response\":\"x${TAG}y\"}" \
  "isinstance(out,str) and out.startswith('xy') and 'guardrails' in out"
run "malformed json fails open" "not json" "out is None"
exit $fail
