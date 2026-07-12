# Policy 3 — Branching

## Rule

Never commit directly to `main` or `master`. Always create a branch and open a PR,
unless the user explicitly instructs otherwise.

## Allowed without asking

- Create branches
- Push branches
- Open PRs
- Comment on PRs
- Trigger builds

## Requires explicit instruction

- Committing to a protected/default branch

## Why

Protected branches stay clean. Review happens in PRs. Mistakes stay isolated on a
branch.
