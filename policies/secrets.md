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

## Why

Secrets in output or history leak permanently. May be cached/indexed even if deleted.

## Related

[commits.md](commits.md) — history is permanent.
