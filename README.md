# agent-rules template

Frozen snapshot of the **project-agnostic** AI-agent ruleset (universal
`AGENTS.md` rules, `CLAUDE.md` wiring, the `.claude/` skills + hooks +
token-efficiency command, and the `.github/` Copilot pointers). Originated
from `personal_manager` (2026-06-16). Cross-agent: Claude Code, Copilot,
Codex, Cursor, … all read the files this drops into the repo.

This is a **snapshot, not a live link** — stamping copies these files into
the new repo, which then diverges freely. Edits here do **not** propagate to
already-stamped repos (and vice-versa). Keep this template current by hand
when a universal rule earns a permanent change.

## What's project-agnostic (here, copied verbatim)

| File | Role |
|---|---|
| `AGENTS.md` | Universal rules: ROLE, ABSOLUTE RULES 1–13, output/doc/test/version/**validation** sections, forbidden list. **Single source of truth.** |
| `CLAUDE.md` | Thin Claude wrapper: `@AGENTS.md` + skill/hook wiring. |
| `.claude/skills/<dir>/SKILL.md` | Redirects Claude to each `<dir>/AGENTS.md`. |
| `.claude/skills/<lang>/SKILL.md` | Language how-to skills — `rails`,`ruby`→`backend/AGENTS.md`, `react`→`web/AGENTS.md`, `react-native`→`mobile/AGENTS.md`. Pruned with their codebase. |
| `.claude/hooks/no-todo.sh` | PostToolUse — **blocks** an edited code file containing `TODO`/`FIXME`. |
| `.claude/hooks/docs-with-code.sh` | Stop — **warns** when code changed but `docs/` didn't. |
| `.claude/settings.json` | Wires the two hooks + token-saving knobs (`autoCompactEnabled`, skill-listing caps, read-only-tool allow-list). |
| `.claude/commands/token-efficiency.md` | Token rules (AGENTS.md rule 7). |
| `.github/copilot-instructions.md` + `.github/instructions/<dir>.instructions.md` | GitHub Copilot pointers — root stub + path-scoped (`applyTo:`) redirects to each `<dir>/AGENTS.md`. Pruned with their codebase. |

## What's project-specific (author fresh per repo, NOT here)

- `AGENTS.md` → the `## STACK` block (exact pinned versions).
- `<dir>/AGENTS.md` — `backend/AGENTS.md`, `mobile/AGENTS.md`, `web/AGENTS.md`,
  `docs/AGENTS.md`: the per-codebase rulesets the SKILL redirects point at.
- `docs/` skeleton — at minimum the four pages `docs-with-code.sh` names:
  setup · architecture · running · troubleshooting.

## Stamp a new repo

No Claude required — `stamp.sh` does the mechanical part and prints the
authoring checklist. `<APP>` = the new repo's absolute path.

```sh
~/.claude/templates/agent-rules/stamp.sh "<APP>" [codebase ...]
# backend + docs are mandatory; web + mobile selectable.
# Default (no args) = full structure: backend web mobile docs
~/.claude/templates/agent-rules/stamp.sh "<APP>"          # full
~/.claude/templates/agent-rules/stamp.sh "<APP>" mobile   # backend mobile docs (no web)
~/.claude/templates/agent-rules/stamp.sh "<APP>" web      # backend web docs (no mobile)
```

Expected (default — full structure, nothing pruned):
```
✔ copied template core into <APP>
✔ docs-with-code.sh now watches: backend|web|mobile
```
…followed by the checklist below. Omitting a client prunes its skill +
Copilot files. The script refuses to run if `<APP>/AGENTS.md` already
exists, so a stamped repo can't be clobbered.

**What the script does (deterministic):** copies the core, deletes its own
`README.md`/`stamp.sh` from the target, removes each pruned codebase's skill
dir (its language how-to skills + Copilot instruction file too), and rewrites
the `docs-with-code.sh` watch list.

**What you author by hand (needs judgment — the script lists these):**

1. **`AGENTS.md`** — fill the `## STACK` block; delete any pruned codebase
   from the prose (STACK, "Per-codebase rules", TEST COVERAGE, VERSION).
2. **`CLAUDE.md`** — drop any pruned codebase from the skill list.
3. **`<dir>/AGENTS.md`** for each kept code codebase — port the convention
   skeleton. Quickest start is to copy the matching file from an existing
   app (`personal_manager`, `Fleet Management`) and adjust.
4. **`docs/`** — `docs/AGENTS.md` is included; the numbered `00-09` pages are
   written same-turn as the code they document (rule 5), not upfront.

## Verify the wiring fires

- Edit any `.rb` with a `# TODO` comment → `no-todo.sh` blocks the turn (exit 2).
- Change a file under `backend/` (or `mobile/`) without touching `docs/`, end
  the turn → `docs-with-code.sh` prints the ⚠ docs reminder.
