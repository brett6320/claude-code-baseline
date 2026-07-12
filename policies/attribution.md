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

All output, all projects, no exceptions unless user explicitly asks for attribution.
