# Claude Code Baseline Guardrails

Baseline rules for Claude Code across all projects. These are hard constraints, not
suggestions. When a rule here conflicts with a request, follow the rule and say so.

Source of truth for the currently-active versions lives in `~/.claude/CLAUDE.md`.
This document is the fuller rationale + reference.

Every policy file follows the same shape: **Rule → Detail → Why → Enforcement → Related.**
*Enforcement* names the hook or setting that mechanizes the rule, or says "prose-only".

## Index

**Dictated (local):**

| # | Policy | File | Enforced by |
|---|--------|------|-------------|
| 1 | Attribution | [policies/attribution.md](policies/attribution.md) | `guardrails.sh` |
| 2 | Commits | [policies/commits.md](policies/commits.md) | `guardrails.sh` |
| 3 | Branching | [policies/branching.md](policies/branching.md) | `guardrails.sh` |
| 4 | Merging | [policies/merging.md](policies/merging.md) | `guardrails.sh` |

**Best-practice baseline:**

| # | Policy | File | Enforced by |
|---|--------|------|-------------|
| 5 | Secrets & Credentials | [policies/secrets.md](policies/secrets.md) | `Read` denies, `guardrails.sh`, sandbox credentials, `secret-leak-check.sh` |
| 6 | Destructive Operations | [policies/destructive-ops.md](policies/destructive-ops.md) | `guardrails.sh`, `scope-bash.py` |
| 7 | Scope & Dependencies | [policies/scope-and-deps.md](policies/scope-and-deps.md) | `permissions.ask` on installers |
| 8 | Verification Honesty | [policies/verification-honesty.md](policies/verification-honesty.md) | prose-only (Stop hook: roadmap) |

**Operational safety:**

| # | Policy | File | Enforced by |
|---|--------|------|-------------|
| 9 | Operational Safety | [policies/safety.md](policies/safety.md) | sandbox, `guardrails.sh`, `sanitize-fetched-content.py`, `scope-bash.py` |
| 10 | Enforcement | [policies/enforcement.md](policies/enforcement.md) | — (how the above is wired) |
| 11 | Threat Model | [policies/threat-model.md](policies/threat-model.md) | — (why) |

**Process:**

| # | Policy | File | Enforced by |
|---|--------|------|-------------|
| 12 | Issue Tracking | [policies/issue-tracking.md](policies/issue-tracking.md) | prose-only |

## Tooling

Hooks live in [hooks/](hooks/); install to `~/.claude/hooks/` and wire via the settings
fragments. Tests in [hooks/tests/](hooks/tests/). Full inventory and precedence rules:
[policies/enforcement.md → Hooks](policies/enforcement.md#hooks).

- **[hooks/guardrails.sh](hooks/guardrails.sh)** — PreToolUse `Bash`: the policy-1–6/9 enforcer
  (attribution trailers, commits to main, shell reads of secrets, pipe-to-shell, destructive-op
  and merge prompts). Superset of `block-pipe-to-shell.sh`.
- **[hooks/scope-bash.py](hooks/scope-bash.py)** + [hooks/settings.scope-bash.json](hooks/settings.scope-bash.json)
  — PreToolUse `Bash`: path-scoped approvals. Auto-allows innocuous commands only inside the
  project / scratchpad / `~/.claude`; forces a prompt outside; never auto-allows code execution
  in the project or writes to Claude config.
- **Injection & egress hardening** — [hooks/settings.injection-hardening.json](hooks/settings.injection-hardening.json):
  sandbox egress allowlist + credential denies, plus
  - [hooks/block-pipe-to-shell.sh](hooks/block-pipe-to-shell.sh) — PreToolUse deny, POSIX-sh
    subset of `guardrails.sh` for installs that want injection hardening only;
  - [hooks/sanitize-fetched-content.py](hooks/sanitize-fetched-content.py) — PostToolUse on
    `WebFetch|Read|mcp__.*`: strips Unicode-Tags / zero-width / bidi smuggling;
  - [hooks/secret-leak-check.sh](hooks/secret-leak-check.sh) — PostToolUse: pauses the turn on a
    live-credential pattern until the user replies `ROTATED`.
- **[skills/update-guardrails](skills/update-guardrails/SKILL.md)** — `/update-guardrails`:
  fetches the latest policies from this repo and reconciles them into local config
  (diff → confirm → apply). Copy to `~/.claude/skills/` to install.

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
