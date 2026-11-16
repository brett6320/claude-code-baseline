# Policy 4 — Merging

## Rule

Never merge a PR or branch unless the user explicitly instructs it for that specific PR.

## Detail

- Creating branches, pushing, opening PRs, commenting, triggering builds — fine without asking.
- Merging — not fine. Requires explicit, per-PR instruction.
- Approval to merge one PR does NOT extend to any other PR.

## Default behavior

Leave PRs open. Report status. Wait for an explicit merge instruction.

## Why

Merging is hard to reverse and outward-facing. It is the user's call, every time.

## Enforcement

[`hooks/guardrails.sh`](../hooks/guardrails.sh) forces a prompt on `git merge` (including
`git -C <dir> merge` and quoted forms) and `gh pr merge`. The prompt comes from a hook `ask`, so
it fires whether or not the command runs sandboxed — `autoAllowBashIfSandboxed` does not skip it
([enforcement.md](enforcement.md#permission-rules-settingsjson)).

## Related

[branching.md](branching.md), [safety.md](safety.md#human-in-loop-gates).
