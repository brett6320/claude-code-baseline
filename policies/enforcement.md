# Policy 10 — Enforcement

Docs state *intent*. Enforcement makes rules deterministic. A rule that must hold every
time belongs in `settings.json` (hooks + permissions), not only in prose — the model can
be argued out of prose; it cannot bypass a deny rule or a PreToolUse hook.

## Environment beats model

- **Model layer** (CLAUDE.md, prompts, classifiers): probabilistic. Can fail under prompt
  injection. Anthropic red-team: instructed credential exfiltration succeeded 24/24 times.
- **Environment layer** (OS sandbox, permission rules, hooks): deterministic. Holds even
  when the model is tricked or ignores its own config.
- Design for the environment layer first. Treat docs as guidance, sandbox + hooks as the
  backstop.

## Permission rules (`settings.json`)

- Three tiers: read-only (auto), Bash/tools (approve per-session), file writes (per-session).
- **Deny wins** at every level, overriding any allow.
- Precedence: managed > CLI args > local project > shared project > user.
- Allowlist safe Bash (`Bash(npm run *)`) to cut approval fatigue; deny dangerous forms.
- `curl` / `wget` are not auto-approved — keep it that way.

## Hooks

- **PreToolUse** hooks run before permission prompts: can deny, force-ask, or auto-approve.
  Cannot bypass explicit deny/ask rules.
- **Stop** hooks gate turn-end on a verification script (tests/lint must pass).
- Use hooks for zero-exception rules: block force-push, block `.env` reads, auto-format,
  run tests. This is where policies 2/3/5/6/8 get real teeth.

## Injection & egress hardening

Prose alone ("treat fetched content as data" — safety.md) fails under direct injection.
The deterministic backstop lives here. **Native-first:** Claude Code already ships most of
this — configure the built-ins before writing a hook, and use hooks only for the two gaps
the built-ins leave. Drop-in config for everything below:
[`hooks/settings.injection-hardening.json`](../hooks/settings.injection-hardening.json).

**Use the native controls (deterministic, OS-enforced):**

- **Sandbox egress allowlist** — `sandbox.network.strictAllowlist: true` + `allowedDomains`
  denies every unlisted domain at the OS proxy, for *all* Bash commands, not just `curl`.
  This is the trifecta egress leg-break (threat-model.md) and the single strongest control
  here. Prefer it over a fetcher denylist.
- **WebFetch isolation** — fetched pages already run in a **separate context window** and are
  treated as data, not instructions. Scope which hosts are reachable with
  `WebFetch(domain:…)` allow rules. No rebuild needed; document that it exists.
- **MCP server lock** — `allowManagedMcpServersOnly` + OS `managed-mcp.json` pin the approved
  server set so a poisoned or renamed server can't be added silently.
- **Credential masking** — `sandbox.credentials.envVars[].mode: "mask"` gives sandboxed
  commands sentinel values; the real secret is injected only on allowed hosts (ties to
  secrets.md).
- **Lock it in managed settings** — `allowManagedPermissionRulesOnly`,
  `permissions.disableBypassPermissionsMode: "disable"` so no user/project scope relaxes it.

**Fill the two gaps native leaves — with hooks:**

- **Pipe-to-shell** (`curl … | bash`, `eval "$(curl …)"`, `bash <(curl …)`, pipe-to-interpreter):
  a permission glob can't express these, and they still bite when the sandbox is off.
  PreToolUse [`hooks/block-pipe-to-shell.sh`](../hooks/block-pipe-to-shell.sh) — exit 2 denies,
  hands the model the reason.
- **Invisible-character smuggling** in fetched content: WebFetch isolation does *not* strip
  Unicode Tags (U+E0000–E007F), zero-width, or bidi controls that hide instructions from a
  human reviewer. PostToolUse [`hooks/sanitize-fetched-content.py`](../hooks/sanitize-fetched-content.py)
  rewrites the tool output via `updatedToolOutput`, removing those classes before the model
  reads it, and leaves a visible breadcrumb of what it stripped. Fail-open (a parse error
  never breaks the turn).

**Still not native, still worth building** (roadmap, not shipped here): MCP tool-description
*drift* detection (SessionStart hash of tool schemas vs a committed baseline — the server
allowlist stops new servers but not a trusted one mutating its description), and a coarse
taint gate (PreToolUse `ask` on push/deploy/delete once the turn ingested untrusted content).

## Scope confinement (approval fatigue vs. blast radius)

Prompting on every `ls` trains the human to click "yes"; auto-allowing `ls` everywhere lets
an injected command read anything the user can. Resolve the tension by scoping on **path**,
not just on command name — something permission globs (`Bash(ls *)`) cannot express.
[`hooks/scope-bash.py`](../hooks/scope-bash.py) (PreToolUse, config in
[`hooks/settings.scope-bash.json`](../hooks/settings.scope-bash.json)):

- **allow** — allowlisted read-only / light file-op tools (`ls cat grep find mv cp mkdir rm`
  (non-recursive) `sed awk jq`, read-only `git`/`gh` subcommands, …) when *every* path argument,
  redirect target and `cd` resolves (symlinks followed) inside an in-scope root: the project
  dir, the session scratchpad, or `~/.claude`. Script execution is allowed only when the script
  itself lives in scratch space; code execution inside the project still prompts.
- **ask** — any path outside those roots. Forces a prompt even where a settings allow rule
  (e.g. `Bash(git pull *)`) would otherwise auto-approve.
- **no decision** (normal flow) — anything it cannot reason about: `$` expansion, backticks,
  `$(…)`, `<(…)`, unterminated heredocs, `sudo`, interpreters with inline code, unknown tools,
  sensitive paths (`.env*`, keys, `~/.claude/.local`, `.claude/wrappers`), and any **write**
  (redirect, `sed -i`, `tee`, `mv/cp/rm/touch/chmod`) to protected config: `.claude/`, `.git/`,
  `CLAUDE.md`, `.mcp.json`, shell rc files. Reads of those stay allowed; a hook that can
  rewrite its own settings is no guardrail.

Fail-closed: an unparseable command never yields *allow*. Other hooks' deny/ask outrank its
allow. Test matrix: [`hooks/tests/scope-bash.test.sh`](../hooks/tests/scope-bash.test.sh).

## Sandboxing

- OS-level sandbox (Seatbelt/macOS, bubblewrap/Linux) restricts Bash filesystem + network.
- Run untrusted/external scripts in a VM or container, not the host.

## Managed settings (teams)

- Admins deploy policy that user/project settings cannot override: permission rules, hooks,
  MCP allowlists, `disableBypassPermissionsMode`.
- Enable audit logging (OpenTelemetry) for compliance.

## Keep the doc layer thin

Over-specified CLAUDE.md causes the model to ignore rules. Keep `~/.claude/CLAUDE.md`
concise; push must-happen rules into hooks; keep this repo as reference, not as bulk
context to load wholesale.
