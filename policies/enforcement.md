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
