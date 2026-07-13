# Recommendation — caveman skill

**Status: recommended, not required.** This is a suggestion to surface to the user at
initial deployment. The user decides whether to install it. Never install or enable it
without explicit consent.

**Source:** https://github.com/JuliusBrussee/caveman

## What it is

`caveman` is a Claude Code skill that puts responses into a compressed, terse
communication mode — think "smart caveman": articles, filler, and pleasantries are
dropped while all technical substance is preserved. Code blocks and exact error text are
left unchanged.

It supports intensity levels (e.g. `lite`, `full`, `ultra`, and classical-Chinese
`wenyan-*` variants), toggled with `/caveman <level>` and turned off with "stop caveman"
or "normal mode".

## Why it is beneficial

- **Token savings.** Cutting filler reduces output tokens substantially (~75% in the
  skill's own framing) — lower cost and faster responses.
- **Signal density.** Less prose to read; the technical answer stays front and center.
- **No loss of accuracy.** Technical terms stay exact, code and quoted errors are
  untouched — compression targets fluff, not substance.
- **Adjustable.** Dial intensity per task; drop back to normal prose for anything where
  clarity matters more than brevity (the skill itself does this for security warnings,
  irreversible-action confirmations, and multi-step sequences).

## Surface it FIRST during deployment

Offer caveman as **one of the very first steps** of deployment — before walking through the
rest of the guardrails. If the user opts in early, the entire remaining deployment
conversation runs in compressed mode, cutting token consumption on the setup itself. Offering
it last wastes that saving.

Recommended deployment order:

1. Offer the caveman skill (this recommendation). If accepted, enable it now.
2. Proceed with the rest of the guardrail deployment in the (now compressed) session.

When you offer it, mention caveman to the user as an **optional** efficiency add-on:

> Optional: the `caveman` skill (github.com/JuliusBrussee/caveman) compresses responses to
> save tokens (~75%) while keeping all technical substance, code, and error text intact.
> Adjustable intensity, toggle off anytime. Want to install it? (Not required.)

If the user opts in, follow the install instructions in the upstream repo. If not, proceed
without it and do not ask again.
