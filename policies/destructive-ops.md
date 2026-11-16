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

## Enforcement

- [`hooks/guardrails.sh`](../hooks/guardrails.sh) forces a prompt on any recursive `rm` (`-r`,
  `-R`, `--recursive`, with or without `-f`), `git reset --hard`, `git clean -f`, force pushes and
  merges. Exception: a lone `rm -r` whose every target resolves, with no symlink on the way, below
  `/tmp/claude-<uid>` (not the root itself, and not another session's scratchpad) is routine
  cleanup.
- [`hooks/scope-bash.py`](../hooks/scope-bash.py) never auto-allows recursive `rm` outside
  scratch space, writes to `.git/`, or any path outside the project / scratchpad.
- DB drops, destructive migrations, and overwrites of pre-existing files are prose-only.

## Related

[merging.md](merging.md), [safety.md](safety.md#rollback-readiness).
