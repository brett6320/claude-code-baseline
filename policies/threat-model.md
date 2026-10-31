# Policy 11 — Threat Model

Why the other policies exist. Frameworks for reasoning about agent risk.

## The lethal trifecta (Simon Willison)

An agent becomes an exfiltration pipeline when it simultaneously has all three:

1. Access to private data (repo, secrets, internal APIs)
2. Exposure to untrusted content (web pages, issues, PRs, file contents, tool output)
3. Ability to communicate externally (network calls, posting, outbound requests)

**Break at least one leg per session.** Remove network egress, or isolate untrusted
input, or scope away private data. Guardrails alone catch only a fraction of attacks —
structural removal of a leg is the reliable control.

## Environment > model (Anthropic)

Model-layer defenses (prompt rules, classifiers) are probabilistic and fail under direct
injection. Environment-layer containment (sandbox, permission deny rules) is deterministic.
Rely on the environment layer for anything that must not fail. See [enforcement.md](enforcement.md).

## Standards mapping

- **OWASP LLM Top 10** — LLM01 Prompt Injection, LLM02 Sensitive Info Disclosure,
  LLM03 Supply Chain, LLM05 Improper Output Handling, LLM06 Excessive Agency.
  <https://genai.owasp.org/llm-top-10/>
- **OWASP Agentic Security Initiative** (Top 10 for agentic apps, in progress) — adds goal
  hijacking, tool misuse, memory/context poisoning.
- **NIST AI RMF 1.0** (GOVERN/MAP/MEASURE/MANAGE) — <https://nvlpubs.nist.gov/nistpubs/ai/nist.ai.100-1.pdf>
- **NIST SP 800-218A** (SSDF for GenAI) — review all code, human or AI-generated.
- **NIST AI 600-1** (GenAI Profile) — confabulation, privacy, misuse risks.

## How our policies map

| Threat | Mitigating policy |
|--------|-------------------|
| Prompt injection | safety.md (data-not-instructions); enforcement.md: sandbox egress allowlist, `guardrails.sh` pipe-to-shell deny, `sanitize-fetched-content.py` on WebFetch/Read/MCP, WebFetch context isolation |
| Secret disclosure | secrets.md; enforcement.md: `Read(...)` denies, `guardrails.sh` shell-read deny, `sandbox.credentials.files`, `secret-leak-check.sh` ROTATED gate |
| Supply chain | scope-and-deps.md (slopsquatting, `permissions.ask` on installers); sandbox egress allowlist limits reachable registries |
| Excessive agency | safety.md (least privilege), merging.md, destructive-ops.md; enforcement.md: `scope-bash.py` path-scoped approvals, auto-mode prompts, `guardrails.sh` ask gates |
| Improper output handling | verification-honesty.md, safety.md (input validation), `sanitize-fetched-content.py` |
| Goal hijack / context poisoning | safety.md (fetched content is data); enforcement.md roadmap: MCP tool-description drift detection, taint gate |
