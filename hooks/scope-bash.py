#!/usr/bin/env python3
"""PreToolUse(Bash) hook — path-scoped auto-approval for innocuous commands.

Goal: cut approval fatigue without widening the blast radius.

  allow  : allowlisted read-only / light file-op tools (ls, cat, grep, mv, mkdir,
           sed, jq, read-only git, ...) when EVERY path argument resolves inside an
           in-scope root: the project dir, the session scratchpad, or ~/.claude.
           Script execution is allowed only when the script lives in scratch space.
  ask    : any path that resolves OUTSIDE the in-scope roots — forces a prompt even
           if a settings.json allow rule would otherwise auto-approve it.
  silent : (no decision -> normal permission flow) anything we cannot reason about:
           $ expansions other than $TMPDIR/$HOME/$CLAUDE_PROJECT_DIR, backticks, $(...), process substitution, sudo, interpreters
           with inline code, unknown tools, code execution inside the project,
           sensitive paths (.env, keys, ~/.claude/.local, .claude/wrappers), and any
           WRITE to protected config (.claude/, .git/, CLAUDE.md, .mcp.json, shell rc).

Fail-closed by construction: an unparseable command never yields "allow".
Deny/ask from other PreToolUse hooks (guardrails.sh) take precedence over allow.

Env overrides:
  CLAUDE_PROJECT_DIR        project root (set by Claude Code for hooks)
  CLAUDE_SCOPE_EXTRA_ROOTS  colon-separated extra in-scope roots
  CLAUDE_SCOPE_EXTRA_CMDS   comma-separated extra allowlisted executables
  CLAUDE_SCOPE_NO_BUILD     set to 1 to drop the default build/test-tool allowlist
"""
import json
import os
import re
import shlex
import sys

HOME = os.path.expanduser("~")
UID = os.getuid()

# ----------------------------------------------------------------- roots
def _real(p):
    return os.path.realpath(os.path.expanduser(p))

SANDBOX_TMPDIR = f"/tmp/claude-{UID}"

def load_roots(project):
    """-> (roots, scratch_roots, sandbox_enabled)"""
    scratch = [f"/private/tmp/claude-{UID}", SANDBOX_TMPDIR]
    roots = [_real(project), _real(os.path.join(HOME, ".claude"))]
    roots += [_real(s) for s in scratch]
    extra = os.environ.get("CLAUDE_SCOPE_EXTRA_ROOTS", "")
    roots += [_real(r) for r in extra.split(":") if r]
    sandbox = False
    try:
        with open(os.path.join(HOME, ".claude", "settings.json")) as fh:
            cfg = json.load(fh)
        for d in (cfg.get("permissions") or {}).get("additionalDirectories") or []:
            roots.append(_real(d))
        sandbox = bool((cfg.get("sandbox") or {}).get("enabled"))
    except Exception:
        pass
    return roots, [_real(s) for s in scratch], sandbox

# Sensitive path components / names: never auto-allow (fall through to prompt).
SENSITIVE_BASENAME = re.compile(
    r"^(\.env(\..*)?|\.ssh|\.aws|\.gnupg|secrets?|credentials?(\..*)?|"
    r"id_rsa.*|id_ed25519.*|.*\.(pem|key|p12|pfx|token|secret))$", re.I)
SENSITIVE_OK = re.compile(r"^\.env\.(example|sample|template|dist)$", re.I)
PSEUDO = {"/dev/null", "/dev/stdin", "/dev/stdout", "/dev/stderr", "/dev/tty", "/dev/fd"}

# Paths that may be READ in scope but must never be WRITTEN without a prompt:
# Claude Code's own config/hooks, git internals, shell rc files. A hook that can
# rewrite its own settings is no guardrail.
PROTECTED_COMPONENTS = {".claude", ".git", ".claude-plugin"}
PROTECTED_BASENAMES = {"CLAUDE.md", ".mcp.json", ".claude.json", "settings.json",
                       "settings.local.json", "managed-settings.json", ".zshrc", ".bashrc",
                       ".bash_profile", ".zprofile", ".profile", ".zshenv", ".gitconfig"}
WRITE_TOOLS = {"mv", "cp", "rm", "rmdir", "mkdir", "touch", "ln", "chmod", "truncate", "tee"}

def is_protected(rp):
    parts = rp.split(os.sep)
    if any(c in PROTECTED_COMPONENTS for c in parts[:-1]) or parts[-1] in PROTECTED_COMPONENTS:
        return True
    return parts[-1] in PROTECTED_BASENAMES

def classify_path(word, curdir, roots, scratch):
    """-> ('in'|'scratch'|'out'|'sensitive', abspath)"""
    if word in ("-", "{}", "{}/", "") or word.startswith("/dev/fd/"):
        return "in", word
    p = os.path.expanduser(word) if word.startswith("~") else word
    if not os.path.isabs(p):
        p = os.path.join(curdir, p)
    rp = os.path.realpath(p)
    if rp in PSEUDO:
        return "in", rp
    parts = rp.split(os.sep)
    for comp in parts:
        if SENSITIVE_BASENAME.match(comp) and not SENSITIVE_OK.match(comp):
            return "sensitive", rp
    claude_dir = _real(os.path.join(HOME, ".claude"))
    if rp.startswith(claude_dir + os.sep):
        rel = rp[len(claude_dir) + 1:].split(os.sep)
        if rel and rel[0] == ".local":
            return "sensitive", rp
    if (os.sep + ".claude" + os.sep + "wrappers") in rp + os.sep:
        return "sensitive", rp
    for s in scratch:
        if rp == s or rp.startswith(s + os.sep):
            return "scratch", rp
    for r in roots:
        if rp == r or rp.startswith(r + os.sep):
            return "in", rp
    return "out", rp

# ----------------------------------------------------------------- allowlist
READ_ONLY = {
    "ls", "cat", "head", "tail", "wc", "grep", "egrep", "fgrep", "rg", "ag", "find", "fd",
    "stat", "file", "du", "df", "tree", "pwd", "echo", "printf", "true", "false", "test", "[",
    "which", "type", "whoami", "id", "date", "cal", "uname", "hostname", "basename", "dirname",
    "realpath", "readlink", "sort", "uniq", "cut", "tr", "column", "paste", "comm", "nl",
    "tac", "rev", "fold", "expand", "unexpand", "seq", "diff", "cmp", "md5", "md5sum",
    "shasum", "sha1sum", "sha256sum", "cksum", "jq", "yq", "wc", "strings", "tee", "yes",
}
FILE_OPS = {"mv", "cp", "mkdir", "rmdir", "touch", "ln", "chmod", "truncate", "rm", "cd",
            "pushd", "popd"}
WRAPPERS = {"time", "command", "builtin"}
INTERPRETERS = {"bash", "sh", "zsh", "python", "python3", "node", "ruby", "perl"}
INLINE_CODE_FLAGS = {"-c", "-e", "-m", "-p", "-E", "--eval", "--print", "-i", "--interactive",
                     "-s", "--stdin"}
SYSTEM_BIN = ("/bin/", "/usr/bin/", "/usr/local/bin/", "/opt/homebrew/bin/", "/sbin/", "/usr/sbin/")

GIT_RO = {
    "status", "diff", "log", "show", "blame", "rev-parse", "ls-files", "ls-tree", "describe",
    "shortlog", "cat-file", "grep", "fetch", "add", "rev-list", "name-rev", "for-each-ref",
    "merge-base", "diff-tree", "show-ref", "var", "check-ignore", "count-objects", "version",
    "ls-remote", "diff-files", "diff-index", "status",
}
GIT_GLOBAL_REJECT = ("-c", "--exec-path", "--git-dir", "--work-tree", "--namespace",
                     "--config-env", "--super-prefix")
GH_RO = {
    "pr": {"view", "list", "status", "diff", "checks"},
    "issue": {"view", "list", "status"},
    "run": {"list", "view"},
    "release": {"list", "view"},
    "repo": {"view"},
    "auth": {"status"},
    "search": {"issues", "prs", "repos", "code", "commits"},
}

# Project build/test tools: allowed only for these subcommands, only when the command
# runs inside the OS sandbox, and still path-scoped.
# They run project code, so the OS sandbox is the real boundary; installs stay behind
# the settings permissions.ask rules (which outrank a hook allow).
BUILD_TOOLS = {
    "make": None,  # any target
    "pytest": None,
    "npm": {"test", "t", "run", "run-script", "ls", "outdated"},
    "pnpm": {"test", "t", "run", "ls", "outdated"},
    "yarn": {"test", "run", "list", "outdated"},
    "cargo": {"build", "b", "check", "c", "test", "t", "clippy", "fmt", "doc", "tree"},
    "go": {"build", "test", "vet", "fmt", "list"},
}
if os.environ.get("CLAUDE_SCOPE_NO_BUILD") == "1":
    BUILD_TOOLS = {}

def check_build(exe, args, ctx):
    if not ctx.get("sandboxed"):
        raise NoDecision  # project code outside the OS sandbox -> normal prompt
    subs = BUILD_TOOLS[exe]
    if subs is None:
        return
    pos = nondash(args)
    if pos and pos[0] in subs:
        return
    raise NoDecision

EXTRA_CMDS = {c.strip() for c in os.environ.get("CLAUDE_SCOPE_EXTRA_CMDS", "").split(",") if c.strip()}

SED_DANGEROUS = re.compile(
    r"(^|[;\n{])\s*(?:\d+|\$|/(?:[^/\\]|\\.)*/)?\s*,?\s*(?:\d+|\$|/(?:[^/\\]|\\.)*/)?\s*[ewrRW]\b"
    r"|s(.)(?:(?!\2).|\\.)*\2(?:(?!\2).|\\.)*\2[a-zA-Z0-9]*[ew]")

class NoDecision(Exception):
    pass

def nondash(args):
    return [a for a in args if not a.startswith("-")]

def check_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        a = args[i]
        if a == "-C":
            i += 2
            continue
        if a.startswith(GIT_GLOBAL_REJECT):
            raise NoDecision
        i += 1
    if i >= len(args):
        raise NoDecision
    sub, rest = args[i], args[i + 1:]
    opts = [a for a in rest if a.startswith("-")]
    pos = nondash(rest)
    if sub in GIT_RO:
        return
    if sub == "branch":
        bad = {"-d", "-D", "-m", "-M", "-f", "--delete", "--move", "--force", "-u", "-c", "-C",
               "--copy", "--set-upstream-to", "--unset-upstream", "--edit-description"}
        if any(o in bad or o.startswith("--set-upstream-to=") for o in opts):
            raise NoDecision
        return
    if sub == "remote":
        if not rest or rest[0] in ("-v", "--verbose", "show", "get-url"):
            return
        raise NoDecision
    if sub == "stash" and rest and rest[0] in ("list", "show"):
        return
    if sub == "tag":
        if not pos and not any(o in ("-d", "-a", "-f", "-s", "--delete", "--force") for o in opts):
            return
        raise NoDecision
    if sub == "worktree" and rest and rest[0] == "list":
        return
    if sub == "reflog" and (not pos or pos[0] == "show"):
        return
    if sub == "symbolic-ref" and len(pos) <= 1:
        return
    if sub == "config":
        write = {"--unset", "--unset-all", "--add", "--replace-all", "--edit", "-e",
                 "--rename-section", "--remove-section"}
        if any(o in write for o in opts):
            raise NoDecision
        ro = {"--get", "--get-all", "--get-regexp", "--list", "-l", "--show-origin"}
        if any(o in ro for o in opts) or len(pos) == 1:
            return
        raise NoDecision
    raise NoDecision

def check_gh(args):
    pos = nondash(args)
    if any(o in ("-w", "--web") for o in args):
        raise NoDecision
    if len(pos) >= 2 and pos[1] in GH_RO.get(pos[0], set()):
        return
    raise NoDecision

def check_sed(args):
    scripts = []
    i = 0
    seen_e = False
    while i < len(args):
        a = args[i]
        if a in ("-f", "--file") or a.startswith("--file="):
            raise NoDecision
        if a in ("-e", "--expression"):
            scripts.append(args[i + 1] if i + 1 < len(args) else "")
            seen_e = True
            i += 2
            continue
        if a.startswith("--expression="):
            scripts.append(a.split("=", 1)[1]); seen_e = True
        i += 1
    if not seen_e:
        p = nondash(args)
        if p:
            scripts.append(p[0])
    for s in scripts:
        if SED_DANGEROUS.search(s):
            raise NoDecision

def check_awk(args):
    i = 0
    prog = None
    while i < len(args):
        a = args[i]
        if a in ("-f", "--file") or a.startswith("--file="):
            raise NoDecision
        if a in ("-v", "-F"):
            i += 2
            continue
        if not a.startswith("-"):
            prog = a
            break
        i += 1
    if prog is None or re.search(r"system|getline|\||print\s*>|printf\s*>", prog):
        raise NoDecision

def check_rm(args, ctx):
    for o in args:
        if (len(o) > 2 and o.startswith("--") and "--recursive".startswith(o)) or \
           (o.startswith("-") and not o.startswith("--") and ("r" in o or "R" in o)):
            targets = nondash(args)
            if not targets or ctx.get("xargs") or "--" in args:
                raise NoDecision  # targets we cannot see (stdin / xargs / after --)
            if any(t.endswith("/") for t in targets):
                raise NoDecision  # `rm -r link/` follows a symlink on macOS
            ctx["rm_r"].extend(targets)  # verdict in main: scratch-only, below root
            return

XARGS_VALOPTS = {"-n", "-I", "-P", "-L", "-s", "-d", "-E", "-a", "-R", "-S", "-J"}

def split_xargs(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] in XARGS_VALOPTS:
            i += 2
        else:
            i += 1
    return args[i:]

# ----------------------------------------------------------------- tokenizing
SEPARATORS = {";", "&&", "||", "|", "&", "|&", "(", ")"}
REDIRECTS = {">", ">>", "<", ">|", ">&", "<&", "<>"}

def strip_heredocs(cmd):
    """Return cmd with heredoc bodies removed; raise NoDecision if malformed."""
    out_lines = []
    lines = cmd.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.search(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2", line)
        if not m:
            out_lines.append(line)
            i += 1
            continue
        delim = m.group(3)
        line = line[:m.start()] + " " + line[m.end():]
        if "<<" in line:
            raise NoDecision  # two heredocs on one line — don't bother
        out_lines.append(line)
        j = i + 1
        while j < len(lines):
            cand = lines[j].lstrip("\t") if m.group(1) else lines[j]
            if cand == delim:
                break
            j += 1
        if j >= len(lines):
            raise NoDecision
        i = j + 1
    return "\n".join(out_lines)

KNOWN_VARS = re.compile(r"\$(?:\{(TMPDIR|HOME|CLAUDE_PROJECT_DIR)\}|(TMPDIR|HOME|CLAUDE_PROJECT_DIR)(?![A-Za-z0-9_]))")

KNOWN_NAMES = re.compile(r"(?<![A-Za-z0-9_])(TMPDIR|HOME|CLAUDE_PROJECT_DIR)(?![A-Za-z0-9_])")

def expand_known(cmd, values):
    """Substitute the few variables whose value we know; any other $ stays and
    makes normalize() give up. Skip substitution entirely (leaving the $ to fail
    closed) when the command could change or not expand the value: the name
    appears outside a plain $VAR / ${VAR} reference (TMPDIR=.., export, read,
    unset), or a $ is escaped or sits in single quotes."""
    if KNOWN_NAMES.search(KNOWN_VARS.sub("", cmd)):
        return cmd
    if re.search(r"\\\$", cmd) or re.search(r"'[^']*\$[^']*'", cmd):
        return cmd
    return KNOWN_VARS.sub(lambda m: values[m.group(1) or m.group(2)], cmd)

def normalize(cmd, values=None):
    if values:
        cmd = expand_known(cmd, values)
    if re.search(r"[`]|\$\(|\$\{|<\(|>\(|\$", cmd):
        raise NoDecision
    cmd = strip_heredocs(cmd)
    cmd = re.sub(r"(?<!\S)\d*>&\s*\d+", " ", cmd)      # 2>&1, >&2
    cmd = re.sub(r"(?<![\w])\d(>>?|<)", r"\1", cmd)   # 2>/dev/null -> >/dev/null
    cmd = cmd.replace("&>>", ">>").replace("&>", ">")
    return cmd

def tokenize(cmd):
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        return list(lex)
    except ValueError:
        raise NoDecision

def segments(tokens):
    """Yield (argv, redirect_targets) per simple command. Handles find -exec and
    escaped ';' by consuming -exec … ; / + inside a find segment."""
    cur, redirs = [], []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if cur and cur[0] == "find" and t in ("-exec", "-execdir", "-ok", "-okdir"):
            cur.append(t)
            i += 1
            while i < len(tokens) and tokens[i] not in (";", "+"):
                cur.append(tokens[i]); i += 1
            if i >= len(tokens):
                raise NoDecision
            cur.append(tokens[i]); i += 1
            continue
        if t in SEPARATORS:
            if cur:
                yield cur, redirs
            cur, redirs = [], []
            i += 1
            continue
        if t in REDIRECTS:
            if i + 1 >= len(tokens) or tokens[i + 1] in SEPARATORS or tokens[i + 1] in REDIRECTS:
                raise NoDecision
            redirs.append(tokens[i + 1])
            i += 2
            continue
        if t.startswith((">", "<")) or t in (";;", ";&", ";;&"):
            raise NoDecision
        cur.append(t)
        i += 1
    if cur:
        yield cur, redirs

# ----------------------------------------------------------------- evaluate
def exe_name(tok):
    if "/" in tok:
        if tok.startswith(SYSTEM_BIN):
            return os.path.basename(tok), None
        return None, tok  # a script / binary path
    return tok, None

def eval_argv(argv, ctx):
    """Check one simple command. Collects paths in ctx['paths'] and raises NoDecision
    when the command is not auto-approvable."""
    # env assignments prefix
    while argv and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", argv[0]):
        val = argv[0].split("=", 1)[1]
        if "/" in val or val.startswith("~"):
            ctx["paths"].append(val)
        argv = argv[1:]
    if not argv:
        return
    while argv and argv[0] in WRAPPERS:
        argv = argv[1:]
    if not argv:
        return
    if argv[0] == "sudo":
        raise NoDecision

    exe, script = exe_name(argv[0])
    args = argv[1:]
    if exe in WRITE_TOOLS or (exe == "sed" and any(a in ("-i", "--in-place") or a.startswith(("-i", "--in-place=")) for a in args)) \
       or (exe == "sort" and "-o" in args) or (exe == "find" and "-delete" in args):
        ctx["writes"].extend(a for a in nondash(args))

    # Collect candidate paths from args (non-options, and --opt=value values).
    for a in args:
        if a.startswith("-"):
            if "=" in a:
                v = a.split("=", 1)[1]
                if "/" in v or v.startswith("~"):
                    ctx["paths"].append(v)
            continue
        ctx["paths"].append(a)

    if script is not None:
        ctx["scripts"].append(script)
        return  # verdict decided in finalize: script must be in scratch

    if args == ["--version"] or args == ["version"]:
        return
    if exe in INTERPRETERS:
        if any(a in INLINE_CODE_FLAGS for a in args):
            raise NoDecision
        pos = nondash(args)
        if not pos:
            raise NoDecision
        ctx["scripts"].append(pos[0])
        return

    if exe in EXTRA_CMDS:
        return
    if exe in BUILD_TOOLS:
        return check_build(exe, args, ctx)
    if exe == "git":
        return check_git(args)
    if exe == "gh":
        return check_gh(args)
    if exe == "sed":
        return check_sed(args)
    if exe == "awk" or exe == "gawk":
        return check_awk(args)
    if exe == "rm":
        return check_rm(args, ctx)
    if exe == "xargs":
        inner = split_xargs(args)
        if not inner:
            raise NoDecision
        ctx["xargs"] = True
        return eval_argv(inner, ctx)
    if exe == "find":
        # inner -exec commands
        i = 0
        while i < len(args):
            if args[i] in ("-exec", "-execdir", "-ok", "-okdir"):
                j = i + 1
                while j < len(args) and args[j] not in (";", "+"):
                    j += 1
                eval_argv(args[i + 1:j], ctx)
                i = j + 1
                continue
            i += 1
        return
    if exe in ("cd", "pushd"):
        target = nondash(args)
        ctx["cd"] = target[0] if target else "~"
        if not target:
            ctx["paths"].append("~")
        return
    if exe in READ_ONLY or exe in FILE_OPS:
        return
    raise NoDecision

def scratch_rm_ok(word, kind, rp, scratch, session):
    """Recursive delete only inside scratch and never across sessions: below
    /tmp/claude-<uid>, a first component starting with '-' is a per-project dir
    holding other sessions' scratchpads, so it must continue into this session."""
    if kind != "scratch" or rp in scratch or re.search(r"[*?\[]", word):
        return False
    for s in scratch:
        if rp.startswith(s + os.sep):
            rel = rp[len(s) + 1:].split(os.sep)
            if rel[0].startswith("-"):
                return bool(session) and len(rel) >= 3 and rel[1] == session
            return True
    return False

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd.strip():
        return
    cwd = data.get("cwd") or os.getcwd()
    project = os.environ.get("CLAUDE_PROJECT_DIR") or cwd
    roots, scratch, sandbox = load_roots(project)
    unsandboxed = bool((data.get("tool_input") or {}).get("dangerouslyDisableSandbox"))
    values = {"HOME": HOME, "CLAUDE_PROJECT_DIR": project}
    # Sandboxed commands see TMPDIR=/tmp/claude-<uid>; otherwise trust only our own env.
    tmp = SANDBOX_TMPDIR if sandbox and not unsandboxed else os.environ.get("TMPDIR")
    if tmp:
        values["TMPDIR"] = tmp.rstrip("/") or "/"

    sandboxed = sandbox and not unsandboxed
    session = data.get("session_id") or ""

    out, sensitive = [], []
    try:
        tokens = tokenize(normalize(cmd, values))
        segs = list(segments(tokens))
        curdir = cwd
        for argv, redirs in segs:
            ctx = {"paths": list(redirs), "scripts": [], "cd": None, "writes": list(redirs),
                   "rm_r": [], "sandboxed": sandboxed}
            eval_argv(argv, ctx)
            for t in ctx["rm_r"]:
                kind, rp = classify_path(t, curdir, roots, scratch)
                if kind == "out":
                    out.append(rp)
                if not scratch_rm_ok(t, kind, rp, scratch, session) or len(segs) != 1:
                    # alone on the line: an earlier `ln -s` in the same command would
                    # turn a scratch path into a link to the project before rm runs
                    raise NoDecision
            for w in ctx["writes"]:
                _, rp = classify_path(w, curdir, roots, scratch)
                if is_protected(rp):
                    raise NoDecision  # write to Claude config / git internals / rc -> prompt
            for p in ctx["paths"]:
                kind, rp = classify_path(p, curdir, roots, scratch)
                if kind == "out":
                    out.append(rp)
                elif kind == "sensitive":
                    sensitive.append(rp)
            for s in ctx["scripts"]:
                kind, rp = classify_path(s, curdir, roots, scratch)
                if kind != "scratch":
                    raise NoDecision  # code execution outside scratch -> normal prompt
            if ctx["cd"]:
                kind, rp = classify_path(ctx["cd"], curdir, roots, scratch)
                if kind == "out":
                    out.append(rp)
                curdir = rp
    except NoDecision:
        if out:
            return emit("ask", "Path outside project/scratch/~/.claude: " + ", ".join(sorted(set(out))))
        return
    if out:
        return emit("ask", "Path outside project/scratch/~/.claude: " + ", ".join(sorted(set(out))))
    if sensitive:
        return
    emit("allow", "scope-bash: in-scope read/file op")

def emit(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason}}))

if __name__ == "__main__":
    main()
