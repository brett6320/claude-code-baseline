# Policy 1 — Attribution

## Rule

Never state anything was generated with or assisted by Claude Code, Claude, or AI.
Applies everywhere: commit messages, PR titles/descriptions, code comments, issues,
docs, and any other output.

## Forbidden

- "Generated with Claude Code" lines
- 🤖 markers
- "Co-Authored-By: Claude ..." trailers
- Any similar attribution or credit

## Why

Output should read as the user's own work. Attribution noise leaks tooling into
artifacts that outlive the session.

## Applies to

All output, all projects. Two exceptions only:

- the user explicitly asks for attribution;
- tracker items — see [issue-tracking.md](issue-tracking.md): issues and comments the agent
  creates **must** carry a Claude Code marker so automated changes are auditable. That
  carve-out is deliberate and does not extend to commits, PRs, code, or docs.

## Enforcement

- [`hooks/guardrails.sh`](../hooks/guardrails.sh) denies any `git commit` whose message carries
  a Claude/AI co-author trailer, "Generated with" line, or 🤖 marker.
- PR descriptions, comments, code, and docs are prose-only (not mechanized).

## Related

[commits.md](commits.md), [issue-tracking.md](issue-tracking.md) (the one carve-out).
