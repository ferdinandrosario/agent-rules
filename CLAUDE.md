# CLAUDE.md

Claude Code entry point. The canonical, cross-agent rules live in
[`AGENTS.md`](AGENTS.md) and are imported below — keep rules there, not
here. This file adds only the Claude-Code-specific wiring.

@AGENTS.md

## Claude Code specifics

- **Per-codebase rules load on demand.** Editing a codebase triggers
  the matching skill in `.claude/skills/<dir>/SKILL.md`, which redirects
  to the canonical `<dir>/AGENTS.md` (`backend`, `web`, `mobile`,
  `docs`). Read that file before changing code in that tree.
- **Language how-to skills.** Best-practice / how-to questions (not
  directory edits) trigger `.claude/skills/<lang>/SKILL.md` — `rails`,
  `ruby`, `react`, `react-native`. Each is **two-layer**: the user-level
  generic skill (`~/.claude/skills/<lang>/`, deployed from this repo's
  `user-skills/`) carries the cross-app idioms, and the matching
  `<dir>/AGENTS.md` (`backend`/`web`/`mobile`) is the binding ruleset
  that **overrides** it on any conflict. `stamp.sh` prunes a language
  skill with its codebase.
- **Enforcement hooks** (deterministic, Claude-only) are wired in
  [`.claude/settings.json`](.claude/settings.json) → `.claude/hooks/`:
  - `no-todo.sh` — `PostToolUse`, **blocks** a just-edited code file
    that contains a `TODO`/`FIXME` comment (AGENTS.md "Universal forbidden").
  - `docs-with-code.sh` — `Stop`, **warns** when the tree has
    `backend`/`web`/`mobile` changes but no `docs/` change (AGENTS.md
    rule 5).
- **Token-efficiency rules** (AGENTS.md rule 7) are spelled out in
  [`.claude/commands/token-efficiency.md`](.claude/commands/token-efficiency.md).
  `.claude/settings.json` also sets token-saving knobs: `autoCompactEnabled`,
  `skillListingMaxDescChars`/`skillListingBudgetFraction` (cap how much context
  the skill listing burns), and a read-only `permissions.allow` list
  (`Read`/`Grep`/`Glob` + read-only git) so safe lookups don't prompt.

Other agents (Copilot, Codex, Cursor, …): see
[`AGENTS.md`](AGENTS.md) "Agent-specific entry points" and
[`docs/development/ai-agents.md`](docs/development/ai-agents.md).
