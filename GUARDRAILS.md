# Claude Code Baseline Guardrails

Baseline rules for Claude Code across all projects. These are hard constraints, not
suggestions. When a rule here conflicts with a request, follow the rule and say so.

Source of truth for the currently-active versions lives in `~/.claude/CLAUDE.md`.
This document is the fuller rationale + reference.

## Index

**Dictated (local):**

| # | Policy | File |
|---|--------|------|
| 1 | Attribution | [policies/attribution.md](policies/attribution.md) |
| 2 | Commits | [policies/commits.md](policies/commits.md) |
| 3 | Branching | [policies/branching.md](policies/branching.md) |
| 4 | Merging | [policies/merging.md](policies/merging.md) |

**Best-practice baseline:**

| # | Policy | File |
|---|--------|------|
| 5 | Secrets & Credentials | [policies/secrets.md](policies/secrets.md) |
| 6 | Destructive Operations | [policies/destructive-ops.md](policies/destructive-ops.md) |
| 7 | Scope & Dependencies | [policies/scope-and-deps.md](policies/scope-and-deps.md) |
| 8 | Verification Honesty | [policies/verification-honesty.md](policies/verification-honesty.md) |

**Operational safety:**

| # | Policy | File |
|---|--------|------|
| 9 | Operational Safety | [policies/safety.md](policies/safety.md) |
| 10 | Enforcement | [policies/enforcement.md](policies/enforcement.md) |
| 11 | Threat Model | [policies/threat-model.md](policies/threat-model.md) |

## Tooling

- **Injection & egress hooks** (policies 9/11) — native-first config in
  [hooks/settings.injection-hardening.json](hooks/settings.injection-hardening.json):
  - [hooks/block-pipe-to-shell.sh](hooks/block-pipe-to-shell.sh) — PreToolUse deny:
    blocks `curl|bash`, `eval "$(curl …)"`, `bash <(curl …)`, pipe-to-interpreter.
  - [hooks/sanitize-fetched-content.py](hooks/sanitize-fetched-content.py) — PostToolUse on
    `WebFetch|Read|mcp__.*`: strips Unicode-Tags / zero-width / bidi smuggling from tool output
    (the gap WebFetch context-isolation leaves; Read and MCP have no isolation).
  - [hooks/secret-leak-check.sh](hooks/secret-leak-check.sh) — PostToolUse: pauses the turn on a
    live-credential pattern in tool output until the user replies `ROTATED` (policy 5).
- **Scope confinement** (policy 10) — [hooks/scope-bash.py](hooks/scope-bash.py) +
  [hooks/settings.scope-bash.json](hooks/settings.scope-bash.json): PreToolUse hook that
  auto-allows innocuous commands (`ls cat mv grep`, read-only `git`, …) only when every path is
  inside the project / scratchpad / `~/.claude`; forces a prompt for paths outside; falls through
  for code execution and anything unparseable. Tests: [hooks/tests/scope-bash.test.sh](hooks/tests/scope-bash.test.sh).
- **[skills/update-guardrails](skills/update-guardrails/SKILL.md)** — `/update-guardrails`
  skill: fetches the latest policies from this repo and reconciles them into local config
  (diff → confirm → apply). Copy to `~/.claude/skills/` to install.

**Process:**

| # | Policy | File |
|---|--------|------|
| 12 | Issue Tracking | [policies/issue-tracking.md](policies/issue-tracking.md) |

## Recommendations (optional, not required)

| Recommendation | File |
|----------------|------|
| caveman skill — token-efficient responses | [recommendations/caveman.md](recommendations/caveman.md) |

Surface these to the user at initial deployment as optional add-ons. Never install or enable
without explicit consent. **Offer the caveman skill first** — before deploying the rest — so,
if accepted, the remaining deployment runs in compressed mode and consumes fewer tokens.

## Precedence

1. Explicit, specific user instruction for the current action (can relax merging/branching).
2. These guardrails.
3. Model defaults.

Approval in one context does not carry to the next. When unsure, stop and ask.
