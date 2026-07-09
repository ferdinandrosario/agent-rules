# agent-rules template

Frozen snapshot of the **project-agnostic** app scaffold: the AI-agent
ruleset (universal `AGENTS.md` rules, `CLAUDE.md` wiring, the naming
convention, the `.claude/` skills + hooks + token-efficiency command, the
`.github/` Copilot pointers), the CI suite (per-codebase workflows,
docs-links, agents-pointers, secrets-guard, Dependabot, PR template,
CODEOWNERS), the `Makefile` test front door, `scripts/check-doc-links.rb`,
and the shipped `docs/` pages. Originated from `personal_manager`
(2026-06-16). Cross-agent: Claude Code, Copilot, Codex, Cursor, … all
read the files this drops into the repo.

This is a **snapshot, not a live link** — stamping copies these files into
the new repo, which then diverges freely. Edits here do **not** propagate to
already-stamped repos (and vice-versa). Keep this template current by hand
when a universal rule earns a permanent change.

## What's project-agnostic (here, copied verbatim)

| File | Role |
|---|---|
| `AGENTS.md` | Universal rules: ROLE, ABSOLUTE RULES 1–13, output/doc/test/version/**validation** sections, forbidden list. **Single source of truth.** |
| `CLAUDE.md` | Thin Claude wrapper: `@AGENTS.md` + skill/hook wiring. |
| `docs/development/naming-conventions.md` | Full reference for naming scripts & docs — verb-first `kebab-case`, lifecycle prefixes, per-concept canonical terms, the rename ritual. Condensed in `AGENTS.md` "Naming conventions". |
| `.claude/skills/<dir>/SKILL.md` | Redirects Claude to each `<dir>/AGENTS.md`. |
| `.claude/skills/<lang>/SKILL.md` | Language how-to skills (`rails` `ruby` `react` `react-native`) — two-layer pointers: the user-level generic skill (`~/.claude/skills/<lang>/`, deployed from `user-skills/`) for cross-app idioms, and the matching `<dir>/AGENTS.md` as the binding override on any conflict. Pruned with their codebase. |
| `user-skills/<skill>/SKILL.md` | **Canonical source of the user-level generic skills** — the four language skills (layered best practices, beginner → staff) plus the `drift-audit` process skill. Not stamped into repos — deployed to `~/.claude/skills/` (see below). |
| `.claude/skills/repo-naming/SKILL.md` | Redirects Claude to `docs/development/naming-conventions.md` + `AGENTS.md` for any rename/standardize-filenames task. Not a codebase skill — survives pruning. |
| `.claude/skills/drift-audit/SKILL.md` | Thin pointer to the user-level `drift-audit` skill — report-first audit of docs/scripts/skills vs reality (findings table → STOP → fix approved items). Not a codebase skill — survives pruning. |
| `.claude/hooks/no-todo.sh` | PostToolUse — **blocks** an edited code file containing `TODO`/`FIXME`. |
| `.claude/hooks/docs-with-code.sh` | Stop — **warns** when code changed but `docs/` didn't. |
| `.claude/settings.json` | Wires the two hooks + token-saving knobs (`autoCompactEnabled`, skill-listing caps, read-only-tool allow-list). |
| `.claude/commands/token-efficiency.md` | Token rules (AGENTS.md rule 7). |
| `.github/copilot-instructions.md` + `.github/instructions/<dir>.instructions.md` | GitHub Copilot pointers — root stub + path-scoped (`applyTo:`) redirects to each `<dir>/AGENTS.md`. Pruned with their codebase. |
| `.github/workflows/` | The CI suite: per-codebase CI (`backend.yml`, `web.yml`, `mobile.yml` — pruned with their codebase), `docs-links.yml` (runs the doc checker), `agents-pointers.yml` (pointer integrity), `secrets-guard.yml` (no tracked secrets). App-code workflows carry a template-only `if:` guard so they skip on this repo; `stamp.sh` strips it. |
| `.github/dependabot.yml` | Weekly dependency PRs for bundler + npm + github-actions; `<web>`/`<mobile>` marker comments let `stamp.sh` prune entries with their codebase. |
| `.github/pull_request_template.md` + `.github/CODEOWNERS` | The PR checklist that mirrors AGENTS.md's rules, and the catch-all review owner. |
| `Makefile` | Uniform test front door (`make test`, `make test-<codebase>`, `make test-coverage`); pruned targets follow their codebase. |
| `scripts/check-doc-links.rb` | Broken-link + orphan check over tracked markdown (run by `docs-links.yml`). Ships with `ORPHAN_ROOTS` = `docs/README.md` and an `AUTHORED_PER_APP` allowlist for the four per-app `AGENTS.md` targets. |
| `docs/` (shipped pages) | `README.md` (topic-folder index), `CONTRIBUTING.md` (feature-doc checklist), `todo.md`, `development/ai-agents.md`, `development/naming-conventions.md`, `development/github-actions.md`. Everything else is authored as the app grows. |

## What's project-specific (author fresh per repo, NOT here)

- `AGENTS.md` → the `## STACK` block (exact pinned versions).
- `<dir>/AGENTS.md` — `backend/AGENTS.md`, `mobile/AGENTS.md`, `web/AGENTS.md`,
  `docs/AGENTS.md`: the per-codebase rulesets the SKILL redirects point at.
- `docs/` topic pages beyond the shipped ones — at minimum the four areas
  `docs-with-code.sh` names: setup · architecture · running ·
  troubleshooting; the full layout is indexed in `docs/README.md`.
- Deploy / CD workflows — deployment is per-app infrastructure (target
  host, container platform, secrets model); author them when the deploy
  story exists.

## User-level generic skills (`user-skills/` → `~/.claude/skills/`)

The generic skills every repo's thin pointers reference — the four
language skills plus `drift-audit` — live here so they are versioned; the
live copies Claude actually loads sit in `~/.claude/skills/`. After
editing one under `user-skills/`, deploy it:

```sh
cp -R ~/Downloads/agent-rules/user-skills/. ~/.claude/skills/
diff -rq ~/Downloads/agent-rules/user-skills ~/.claude/skills | grep -v "Only in $HOME/.claude/skills"
# expected: no output — every versioned skill matches its deployed copy
# (repo-naming lives only in ~/.claude/skills + per-repo, hence the grep -v)
```

Edit in this repo first, then deploy — never edit `~/.claude/skills/`
directly, or the change is unversioned and dies with the machine.

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
✔ stripped template-only CI guards
✔ cleaned Dependabot prune markers
✔ docs-with-code.sh now watches: backend|web|mobile
```
…followed by the checklist below. Omitting a client also prints a `✔ pruned`
line each for its skill, Copilot instructions, CI workflow, Dependabot
entry, and Makefile targets. The script refuses to run if `<APP>/AGENTS.md`
already exists, so a stamped repo can't be clobbered.

**What the script does (deterministic):** copies the core; deletes the
template-only files (`README.md`, `stamp.sh`) and dirs (`.git`,
`user-skills/`) from the target; removes each pruned codebase's skill dir
(its language how-to skills + Copilot instruction file too), CI workflow,
Dependabot entry, and Makefile targets; strips the template-only CI guard
lines; and rewrites the `docs-with-code.sh` watch list.

**What you author by hand (needs judgment — the script lists these):**

1. **`AGENTS.md`** — fill the `## STACK` block; delete any pruned codebase
   from the prose (STACK, "Per-codebase rules", TEST COVERAGE, VERSION).
2. **`CLAUDE.md`** — drop any pruned codebase from the skill list.
3. **`<dir>/AGENTS.md`** for each kept code codebase — port the convention
   skeleton. Quickest start is to copy the matching file from an existing
   app (`personal_manager`, `Fleet Management`) and adjust.
4. **`docs/`** — author `docs/AGENTS.md` too (not shipped); the topic-folder
   pages beyond the shipped ones (see `AGENTS.md` "DOCUMENTATION" and the
   `docs/README.md` index) are written same-turn as the code they document
   (rule 5), not upfront.

## Verify the wiring fires

- Edit any `.rb` with a `# TODO` comment → `no-todo.sh` blocks the turn (exit 2).
- Change a file under `backend/` (or `mobile/`) without touching `docs/`, end
  the turn → `docs-with-code.sh` prints the ⚠ docs reminder.
