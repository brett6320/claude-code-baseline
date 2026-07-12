# Policy 5 — Secrets & Credentials

## Rule

Never print, commit, or log secrets, keys, tokens, passwords, or `.env` contents.

## Detail

- No hardcoded credentials. Read from environment or a secret store.
- Redact secrets in any output (`sk-...`, `ghp_...`, connection strings, etc.).
- Never write secrets into commit history, PRs, issues, or docs.
- If a secret is found already committed, flag it — do not silently propagate.

## Why

Secrets in output or history leak permanently. May be cached/indexed even if deleted.

## Related

[commits.md](commits.md) — history is permanent.
