---
name: drift-audit
description: Use when auditing this repo for drift — stale docs, scripts, or skills that no longer match the code — checking documentation against reality, or producing a list of items to update or correct. Report-first — findings table, then STOP for approval before fixing.
---

# Drift audit — this repo

The full process — read-only audit → prioritized findings table →
**STOP** → fix only approved items — lives in the user-level skill
(`~/.claude/skills/drift-audit/SKILL.md`, versioned in the `agent-rules`
template's `user-skills/drift-audit/`). **Read it before auditing.**

Run it against this repo's authorities:

- [`AGENTS.md`](../../../AGENTS.md) — the binding ruleset; **overrides**
  the generic skill on any conflict.
- `docs/` is the source of truth for feature behavior; a code ↔ docs
  disagreement is always a finding.
- Shared `.claude/skills/` are synced copies (template + apps): any
  divergence is a finding, and a fix flows canonical → every copy in the
  same turn.

Universal rules: [`AGENTS.md`](../../../AGENTS.md).
