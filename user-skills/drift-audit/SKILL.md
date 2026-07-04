---
name: drift-audit
description: Audit a repository for drift between reality (code, configs, tooling) and what its documents, scripts, and skills claim, then fix only user-approved items. Use when asked to audit the repo, find stale or outdated docs, check docs/scripts/skills against the code, or produce a list of items to update or correct. Report-first — prioritized findings table, then STOP for approval before any fix.
---

# Drift audit — docs, scripts, skills vs reality

Find every place where a repository's documents, scripts, and skills have
drifted from what the code and tooling actually do; deliver a prioritized
fix list; apply only the items the user approves.

## Operating rules (both passes)

- **Report-first.** Pass 1 edits nothing — not even "obvious" typos. *Why:*
  an audit that fixes as it goes tends to "correct" docs toward what the
  code does even when the **code** is what's wrong; the human decides the
  direction of every fix.
- **Verify, don't assume.** Every finding cites evidence gathered this
  pass (`grep`/read of the live file) — never chat recollection, memory,
  or an earlier session.
- **Never execute** the scripts being audited — read them. Dry-run flags
  only with explicit user approval.
- The repo's own `AGENTS.md` (and nearest `<dir>/AGENTS.md`) is the
  binding ruleset — it **overrides** this skill on any conflict.

## Pass 1 — Audit (read-only)

Sweep four scopes. For every finding record the file, the evidence
(`path:line`), and the suggested fix.

### 1. Documents (`docs/`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`)

- Referenced file paths, commands, env vars, endpoints, and script names
  still exist — `grep` the tree, don't trust the prose.
- Version numbers (language, framework, packages) match the lockfiles
  (`Gemfile.lock`, `package-lock.json`, `.ruby-version`, …).
- Counts and inventories ("15 features", route tables, skill lists) match
  reality — recount, don't skim.
- **Every command shows its expected output**; a bare command is a finding.
- Setup/runbook steps still work in order — flag steps referencing removed
  or renamed files.
- Tuning/production tunables state **all three load tiers**
  (basic / mid / heavy); a single-value tunable is a finding.
- Every shipped feature has its canonical doc; flag features present in
  code but missing or stale in `docs/`.

### 2. Scripts (`script/`, `scripts/`, `bin/`, `*.sh`)

- Header states the plain-language purpose + where it runs (machine, user,
  directory).
- ✔/✖ success/failure logging with clear progress output; a silent script
  is a finding.
- Referenced paths, binaries, env vars, and hosts still exist.
- Dead ends both ways: scripts referenced nowhere, and docs referencing
  scripts that no longer exist.
- Filenames self-explanatory per the repo's `NAMING-CONVENTIONS.md`.
  Report naming findings here; a **systematic** rename effort is the
  `repo-naming` skill's job — recommend it rather than duplicating it.

### 3. Skills (`.claude/skills/`; in the template repo also `user-skills/`)

- The description matches what the body actually instructs.
- Paths, commands, and versions inside the skill are still valid.
- Triggers don't overlap or contradict a sibling skill.
- **Sync check:** shared skills exist as copies in the `agent-rules`
  template, each app repo, and `~/.claude/skills/`. `diff` this repo's
  copy against the canonical source; any divergence is a finding
  ("sync needed", with the direction the fix should flow).

### 4. Cross-cutting

- `AGENTS.md`/`CLAUDE.md` instructions contradicting the current code or
  each other.
- Stale `docs/todo.md` entries already done in code.
- Anything that would send a maintainer with zero context down a wrong path.

### Deliverable, then STOP

One table, sorted by priority:

| # | File | Type (doc/script/skill/config) | Problem | Evidence (`path:line`) | Suggested fix | Priority |

Priorities — **P1** wrong info that breaks a rebuild or a command ·
**P2** stale/incomplete info · **P3** style/polish (naming, logging
format, missing expected-output blocks). After the table, restate the
P1 items as a short numbered "fix first" list, then **STOP** and wait
for the item numbers to fix.

## Pass 2 — Fix (approved items only)

- Branch `chore/drift-audit-fixes` (or the branch the user names).
- **One atomic Conventional Commit per item**; a script or skill fix
  updates its matching doc in the same commit.
- When the **code** (not the doc) turns out to be wrong, say so and
  confirm the direction before "fixing" the doc to match a bug.
- A shared-skill fix flows **canonical source → every copy** (template,
  each app repo, `~/.claude/skills/`) in the same turn.
- Report per item with ✔/✖ and a diff summary; re-verify each fixed
  doc's commands and paths before closing the item.
