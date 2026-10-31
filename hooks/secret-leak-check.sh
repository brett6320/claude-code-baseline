#!/usr/bin/env bash
# claude-code-baseline guardrails — PostToolUse enforcement.
# Source: github.com/brett6320/claude-code-baseline, policies/secrets.md
# (incident response: secret revealed/transmitted -> stop, advise rotation, require ROTATED).
set -euo pipefail

input="$(cat)"
combined="$(printf '%s' "$input" | jq -r '
  [.tool_response.stdout?, .tool_response.output?, .tool_response.content?, .tool_response.text?]
  | map(select(. != null))
  | join("\n")
' 2>/dev/null || true)"
[ -z "$combined" ] && exit 0

pattern='(-----BEGIN[ A-Z]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35})'

if printf '%s' "$combined" | grep -Eq "$pattern"; then
  printf '{"decision":"block","reason":"STOP: tool output appears to contain a live credential (secret-pattern match). Do not print, log, or reuse it further. Tell the user to rotate this credential now (do not restate its material). Do not resume work until the user replies the exact word ROTATED.","systemMessage":"Possible credential detected in tool output — work paused per secrets policy. Rotate the credential, then reply ROTATED to continue."}'
  exit 0
fi
exit 0
