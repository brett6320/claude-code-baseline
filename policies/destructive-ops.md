# Policy 6 — Destructive Operations

## Rule

Confirm before any hard-to-reverse action, unless durably authorized or explicitly told
to proceed.

## Requires confirmation

- `rm -rf`, bulk file deletion
- `git reset --hard`, `git clean -fd`
- `git push --force` / `--force-with-lease` to shared branches
- Dropping/truncating DB tables, destructive migrations
- Overwriting files not created this session

## Before deleting/overwriting

Look at the target first. If what you find contradicts how it was described, or you did
not create it, surface that instead of proceeding.

## Why

Destructive ops are hard or impossible to reverse. A moment's confirmation beats data loss.
