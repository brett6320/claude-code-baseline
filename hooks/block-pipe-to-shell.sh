#!/usr/bin/env sh
# PreToolUse hook — injection & egress hardening.
#
# Blocks the concrete moves a prompt-injection payload uses to turn "read/fetch"
# into "execute" or "exfiltrate":
#   1. pipe-to-shell            curl … | sh   |  wget … | bash   |  … | sudo sh
#   2. fetch-then-eval          eval "$(curl …)"   |  bash <(curl …)   |  source <(wget …)
#   3. blind remote exec        curl … | python  |  … | perl  |  … | node
#
# Deterministic backstop for policies 9 (safety) and 11 (threat-model): the model
# can be argued out of the prose rule under injection; a deny hook cannot.
#
# Contract: reads the PreToolUse event JSON on stdin. Exit 0 = allow, exit 2 = block
# (stderr is surfaced to the model as the denial reason). No jq dependency — matches
# the raw command text, which is sufficient for a fail-closed denylist.

payload=$(cat)

# Only inspect Bash tool calls; let everything else through untouched.
case "$payload" in
  *'"tool_name":"Bash"'*|*'"tool_name": "Bash"'*) : ;;
  *) exit 0 ;;
esac

# Normalize: strip escaped quotes/newlines so the regex sees a flat command line.
cmd=$(printf '%s' "$payload" | tr -d '\n' | sed 's/\\"/"/g; s/\\n/ /g')

# Pipe-to-shell / pipe-to-interpreter: <fetcher> … | … <shell|interpreter>
if printf '%s' "$cmd" | grep -Eqi '(curl|wget|fetch)[^|]*\|[^|]*(sudo[[:space:]]+)?(ba)?sh\b'; then
  printf 'BLOCKED: pipe-to-shell from a network fetch (curl|bash pattern). Download to a file, review it, then run it explicitly.\n' >&2
  exit 2
fi
if printf '%s' "$cmd" | grep -Eqi '(curl|wget|fetch)[^|]*\|[^|]*(python[0-9.]*|perl|ruby|node|php)\b'; then
  printf 'BLOCKED: piping a network fetch straight into an interpreter. Save, inspect, then run.\n' >&2
  exit 2
fi

# Process-substitution eval: bash <(curl …) / source <(wget …)
if printf '%s' "$cmd" | grep -Eqi '(source|\.|(ba)?sh|python[0-9.]*|node)[[:space:]]+<\([[:space:]]*(curl|wget|fetch)'; then
  printf 'BLOCKED: executing a process-substituted network fetch (bash <(curl …)). Save, inspect, then run.\n' >&2
  exit 2
fi

# eval of command-substituted fetch: eval "$(curl …)"
if printf '%s' "$cmd" | grep -Eqi 'eval[[:space:]]+["'\''$(]*[[:space:]]*\$?\(?[[:space:]]*(curl|wget|fetch)'; then
  printf 'BLOCKED: eval of a network fetch (eval "$(curl …)"). Save, inspect, then run.\n' >&2
  exit 2
fi

exit 0
