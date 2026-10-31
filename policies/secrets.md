# Policy 5 — Secrets & Credentials

## Rule

Never print, commit, or log secrets, keys, tokens, passwords, or `.env` contents.

## Detail

- No hardcoded credentials. Read from environment or a secret store.
- Redact secrets in any output (`sk-...`, `ghp_...`, connection strings, etc.).
- Never write secrets into commit history, PRs, issues, or docs.
- If a secret is found already committed, flag it — do not silently propagate.
- **Shell env inheritance:** the agent inherits the full shell environment, so any exported
  secret (e.g. `AWS_SECRET_ACCESS_KEY`) propagates to every subprocess it spawns. Scope or
  scrub the environment before running the agent; don't export prod secrets into its shell.
- **Never reveal credentials to Claude itself**, not just to output/logs/history. If a task
  needs a credential value and would likely (or even possibly) expose it to the model — e.g.
  reading it into context, echoing it, passing it as a visible arg — write a wrapper script
  that performs the credentialed action without surfacing the raw value. Place wrappers in
  `.claude/wrappers/` in the project directory and exclude that path from version control
  (`.gitignore`).
- **Incident response — secret revealed/transmitted:** if a secret is revealed or transmitted
  anyway (printed, logged, sent), stop work immediately. Advise user to rotate the credential
  (do not restate its material). Do not resume work until user replies exact word `ROTATED`.

## Why

Secrets in output or history leak permanently. May be cached/indexed even if deleted.

## Enforcement

Layered, because no single control covers every tool (details in
[enforcement.md](enforcement.md#injection--egress-hardening)):

- **File tools** — `permissions.deny` `Read(...)` globs for `.env*`, `*.pem`, `id_rsa*`,
  `id_ed25519*`, `*.token`, `secrets/`, `~/.ssh/`, and credential-shaped files under
  `~/.claude/.local`; `blockReadsOutsideWorkingDirectories` blocks reads outside the project.
- **Shell** — `Read(...)` denies do *not* cover Bash. [`hooks/guardrails.sh`](../hooks/guardrails.sh)
  denies `cat`/`head`/`less`/… of dot-env and key files and prompts before a full `env` dump.
  [`hooks/scope-bash.py`](../hooks/scope-bash.py) never auto-allows a sensitive path.
- **Sandbox** — `sandbox.credentials.files` `deny` entries hide key files from every sandboxed
  command; the home directory is read-denied except listed sub-paths.
- **Incident gate** — PostToolUse [`hooks/secret-leak-check.sh`](../hooks/secret-leak-check.sh)
  blocks the turn when output matches a live-credential pattern and requires `ROTATED`.

## Related

[commits.md](commits.md) — history is permanent. [enforcement.md](enforcement.md),
[threat-model.md](threat-model.md) (private-data leg of the trifecta).
