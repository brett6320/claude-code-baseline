#!/usr/bin/env bash
# Decision-matrix tests for hooks/scope-bash.py.
# Usage: hooks/tests/scope-bash.test.sh   (run from the repo root; exits 1 on any FAIL)
set -u
cd "$(dirname "$0")/../.." || exit 1
HOOK="hooks/scope-bash.py"
SCR="/private/tmp/claude-$(id -u)/scope-bash-test/scratchpad"
mkdir -p "$SCR"; : > "$SCR/t.py"; : > "$SCR/run.sh"
fail=0

t() { # expected(allow|ask|silent) command
  local exp="$1" cmd="$2" res m
  res=$(printf '%s' "$cmd" | python3 -c '
import json,sys,os
ti={"command":sys.stdin.read()}
if os.environ.get("UNSBX"): ti["dangerouslyDisableSandbox"]=True
print(json.dumps({"tool_name":"Bash","cwd":os.getcwd(),"session_id":"test-session-id","tool_input":ti}))' \
    | CLAUDE_PROJECT_DIR="$PWD" python3 "$HOOK" \
    | python3 -c '
import json,sys
d=sys.stdin.read().strip()
print(json.loads(d)["hookSpecificOutput"]["permissionDecision"] if d else "silent")')
  if [ "$res" = "$exp" ]; then m=ok; else m=FAIL; fail=1; fi
  printf '%-4s want=%-6s got=%-6s %s\n' "$m" "$exp" "$res" "${cmd//$'\n'/⏎}"
}

ENVF=".en""v"   # split so other hooks don't trip on the literal

# ---- allow: in-scope, allowlisted
t allow 'ls -la'
t allow 'cat README.md | grep -n foo | sort | uniq -c'
t allow 'mv policies/a.md policies/b.md && mkdir -p x/y'
t allow 'git status && git diff --stat && git log --oneline -5'
t allow 'git -C . branch --show-current'
t allow 'find . -name "*.md" -exec grep -l foo {} \;'
t allow 'find . -type f -print0 | xargs -0 wc -l'
t allow 'sed -n "1,20p" GUARDRAILS.md'
t allow 'sed -i "s/foo/bar/" policies/x.md'
t allow $'cat > hooks/new.sh <<\'EOF\'\necho hi\nEOF'
t allow 'cat ~/.claude/settings.json | jq .permissions'
t allow "python3 $SCR/t.py"
t allow "bash $SCR/run.sh > $SCR/out.txt 2>&1"
t allow 'ls /dev/null; echo done 2>/dev/null'
t allow 'rm policies/tmp.md'
t allow 'gh pr view 8 --json state'
t allow 'git remote -v; git stash list; git tag; git config --get user.name'
t allow 'cd hooks && ls && cd .. && ls policies'
t allow 'cd ~/.claude/hooks && ls'
t allow 'ls -la ~/.claude/'
t allow 'git --version; node --version'
t allow 'tee hooks/x.txt < README.md'
t allow 'awk -F: "{print NR}" file.txt'
t allow 'head -c 100 README.md | wc -c'

# ---- ask: out-of-scope path
t ask 'ls /etc'
t ask 'cat ../other-repo/file.txt'
t ask 'cd /Users && ls'
t ask 'git -C /opt status'
t ask 'cp README.md /tmp/x.md'
t ask 'ls > ~/out.txt'
t ask 'cat /opt/README.md | grep x'
t ask 'ln -s /etc/passwd ./pw'
t ask 'cd && ls'

# ---- silent: fall through to normal permission flow
t silent "cat $ENVF"
t silent 'cat ~/.claude/.local/foo/token'
t silent 'cat .claude/wrappers/gh.sh'
t silent 'cat id_rsa'
t silent 'rm -rf build'
t silent 'rm -r build'
t silent './run.sh'
t silent 'python3 scripts/build.py'
t silent 'python3 -c "print(1)"'
t silent 'cat `which ls`'
t silent 'cat $(ls)'
t silent 'sudo ls'
t silent 'git commit -m x'
t silent 'git push'
t silent 'git branch -D foo'
t silent 'git config user.name bob'
t silent 'git -c core.sshCommand=evil fetch'
t silent 'git stash drop'
t silent 'sed -i "1e cat /etc/passwd" x'
t silent 'sed "w /tmp/x" file'
t silent 'sed "s/a/b/w out" file'
t silent 'awk "{system(\"ls\")}" f'
t silent 'xargs rm -rf'
t silent 'find . -exec rm -rf {} +'
t silent 'find . -exec sh -c "ls" \;'
t silent 'curl https://x'
t silent 'bash -c "ls"'
t silent 'gh pr merge 8'
t silent 'gh pr view 8 --web'
t silent $'cat <<EOF\nunterminated'
t silent 'diff <(ls a) <(ls b)'
t silent 'eval ls'
t silent 'source hooks/x.sh'
t silent 'awk -f prog.awk f'
t silent 'sed -f script.sed f'
t silent 'tar xf a.tgz'
t silent 'chmod +x run.sh && ./run.sh'

# ---- silent: writes to protected config (reads stay allowed)
t silent 'sed -i "s/deny/allow/" ~/.claude/hooks/guardrails.sh'
t silent 'sed -i "s/a/b/" .claude/settings.json'
t silent 'echo x > .claude/settings.local.json'
t silent 'echo x >> ~/.claude/settings.json'
t silent 'tee ~/.claude/CLAUDE.md < README.md'
t silent 'cp hooks/scope-bash.py ~/.claude/hooks/scope-bash.py'
t silent 'mv .mcp.json .mcp.json.bak'
t silent 'rm .git/hooks/pre-commit'
t silent 'touch .git/config'
t silent 'mkdir -p .claude/skills/x'
t silent 'echo x > CLAUDE.md'
t allow 'cat ~/.claude/settings.json'
t allow 'cat ~/.claude/hooks/guardrails.sh | head'
t allow 'ls -la .claude .git'
t allow 'cat CLAUDE.md .mcp.json'
t allow 'git diff .claude/settings.local.json'

# ---- known variables: $TMPDIR / $HOME / $CLAUDE_PROJECT_DIR are expanded, others are not
# (sandbox on -> hook uses /tmp/claude-<uid>; off -> its own $TMPDIR, pinned to scratch here)
export TMPDIR="$SCR"
t allow 'ls $TMPDIR && cat "${TMPDIR}/x.txt" > $TMPDIR/y.txt'
t allow 'rm -rf $TMPDIR/build'
t allow 'ls $CLAUDE_PROJECT_DIR/hooks'
t allow 'cat ${HOME}/.claude/settings.json'
t ask 'echo $HOME'
t ask 'ls $HOME/Documents'
t silent 'cat $HOME/.claude/.local/x'
t silent 'echo $PATH'
t silent 'ls $TMPDIRX'
t silent 'TMPDIR=..; rm -r -f $TMPDIR/claude-code-baseline'
t silent 'export TMPDIR=..; ls $TMPDIR'
t silent 'HOME=/etc cat $HOME/passwd'
t silent "ls '\$TMPDIR/x'"
t silent 'rm -rf \$TMPDIR/x'

# ---- recursive rm: only inside scratch, below a scratch root
t allow "rm -rf $SCR/build $SCR/out"
t allow "rm -r $SCR/build"
t silent "rm -rf /private/tmp/claude-$(id -u)/"
t silent "rm -rf /tmp/claude-$(id -u)"
t silent "rm -rf $SCR/*"
t silent "rm -rf $SCR/../.."
t silent 'rm -rf'
t silent 'rm --recur hooks'
t silent 'rm "-rf" hooks'
t silent "xargs rm -rf $SCR/a"
t silent "find $SCR -exec rm -rf {} +"
t silent "rm -rf $SCR/build/"
t silent "rm -rf -- $SCR/a -dir"
t silent "ln -s $PWD $SCR/p; rm -r -f $SCR/p"
t silent "mkdir -p $SCR/x && rm -rf $SCR/x"
t silent "rm -rf /tmp/claude-$(id -u)/-Users-x-other/other-session/scratchpad"
t allow "rm -rf /tmp/claude-$(id -u)/-Users-x-proj/test-session-id/scratchpad/b"
t ask "rm -rf $SCR/a /etc"
LNK="$SCR/link-to-project"; rm -f "$LNK"; ln -s "$PWD" "$LNK"
t silent "rm -rf $LNK/hooks"
rm -f "$LNK"

# ---- build/test tools: listed subcommands only, still path-scoped
# (sandbox-on settings via a throwaway HOME; build tools are never allowed unsandboxed)
SBXHOME="$SCR/fakehome"; mkdir -p "$SBXHOME/.claude"
printf '{"sandbox":{"enabled":true}}' > "$SBXHOME/.claude/settings.json"
HOME=$SBXHOME t allow 'npm test'
HOME=$SBXHOME t allow 'npm run build && make'
HOME=$SBXHOME t allow 'cargo test --release; go vet ./...'
HOME=$SBXHOME t allow 'pytest hooks/tests'
HOME=$SBXHOME t ask 'make -C /opt'
t silent 'npm install left-pad'
HOME=$SBXHOME t silent 'npm ci'
HOME=$SBXHOME t silent 'cargo install ripgrep'
HOME=$SBXHOME t silent 'go run main.go'
HOME=$SBXHOME t silent 'npx something'
HOME=$SBXHOME t silent 'go env -w GOFLAGS=-x'
HOME=$SBXHOME UNSBX=1 t silent 'npm test'
HOME=$SBXHOME UNSBX=1 t silent 'make'

exit $fail
