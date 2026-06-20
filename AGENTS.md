# AGENTS.md

Canonical, cross-agent instructions for this repo. Every AI coding
agent — Claude Code, GitHub Copilot, OpenAI Codex, Cursor, Aider,
Windsurf, Zed, Gemini CLI — reads the universal rules below, plus the
**nearest `AGENTS.md`** to the file being edited (`backend/`, `web/`,
`mobile/`, and `docs/` each have their own).

This file is the **single source of truth**. `CLAUDE.md` imports it;
the Copilot instruction files point to it; the per-codebase
`.claude/skills/*/SKILL.md` redirect to the matching `<dir>/AGENTS.md`.
Don't copy rules into those — edit them here (or in the per-codebase
file). Full layout + the pointer-integrity check: [docs/ai-agents.md](docs/ai-agents.md).

## ROLE

Senior staff full-stack engineer on a production-grade SaaS monorepo.
Prioritize **simplicity, maintainability, and clarity over cleverness**.

## STACK

```
backend/  → Rails 8.1 API (PostgreSQL + PostGIS, Rails defaults only — Solid Queue, Cache, Cable, Propshaft)
web/      → React 19 + Vite (JavaScript + incremental TypeScript) — Tailwind v4 + shadcn/ui
mobile/   → React Native + Expo SDK 56 (TypeScript) — NativeWind v4 + react-native-reusables
docs/     → source of truth (UI stack: docs/feature/ui.md)
```

## ABSOLUTE RULES (apply to every response)

1. **No invented requirements** — don't assume a fact you haven't
   verified. Confirm against the code, not against chat recollection.
   (Use the conversation as working state; just don't fabricate from it.)
2. **No TODOs, placeholders, or incomplete code.**
3. **No breaking existing structure.**
4. **All code must be immediately runnable.**
5. **Every change updates its docs *and* rules in the same response.**
   Code → its `docs/` page. A changed convention
   → the canonical `AGENTS.md` (or `<codebase>/AGENTS.md`), never a
   pointer. A pinned-version bump → rule 10's audit. Nothing ships
   half-documented — the change and its paperwork land together.
6. **No overengineering. No premature optimization.**
7. **Token efficiency** — apply the rules in
   `.claude/commands/token-efficiency.md` to every response (terse
   output, targeted edits, lean git ops, batched tool calls).
8. **Git — confirm before acting.** Mutating / remote-visible git
   needs explicit per-invocation user confirmation. `commit` is
   exempt — agents may stage (by exact path) and commit on the local
   branch autonomously. An explicit instruction in the task itself
   ("push this", "open a PR") counts as the per-invocation
   confirmation for that command — this is how remote / CI sessions
   work, where the user cannot confirm interactively. **PR merges
   always use "Rebase and merge"** — linear history; never a merge
   commit, never squash. Past approval does not carry over. Full
   command list in `.claude/commands/token-efficiency.md`.
9. **Test coverage — 100% target, 90% floor (backend: 100% mandatory).**
   See the TEST COVERAGE section below for the full statement.
10. **Version & stability — latest stable first (except the OS: latest
    Ubuntu LTS), never preview/RC/EOL.** Every
    version bump is documented everywhere, no exceptions: run the
    version-bump audit grep, update every match, and record old→new in
    the commit message. The bump is **not done** until the audit
    returns zero stale matches. See the VERSION & STABILITY section
    below for the full statement.
11. **Docs & comments — precise, concise, complete.** Write every doc
    and comment so a maintainer with zero context grasps it on first
    read, and so any future change can be made from the file alone —
    no AI, no chat history, no re-derivation. Capture the *why*, the
    inputs, and the constraints — not just the *what*.
12. **Verify load-bearing facts before quoting them.** Counts,
    versions, paths, thresholds, and feature inventories are checked
    against the live file *in the same turn* — never quoted from
    memory or chat. This is the active counterpart to rule 1: rule 1
    forbids inventing a fact, rule 12 requires confirming the ones you
    state. (A hard-coded "eleven features" that drifts to thirteen is
    the failure this prevents.)
13. **Validation — every feature validates at all three layers.** A
    feature that accepts user input validates on the backend (model
    validators are the source of truth), mirrors those rules inline on
    each client, and guards every file attachment. See the VALIDATION
    section below for the full statement.

## OUTPUT FORMAT (for substantive code changes)

Use these sections **when a response delivers or modifies code.** For
questions, lookups, and one-line fixes, skip the scaffolding and follow
the terse rules in `.claude/commands/token-efficiency.md` instead — a
trivial answer wearing five headers is the waste rule 7 forbids.

1. **ASSUMPTIONS**
2. **DESIGN DECISIONS**
3. **IMPLEMENTATION**
4. **DOCUMENTATION UPDATES**
5. **VERIFICATION STEPS**

## DOCUMENTATION (required on every change)

Update all affected sections: **setup · architecture · running · troubleshooting**.
Include exact commands, file paths, and expected outputs.

> Standard: a developer must be able to rebuild the feature from docs alone,
> with no chat history.

(Precise · concise · complete — the test in rule 11 above.)

`docs/` is the source of truth, numbered `00`–`10` plus per-feature
canonical files under `docs/feature/` (`feature/auth.md`,
`feature/ui.md`, `feature/task-planner.md`, …) and `FEATURES.md`. If
code and docs disagree, fix it in the same change. Change history
lives in git — write commit messages that carry the *why*. Full
feature-doc checklist:
[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

## TEST COVERAGE (rule, every codebase)

**Target: 100%** on every dimension the coverage tool measures
(lines, branches, functions, statements).
**Floor: 90%** on every dimension when 100% is not practical — e.g. a
third-party adapter shim, a native-module mock, or pure view glue
with no branchable logic. Whenever a dimension lands below 100% —
and especially while it is still under the 90% floor — document the
why in the matching `<codebase>/AGENTS.md` (one line).

**Backend has no floor — 100% line coverage is mandatory.**
`backend/spec/spec_helper.rb` enforces it via SimpleCov
(`minimum_coverage line: 100`); never lower that number. Missing
coverage means missing spec, not a threshold to relax.

**Web and mobile** carry the 100% target with the 90% floor on all
four dimensions. Enforcement lives in `web/jest.config.js` and
`mobile/jest.config.js`; where a dimension has not reached the floor
yet, its pin holds the **highest value the suite already clears** —
the pin is a ratchet, not the floor itself. Raise a pin only when
the suite clears the new value on that dimension; never lower one,
never red-CI the next commit; document each below-floor dimension's
why (one line) in the matching `<codebase>/AGENTS.md`. The current
snapshot of where each suite sits versus the 90% floor is the set of
pins in `web/jest.config.js` and `mobile/jest.config.js` — those
configs are the source of truth, not this file.

## VERSION & STABILITY (rule, every codebase)

Applies to every dependency, OS, and CI runner across `backend/`,
`web/`, `mobile/`, and `docs/`.

- **Latest stable first — except the OS.** Use the **latest stable
  production release** of every dependency, runtime, and tool — Node,
  Ruby, PostgreSQL, React, Vite, Expo, React Native, and the rest. The
  release line may be a "Current" line not yet promoted to LTS; that is
  allowed, but a prerelease never is. **The OS is the sole exception:
  use the latest Ubuntu LTS** (see the OS bullet) — its multi-year
  support window outweighs chasing a shorter-lived interim release on
  dev / CI / prod boxes. Never
  alpha/beta/rc/nightly/canary/preview/experimental/deprecated/EOL.
- **Pin deliberately, per manifest.** `Gemfile` pins exact (`= x.y.z`);
  `.ruby-version` / `backend/.ruby-version` pin exact; `.mise.toml`
  pins Ruby and Node exact. `package.json` stays inside one
  pinned major — web uses caret ranges, mobile uses the exact /
  tilde pins its Expo SDK requires — and the lockfile holds the exact
  resolution. Upgrade deliberately — one tool per PR, reason in the
  PR description.
- **OS — the exception to "latest stable": Ubuntu LTS only** (currently
  **26.04 LTS**) for Linux dev / containers / CI, because its ~5-year
  support window beats a 9-month interim release for a hosted service;
  macOS stable public release only for local dev and iOS CI; Xcode and
  Android Studio on stable channels only. CI may use
  `runs-on: ubuntu-latest` — that's the GitHub Actions label that
  tracks the current LTS automatically.
- **Compatibility pins** (e.g. `tailwindcss@3.4.17` because
  NativeWind v4 doesn't yet support Tailwind v4) require a one-line
  `why` next to the pin in the manifest.
- **Minimum footprint:** remove unused deps; reject duplicate-purpose
  libs; prefer official SDKs and framework defaults over third-party
  add-ons.
- **Version-bump audit (mandatory, religious — every pinned-version
  change):** a version string is intentionally repeated outside its
  manifest so a human or agent reads it without opening
  `Gemfile`/`package.json` — the **manifest is the source of truth**,
  the other copies exist for readability. The audit keeps them honest:
  after bumping a pinned tool or runtime, grep the **old** version
  string repo-wide, update every match in the same PR, and record
  old→new in the commit message. **The bump is not complete until the
  grep returns zero stale matches.** A pinned version touches root
  configs (`.ruby-version`, `.mise.toml`), `README.md`, the `AGENTS.md`
  files (root + per-codebase, which quote exact pins), the numbered
  docs (`01-prerequisites.md`, `09-deployment.md`,
  `github-actions-guide.md`), every `docs/feature/<feature>.md` that quotes it,
  and CI workflows — none of which fall under the per-codebase
  doc-update mappings on their own. The exact verification grep lives
  in [`docs/AGENTS.md`](docs/AGENTS.md) "Verification ritual".

Codebase-specific deltas (audit command, RN/Expo nightly bans,
pinning mechanics) live in the matching `<codebase>/AGENTS.md`. Don't
duplicate this universal block there.

## VALIDATION (rule, every feature that takes user input)

Validate at all three layers — never trust the client, never duplicate
the rule's source of truth:

- **Backend is the source of truth.** Model validators define the rule;
  the API returns a structured validation error (a typed envelope with
  per-field messages), never a bare 500. Controllers surface the model's
  errors — they don't re-implement them.
- **Clients mirror, inline.** Every client re-states the same rules for
  fast feedback and renders errors **inline next to the field** (never a
  toast/alert). Drive every client from one shared field schema so the
  copy can't drift.
- **Attachments are guarded.** Every upload is constrained by a max size
  and a MIME allow-list at the model layer — an unguarded
  `has_one_attached`/`has_many_attached` (or its client equivalent) is a
  bug.

The concrete mechanism (envelope shape, shared-schema name, the
attachment validator) is per-app — record it in the matching
`<codebase>/AGENTS.md` and the relevant `docs/` page.

## System-level installs (hand to the user)

When a task needs a **system / OS package** — Homebrew (`brew install …`),
`apt-get`, a system library, a runtime outside `mise`, or a Docker image —
the agent does **not** run it. These are slow, may need elevated permission,
and block the actual work. Instead the agent:

1. Gives the **exact copy-paste command(s)** up front, in order, noting the
   *one* package truly required (dependencies auto-resolve — don't list them
   as separate installs).
2. States the **verification command + expected output**.
3. Continues on everything that does not depend on the install (repo edits,
   code, docs) while the user runs it.

This covers machine/OS mutations only. **Repo-owned dependency manifests stay
the agent's job** — `Gemfile` + `bundle install`, `package.json` + `npm i`.
The test: *does it mutate the machine/OS or the repo?* Machine/OS → hand it
to the user.

## Per-codebase rules (nearest `AGENTS.md` wins)

Each codebase has its own `AGENTS.md` with rules that apply only there.
Agents that resolve the nearest file (Codex, Cursor, Gemini CLI, …)
load it automatically when editing that tree; Claude Code loads the
matching `.claude/skills/<dir>/SKILL.md`, which redirects to it.

- [`backend/AGENTS.md`](backend/AGENTS.md) — Rails API rules
- [`web/AGENTS.md`](web/AGENTS.md) — React + Vite rules
- [`mobile/AGENTS.md`](mobile/AGENTS.md) — Expo + RN rules
- [`docs/AGENTS.md`](docs/AGENTS.md) — `docs/`-only changes (numbering, feature checklist)

Seed data is modular per feature (`backend/db/seeds/<feature>.rb`); the
"touch a table, update its seed + doc in the same change" rule lives in
[`backend/AGENTS.md`](backend/AGENTS.md) and [`docs/seed-data.md`](docs/seed-data.md).

## Agent-specific entry points

Every agent ends up reading the rules above, but each discovers the
repo through its own file. All of these are **thin pointers** to this
`AGENTS.md` and the per-codebase ones — they hold no rules of their own:

- **Claude Code** — `CLAUDE.md` (`@AGENTS.md` import) + `.claude/skills/<dir>/SKILL.md` (redirect to `<dir>/AGENTS.md`); deterministic hooks in `.claude/`.
- **GitHub Copilot** — `.github/copilot-instructions.md` + `.github/instructions/<dir>.instructions.md` (`applyTo:`-scoped).
- **Codex / Cursor / Aider / Windsurf / Zed / Gemini CLI** — read this `AGENTS.md` and the nearest per-codebase one directly; no extra file needed.

Full mapping + the (minimal) pointer-integrity check:
[docs/ai-agents.md](docs/ai-agents.md). When you change a rule, change
it in the canonical `AGENTS.md` only — the pointers never need editing.

## Review

Before opening a backend PR, check the diff against the layer rules in
[`backend/AGENTS.md`](backend/AGENTS.md) — model/service/controller
boundaries, callback scoring, model size signals. Flag any violation in
the PR description even when you don't fix it in the same change.

## Universal forbidden

- Cross-codebase changes in a single commit. Backend, web, mobile each get
  their own commit even within one PR.
- Adding any dependency without a one-paragraph justification in the PR
  (what it does, why a stdlib/framework version doesn't cut it, version pin).
- `// TODO:` / `# TODO:` comments in any language. File an issue or do it now.
- Process orchestrators (overmind, foreman, concurrently). Four terminals
  is the deliberate choice — see `docs/05-running-locally.md`.
- Comments restating *what* the code does. Comments explain *why* only.
