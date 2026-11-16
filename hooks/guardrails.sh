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

# Word-level view of the command (quotes/escapes resolved the way the shell will), so
# `rm "-rf"`, `r''m -r`, `rm --recur`, `git 'merge'` or `git -C . merge` can't slip past the
# raw-text patterns. Recurses into quoted strings that hold whitespace (bash -c "…").
# Prints "rm" and/or "merge"; an unparseable command that mentions either fails closed.
word_gates() {
  CMD="$cmd" python3 -I -c '
import os, re, shlex
SEP = {";", "&&", "||", "|", "&", "|&", "(", ")", "\n"}
GIT_VALOPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}
hits = set()
def words(text):
    lex = shlex.shlex(text, posix=True, punctuation_chars=";&|()")
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)
def check(text, depth=0):
    try:
        toks = words(text)
    except ValueError:
        if re.search(r"rm|merge", text):
            hits.update(("rm", "merge") if "merge" in text else ("rm",))
        return
    seg = []
    for t in toks + [";"]:
        if t in SEP or set(t) <= set(";&|()"):
            scan(seg); seg = []
        else:
            seg.append(t)
    if depth < 3:
        for t in toks:
            if re.search(r"\s", t):
                check(t, depth + 1)
def scan(seg):
    for i, t in enumerate(seg):
        name = os.path.basename(t)
        if name == "rm":
            for o in seg[i + 1:]:
                if o == "--":
                    break
                if (o.startswith("-") and not o.startswith("--") and re.search("[rR]", o)) or \
                   (len(o) > 2 and o.startswith("--") and "--recursive".startswith(o)):
                    hits.add("rm")
        if name == "git":
            j = i + 1
            while j < len(seg) and seg[j].startswith("-"):
                j += 2 if seg[j] in GIT_VALOPTS else 1
            if j < len(seg) and seg[j] == "merge":
                hits.add("merge")
check(os.environ["CMD"])
print(" ".join(sorted(hits)))
'
}
# Fail closed: if python3 is missing or errors, gate on any mention (r''m included).
if ! gates="$(word_gates 2>/dev/null)"; then
  gates=""
  has 'r[^[:alnum:][:space:]]*m' && gates="rm"
  has 'merge' && gates="$gates merge"
fi

# Recursive rm confined to this session's scratch space is routine cleanup, not a destructive
# op. Exempt only a lone `rm` (no chaining/substitution/globs/`--`/trailing slash) whose every
# target resolves, with no symlink on the way, to at least one level below /tmp/claude-<uid>
# (never the root) and, inside a per-project dir (leading '-'), within this session's own
# subdir. $TMPDIR counts only when the sandbox is on (it then is /tmp/claude-<uid>).
scratch_rm_only() {
  printf '%s' "$cmd" | grep -Eq '[;&|<>`*?\\]|\$\(|(^|[[:space:]])--([[:space:]]|$)|/[[:space:]]*$|/[[:space:]]' && return 1
  [ "$(printf '%s\n' "$cmd" | wc -l)" -eq 1 ] || return 1
  local sbx=0
  jq -e '.sandbox.enabled == true' "$HOME/.claude/settings.json" >/dev/null 2>&1 && sbx=1
  CMD="$cmd" SBX="$sbx" SID="$(printf '%s' "$input" | jq -r '.session_id // ""')" python3 -I -c '
import os, re, shlex, sys
uid = os.getuid()
try:
    argv = shlex.split(os.environ["CMD"])
except ValueError:
    sys.exit(1)
if not argv or argv[0] != "rm":
    sys.exit(1)
i = 1
while i < len(argv) and argv[i].startswith("-"):
    if not re.fullmatch(r"-[A-Za-z]+|--(recursive|force|verbose)", argv[i]):
        sys.exit(1)
    i += 1
targets = argv[i:]
if not targets:
    sys.exit(1)
root = os.path.realpath(f"/tmp/claude-{uid}")
for t in targets:
    if t.startswith("-") or "$" in t and os.environ["SBX"] != "1":
        sys.exit(1)
    t = re.sub(r"^\$(TMPDIR\b|\{TMPDIR\})", f"/tmp/claude-{uid}", t)
    if "$" in t or not t.startswith(("/tmp/", "/private/tmp/")):
        sys.exit(1)
    rel = os.path.normpath(t).split(os.sep)
    base = 3 if rel[1] == "tmp" else 4          # ["", "tmp", "claude-N", ...]
    if os.path.normpath(t) != t.rstrip("/") or len(rel) <= base or rel[base - 1] != f"claude-{uid}":
        sys.exit(1)
    p = os.path.join(root, *rel[base:])
    cur = root
    for comp in rel[base:]:                     # no symlink anywhere below the root
        cur = os.path.join(cur, comp)
        if os.path.islink(cur):
            sys.exit(1)
    if os.path.realpath(p) != p:
        sys.exit(1)
    sub = rel[base:]
    if sub[0].startswith("-") and not (len(sub) >= 3 and sub[1] == os.environ["SID"] and os.environ["SID"]):
        sys.exit(1)
sys.exit(0)
'
}
if { has '\brm\b[^|;&]*[[:space:]](-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)\b' || [[ " $gates " == *" rm "* ]]; } \
   && ! scratch_rm_only; then
  ask "Confirm: recursive delete (rm -r) — destructive, hard to reverse."
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
if has '\bgit[[:space:]]+merge([[:space:]]|$)|\bgh[[:space:]]+pr[[:space:]]+merge\b' || [[ " $gates " == *" merge "* ]]; then
  ask "Confirm: merge requires explicit per-PR instruction (merging policy)."
fi

exit 0
