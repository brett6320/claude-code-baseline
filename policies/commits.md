# Policy 2 — Commits

## Rule

Never add "Co-Authored-By" attribution to Claude Code in commit messages.

## Why

Commit history is permanent and shared. Trailers crediting the tool are attribution
noise (see [attribution.md](attribution.md)).

## Timing

Commit only when the user asks. Do not auto-commit after edits.

## Enforcement

[`hooks/guardrails.sh`](../hooks/guardrails.sh) denies `git commit` with an attribution trailer
(policy 1) and denies `git commit` on `main`/`master` (policy 3). Commit timing is prose-only.

## Related

[attribution.md](attribution.md), [branching.md](branching.md).
