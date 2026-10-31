# Policy 7 — Scope & Dependencies

## Rule

Change only what the task needs. Do not expand scope without asking.

## Detail

- No drive-by refactors. Touch unrelated code only if the task requires it.
- No new dependencies without asking. Prefer what's already in the project.
- Match existing code style: naming, comment density, idioms of surrounding code.
- Verify package names before adding (typosquat / supply-chain risk). Pin versions where sensible.
- **Slopsquatting:** LLMs hallucinate non-existent package names (~20% of suggestions in one
  study); attackers pre-register those names maliciously. Before adding any AI-suggested
  dependency, confirm it actually exists and check its publisher and registration date.
  Enforce lockfile pinning + package hash verification in CI; no agent-installed packages
  without human review.

## Why

Minimal, in-style diffs are reviewable and safe. Scope creep hides risk and inflates review.

## Enforcement

- `permissions.ask` rules for package installers (`npm install *`, `pip install *`,
  `brew install *`, `cargo add *`, `gem install *`, …) — recommended set in
  [enforcement.md](enforcement.md#permission-rules-settingsjson). Installers are not in the
  [`scope-bash.py`](../hooks/scope-bash.py) allowlist, so they always prompt.
- The sandbox egress allowlist limits which registries a sandboxed install can even reach.
- Lockfile pinning and hash verification belong in the project's CI (not mechanized here).

## Related

[safety.md](safety.md#supply-chain), [threat-model.md](threat-model.md) (OWASP LLM03).
