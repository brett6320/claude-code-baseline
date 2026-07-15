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

## Related

[commits.md](commits.md) — history is permanent.
