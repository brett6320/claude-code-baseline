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
- **OWASP Agentic Top 10** — adds goal hijacking, tool misuse, memory/context poisoning.
- **NIST AI RMF 1.0** (GOVERN/MAP/MEASURE/MANAGE) — <https://nvlpubs.nist.gov/nistpubs/ai/nist.ai.100-1.pdf>
- **NIST SP 800-218A** (SSDF for GenAI) — review all code, human or AI-generated.
- **NIST AI 600-1** (GenAI Profile) — confabulation, privacy, misuse risks.

## How our policies map

| Threat | Mitigating policy |
|--------|-------------------|
| Prompt injection | safety.md (data-not-instructions), enforcement.md (isolated context) |
| Secret disclosure | secrets.md, enforcement.md (deny `.env` reads) |
| Supply chain | scope-and-deps.md (slopsquatting), enforcement.md (CI hash pinning) |
| Excessive agency | safety.md (least privilege), merging.md, enforcement.md (permission tiers) |
| Improper output handling | verification-honesty.md, safety.md (input validation) |
