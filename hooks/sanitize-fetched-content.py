#!/usr/bin/env python3
"""PostToolUse hook — strip invisible-character injection vectors from tool output.

Claude Code isolates WebFetch in a separate context and treats fetched text as data,
but it does NOT strip Unicode characters that smuggle instructions past a human reviewer.
This closes that gap: it rewrites the tool's returned content, removing the character
classes an indirect-injection payload hides in, before the model reads it.

Stripped:
  - Unicode Tags block            U+E0000-U+E007F  (invisible; the classic tag-smuggling channel)
  - Zero-width / joiners          U+200B-U+200D, U+2060, U+FEFF
  - Bidirectional controls        U+200E, U+200F, U+202A-U+202E, U+2066-U+2069
  - Soft hyphen                   U+00AD

Contract (Claude Code PostToolUse):
  stdin  = event JSON with `tool_response` (the tool's result).
  stdout = {"hookSpecificOutput": {"hookEventName": "PostToolUse",
            "updatedToolOutput": <sanitized tool_response>}}
  PostToolUse cannot block (the tool already ran); this only rewrites content.

Fail-open by design: a malformed event or parse error exits 0 with no output — the
worst case is unsanitized content, i.e. the same as not having the hook. It never
breaks the session. Wire it to WebFetch (and optionally MCP tools) in settings.json.
"""
import json
import re
import sys

# One codepoint set, compiled once. Ranges are inclusive.
_STRIP = re.compile(
    "["
    "­"              # soft hyphen
    "​-‏"       # zero-width space/joiners + LRM/RLM
    "⁠"              # word joiner
    "‪-‮"       # bidi embeddings/overrides
    "⁦-⁩"       # bidi isolates
    "﻿"              # zero-width no-break space / BOM
    "\U000e0000-\U000e007f"  # Unicode Tags block
    "]"
)

_removed = 0


def scrub(value):
    """Recursively strip invisible chars from every string in a JSON value."""
    global _removed
    if isinstance(value, str):
        cleaned = _STRIP.sub("", value)
        _removed += len(value) - len(cleaned)
        return cleaned
    if isinstance(value, list):
        return [scrub(v) for v in value]
    if isinstance(value, dict):
        return {k: scrub(v) for k, v in value.items()}
    return value


def main():
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # fail open — never break the turn

    if "tool_response" not in event:
        sys.exit(0)

    cleaned = scrub(event["tool_response"])
    if _removed == 0:
        sys.exit(0)  # nothing hidden — leave output untouched

    # Leave a visible breadcrumb so the model (and transcript) show sanitization happened.
    note = f"\n\n[guardrails: removed {_removed} invisible/bidi character(s) from fetched content]"
    if isinstance(cleaned, str):
        cleaned += note
    elif isinstance(cleaned, dict):
        cleaned.setdefault("_guardrails_note", note.strip())

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "updatedToolOutput": cleaned,
            }
        },
        sys.stdout,
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
