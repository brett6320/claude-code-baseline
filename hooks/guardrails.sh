#!/usr/bin/env bash
# claude-code-baseline guardrails — PreToolUse(Bash) enforcement.
# Source: github.com/brett6320/claude-code-baseline (policies mechanized per enforcement.md).
# Emits a PreToolUse permissionDecision (deny|ask) with a reason, else exits silently (allow).
#
# Covers policies 1-6 and 9: attribution trailers in commits, commits to main/master,
# shell reads of .env/key files, env dumps, pipe-to-shell, destructive git/rm forms, merges.
# Superset of hooks/block-pipe-to-shell.sh — install one or the other, not both.
# Install: copy to ~/.claude/hooks/guardrails.sh; wire as PreToolUse matcher "Bash".
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
[ -z "$cmd" ] && exit 0

emit() { # $1=decision $2=reason
  reason="$(printf '%s' "$2" | jq -R -s .)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}' "$1" "$reason"
  exit 0
}
deny() { emit deny "$1"; }
ask()  { emit ask  "$1"; }
has() { printf '%s' "$cmd" | grep -Eiq "$1"; }

# ---------- DENY: hard blocks ----------

# Pipe-to-shell from network fetch (safety.md: no curl|bash from unvetted sources)
if has '\b(curl|wget|fetch)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|d)?sh\b'; then
  deny "Blocked: pipe-to-shell from a network fetch (safety policy). Download, inspect, then run."
fi

# Pipe network fetch into an interpreter — curl … | python/perl/ruby/node/php (safety.md)
if has '\b(curl|wget|fetch)\b[^|]*\|[^|]*(python[0-9.]*|perl|ruby|node|php)\b'; then
  deny "Blocked: piping a network fetch into an interpreter (safety policy). Save, inspect, then run."
fi

# Process-substituted network fetch — bash <(curl …) / source <(wget …) (safety.md)
if has '\b(source|\.|(ba)?sh|python[0-9.]*|node)[[:space:]]+<\([[:space:]]*(curl|wget|fetch)'; then
  deny "Blocked: executing a process-substituted network fetch (safety policy). Save, inspect, then run."
fi

# eval of a command-substituted fetch — eval "\$(curl …)" (safety.md)
if has 'eval[[:space:]]+["'\''$(]*[[:space:]]*\$?\(?[[:space:]]*(curl|wget|fetch)'; then
  deny "Blocked: eval of a network fetch (safety policy). Save, inspect, then run."
fi

# Claude/AI attribution in commits (attribution.md / commits.md)
if has '\bgit[[:space:]]+commit\b' && has 'co-authored-by:[^\"]*(claude|anthropic)|generated with (claude|ai)|🤖'; then
  deny "Blocked: Claude/AI attribution in commit (attribution policy). Remove the trailer/marker."
fi

# Direct commit to main/master (branching.md)
if has '\bgit[[:space:]]+commit\b'; then
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    deny "Blocked: direct commit to '$branch' (branching policy). Create a branch and open a PR."
  fi
fi

# Reading .env / secret files via shell (secrets.md) — allow .env.example/sample/template/dist
if has '\b(cat|bat|less|more|head|tail|nl|xxd|od|strings|hexdump|tac)\b[^|]*\.env([.][a-z0-9_]+)*\b' \
   && ! has '\.env[.](example|sample|template|dist)\b'; then
  deny "Blocked: reading a .env/secret file (secrets policy). Do not print secret contents."
fi

# Reading key/cert/secret files via shell (secrets.md — never reveal credentials to Claude itself)
if has '\b(cat|bat|less|more|head|tail|nl|xxd|od|strings|hexdump|tac)\b[^|]*(id_rsa|id_ed25519|\.pem\b|\.p12\b|\.pfx\b|/secrets/|\.ssh/)'; then
  deny "Blocked: reading a private key/cert/secret file (secrets policy). Write a credentialed-action wrapper in .claude/wrappers/ instead."
fi

# Dumping the full environment (secrets.md — shell env inheritance can contain live secrets)
if has '^\s*(printenv|env)\s*($|\|)' ; then
  ask "Confirm: dumping full environment can print inherited secrets (secrets policy). Prefer printenv <SPECIFIC_VAR>."
fi

# ---------- ASK: confirmation gates (destructive-ops.md / merging.md) ----------

if has '\brm\b[^|]*(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-rf|-fr)\b'; then
  ask "Confirm: recursive force delete (rm -rf) — destructive, hard to reverse."
fi
if has '\bgit[[:space:]]+reset\b[^|]*--hard'; then
  ask "Confirm: git reset --hard discards working-tree/commit state — destructive."
fi
if has '\bgit[[:space:]]+clean\b[^|]*-[a-z]*f'; then
  ask "Confirm: git clean -f deletes untracked files — destructive."
fi
if has '\bgit[[:space:]]+push\b[^|]*(--force|--force-with-lease|[[:space:]]-f\b)'; then
  ask "Confirm: force push can overwrite shared history (destructive-ops policy)."
fi
if has '\bgit[[:space:]]+merge\b|\bgh[[:space:]]+pr[[:space:]]+merge\b'; then
  ask "Confirm: merge requires explicit per-PR instruction (merging policy)."
fi

exit 0
