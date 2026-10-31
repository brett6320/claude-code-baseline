# Policy 12 — Issue Tracking

Applies when **either** is true:

- the project uses an issue tracker (Jira, Linear, GitHub Issues, etc.), **or**
- issue tracking is set as a global preference (a tracker is designated in the user's global
  config, to be used across projects).

If either holds, this policy is in force for the work at hand.

## Rule

- **Create an issue before any change to a live system.** No change to a live/production
  system without a tracking issue first — no exceptions.
- **Order is critical: the issue MUST exist before the change is made.** Not concurrently,
  not after. Issue first, then the change. If you catch yourself about to touch a live system
  with no issue open, stop and create it first.
- **Always keep the issue status updated** as work progresses.
- When implementation is complete, move the status to **in-review** — pending unit testing
  or human approval. Do not mark it done; a human closes it.

## Attribution (carve-out from [attribution.md](attribution.md))

- Issues and comments created by the agent **must** carry attribution that they were
  created by Claude Code.
  - Issue: apply the "Claude Code" label (or equivalent marker the tracker supports).
  - Comments: append a footer line, e.g. `🤖 _Comment by Claude Code_`.
- This is the deliberate exception to Policy 1 (no attribution). Tracker items are the one
  place attribution is required, so ownership of automated changes is auditable.

## Updates go in comments

- **Do not modify the issue body to track progress.** The body is the original description.
- Record all progress, decisions, and status notes as **comments**, preserving a chronological
  trail.

## Why

The tracker is the audit log and the human-in-the-loop gate. An issue-first workflow means no
live change is untracked; status discipline keeps reviewers informed; comment-only updates keep
the history intact and the original ask unaltered.

## Enforcement

Prose-only (tracker APIs differ). The MCP/tracker tools are gated by normal permissions; the
"issue first" ordering is a model-layer rule.

## Related

[attribution.md](attribution.md) (this is its one carve-out), [safety.md](safety.md#audit-trail).
