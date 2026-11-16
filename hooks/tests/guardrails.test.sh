#!/usr/bin/env bash
# Decision tests for hooks/guardrails.sh (merge gate and rm -rf scratch exemption).
# Usage: hooks/tests/guardrails.test.sh   (run from the repo root; exits 1 on any FAIL)
set -u
cd "$(dirname "$0")/../.." || exit 1
HOOK="hooks/guardrails.sh"
U="$(id -u)"
fail=0

SID="test-session-id"
t() { # expected(deny|ask|silent) command
  local exp="$1" cmd="$2" res m
  res=$(jq -n --arg c "$cmd" --arg s "$SID" '{tool_name:"Bash",session_id:$s,tool_input:{command:$c}}' | bash "$HOOK" \
    | jq -r '.hookSpecificOutput.permissionDecision // empty')
  [ -z "$res" ] && res=silent
  if [ "$res" = "$exp" ]; then m=ok; else m=FAIL; fail=1; fi
  printf '%-4s want=%-6s got=%-6s %s\n' "$m" "$exp" "$res" "$cmd"
}

# ---- merge gate: real merges only
t ask 'git merge feature'
t ask 'git merge'
t ask 'gh pr merge 12 --squash'
t silent 'git merge-base main HEAD'
t silent 'git merge-tree a b'
t ask 'git -C . merge x'
t ask 'git --no-pager merge x'
t ask 'git merge"" feature'
t ask "git 'merge' feature"
t ask 'bash -c "git merge x"'
t silent 'git commit -m "fix merge bug"'

# ---- rm -rf: exempt only below the scratch root
t silent "rm -rf /tmp/claude-$U/sess/scratchpad/build"
t silent "rm -rf /private/tmp/claude-$U/a /private/tmp/claude-$U/b/c"
t silent "rm -rf '/tmp/claude-$U/x y'"
t ask "rm -rf /tmp/claude-$U"
t ask "rm -rf /tmp/claude-$U/"
t ask "rm -rf /tmp/claude-$U/."
t ask "rm -rf /tmp/claude-$U/./"
t ask "rm -rf /tmp/claude-$U/*"
t ask "rm -rf /tmp/claude-$U/a/../.."
t ask "rm -rf /tmp/claude-$U/a /etc"
t ask "rm -rf /tmp/claude-$U/a; rm -rf ~"
t ask "rm -rf /tmp/claude-$U/a && rm -rf build"
t ask "rm -rf /tmp/claude-999999/a"
t ask "rm -rf /tmp/claude-$U/\$(whoami)"
t ask 'rm -rf build'
t ask 'rm -rf $HOME/x'
t ask 'rm -rf $TMPDIR'
t ask "TMPDIR=..; rm -r -f \$TMPDIR/claude-code-baseline"

# ---- every recursive form asks, not only -rf
t ask 'rm -r hooks'
t ask 'rm -r -f hooks'
t ask 'rm -R hooks'
t ask 'rm --recursive --force hooks'
t silent 'rm hooks/x.txt'
t ask 'rm "-rf" hooks'
t ask "rm '-r' hooks"
t ask 'rm \-rf hooks'
t ask "r''m -rf hooks"
t ask 'rm --recur hooks'
t ask '/bin/rm -r hooks'
t ask 'bash -c "rm -r hooks"'
t ask 'echo x | xargs rm -r'
t ask 'rm -- -r'   # raw-text gate stays conservative
t silent 'grep -r foo .; rm x.txt'

# ---- rm exemption: no --, trailing slash, symlinks, or other sessions' dirs
t ask "rm -rf -- -dir /tmp/claude-$U/a"
t ask "rm -rf /tmp/claude-$U/a/"
t ask "rm -rf /tmp/claude-$U/-Users-x-other/other-session/scratchpad"
t ask "rm -rf /tmp/claude-$U/-Users-x-proj"
t silent "rm -rf /tmp/claude-$U/-Users-x-proj/$SID/scratchpad/build"
LNK="/tmp/claude-$U/guardrails-test-link"
rm -f "$LNK"; ln -s "$PWD" "$LNK"
t ask "rm -rf $LNK"
t ask "rm -rf $LNK/hooks"
rm -f "$LNK"

# ---- python3 broken: word gates fail closed, grep-only gates still fire
NOPY="$(mktemp -d "${TMPDIR:-/tmp}/guardrails-nopy.XXXXXX")" || exit 1; printf '#!/bin/sh\nexit 1\n' > "$NOPY/python3"; chmod +x "$NOPY/python3"
PATH="$NOPY:$PATH" t ask 'git reset --hard HEAD'
PATH="$NOPY:$PATH" t ask "r''m -rf hooks"
PATH="$NOPY:$PATH" t ask "git 'merge' x"
PATH="$NOPY:$PATH" t ask "rm -rf /tmp/claude-$U/sess/scratchpad/build"
PATH="$NOPY:$PATH" t silent 'ls -la'
rm -rf "$NOPY"

exit $fail
