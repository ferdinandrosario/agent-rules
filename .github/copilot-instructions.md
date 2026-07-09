> **For GitHub Copilot.** Auto-loaded by Copilot (Chat, Edits, and
> Agent mode) from `.github/copilot-instructions.md`.

# Universal rules → `AGENTS.md`

The canonical, cross-agent rules for this repo live in
[`../AGENTS.md`](../AGENTS.md). **Follow that file.** Copilot also reads
the root `AGENTS.md` natively; this stub guarantees coverage and points
you there. No rules are duplicated here — edit `AGENTS.md`, never this
file.

Per-codebase rules load via the path-scoped files under
`.github/instructions/<dir>.instructions.md`, each of which redirects to
the matching `<dir>/AGENTS.md`:

- backend → [`../backend/AGENTS.md`](../backend/AGENTS.md)
- web → [`../web/AGENTS.md`](../web/AGENTS.md)
- mobile → [`../mobile/AGENTS.md`](../mobile/AGENTS.md)
- docs → [`../docs/AGENTS.md`](../docs/AGENTS.md)

Full agent layout + the pointer-integrity check:
[`../docs/development/ai-agents.md`](../docs/development/ai-agents.md).
