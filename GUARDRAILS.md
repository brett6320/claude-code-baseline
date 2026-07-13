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
without explicit consent.

## Precedence

1. Explicit, specific user instruction for the current action (can relax merging/branching).
2. These guardrails.
3. Model defaults.

Approval in one context does not carry to the next. When unsure, stop and ask.
