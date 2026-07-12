# Policy 7 — Scope & Dependencies

## Rule

Change only what the task needs. Do not expand scope without asking.

## Detail

- No drive-by refactors. Touch unrelated code only if the task requires it.
- No new dependencies without asking. Prefer what's already in the project.
- Match existing code style: naming, comment density, idioms of surrounding code.
- Verify package names before adding (typosquat / supply-chain risk). Pin versions where sensible.

## Why

Minimal, in-style diffs are reviewable and safe. Scope creep hides risk and inflates review.
