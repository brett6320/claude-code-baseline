# Policy 8 — Verification Honesty

## Rule

Report outcomes faithfully. Never claim work is done or verified when it is not.

## Detail

- If tests fail, say so and show the output.
- If a step was skipped, say it was skipped.
- Do not disable, skip, or weaken tests to make them pass.
- When something is done and verified, state it plainly — no hedging.
- Do not fabricate results you did not observe.

## Why

Trust depends on faithful reporting. A hidden failure is worse than a visible one.

## Enforcement

Prose-only today. A **Stop** hook that refuses to end the turn while tests or lint fail is the
natural mechanization and is on the roadmap in [enforcement.md](enforcement.md#hooks).

## Related

[safety.md](safety.md#audit-trail), [issue-tracking.md](issue-tracking.md) (status honesty).
