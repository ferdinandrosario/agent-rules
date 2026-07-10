---
name: repo-naming
description: Audit and standardize script and documentation filenames in any repository so a brand-new contributor can tell each file's job from its name alone. Use when asked to rename scripts or docs, make filenames newcomer-friendly or self-explanatory, enforce or create a naming convention, fix inconsistent/misleading/snake_case filenames, or add a NAMING-CONVENTIONS.md. Runs a propose-first, STOP-gated audit → convention → rename → verify process using git mv and atomic Conventional Commits.
---

# Repo naming standardization

Make every script and Markdown filename in a repository self-explanatory to a
newcomer, lock the convention into durable artifacts (`NAMING-CONVENTIONS.md` +
the repo's agent-rules file), update every reference, and verify nothing broke.

## Operating rules (every phase)

- **Propose-first.** Never rename, edit, or create a file until the user
  approves. **STOP** where a phase says STOP and wait.
- **Renames use `git mv` only** — never delete + recreate. Nothing is ever
  deleted (preserves history and the executable bit).
- **Never execute the scripts** being renamed.
- **Diff-only output** — don't restate unchanged content.
- One **atomic commit per rename** = the move + every reference update, so each
  commit is self-consistent and bisectable.

## Process

### Phase 0 — Preconditions (read-only)
Confirm it's a git repo and the tree is **clean** (if dirty, STOP — ask the user
to commit/stash). Create/checkout a dedicated branch `chore/naming-conventions`.
Set `git config pull.rebase true` if unset. Report branch + status.

### Phase 1 — Audit (read-only)
List every `.sh`, `.md`, and any file that *names* scripts: `Makefile`,
`Rakefile`, `package.json` scripts, `Dockerfile`, `docker-compose*`, CI YAML
(`.github/workflows/**`), systemd units, crontabs. Read each script/doc's
header/purpose; summarize in **one line** what it actually does. Flag names that
are ambiguous, misleading, or confusable with a sibling. Output a table:
`path | one-line purpose | clear? (y/n) | problem`. Note references to scripts
that live **outside** the repo (deploy-server crontab/systemd) the user must fix
by hand.

### Phase 2 — Propose the convention (STOP)
Draft `NAMING-CONVENTIONS.md` covering the rules below, newcomer-friendly with a
short rationale + example per rule. **STOP for sign-off on the rules.**

### Phase 3 — Propose the rename map (STOP)
Apply the approved convention. Table: `old → new → reason`. For each rename list
**every** reference to update (other scripts, README, all docs, Makefile,
package.json, Dockerfile, compose, CI) and the proposed Conventional-Commit
message. Decide ambiguous names from the file's **contents**, never a guess.
**STOP for approval before touching any file.**

### Phase 4 — Execute (after approval)
`git mv` each file; update every reference; commit atomically per rename
(`refactor: rename OLD -> NEW`). Finalize `NAMING-CONVENTIONS.md`, verify its
examples match the renames actually performed, link it from the README, commit
`docs: add NAMING-CONVENTIONS.md`.

### Phase 5 — Durable artifacts
Add condensed **Naming conventions** + **Git workflow** sections to the repo's
agent-rules file (`AGENTS.md`/`CLAUDE.md`/`CONTRIBUTING.md`), linking the full
reference. Commit `docs: add naming + git rules to AGENTS.md`.

### Phase 6 — Consistency sweep + report
`git grep` each OLD name → confirm zero orphans. Verify every relative Markdown
link resolves, scripts that source other scripts point to valid paths, renamed
`.sh` kept their executable bit (`git ls-files -s` → `100755`), and the
convention doc + agent-rules agree. Report: files renamed, references updated,
links/exec-bits checked, commits made, external references the user must fix by
hand, anything still needing a human decision.

## Naming convention rules

**Scripts** — lowercase `kebab-case`, **verb-first**. The verb encodes
**lifecycle** (the usual source of confusion):
- *Run-once / idempotent:* `provision-` (create cloud infra: VM/instance/DB,
  off-box) · `bootstrap-` (configure a fresh host into the full architecture,
  on-box) · `setup-` (install deps/runtimes, on-box) · `migrate-`/`seed-`.
- *Repeatable / runtime:* `deploy-` (ship a release) · `run-` (foreground,
  blocks) · `start-` (background service) · `build-` · `backup-` · `check-`.
- A script spanning stages is named for its **end goal**.

**Target in the name, never implied** — environment (`-production`/`-staging`/
`-local`) + platform (`-aws`/`-ubuntu`/…) + topology (`-single-vm`/`-containers`/
`-nginx`/`-foreground`). Include **only what the script actually requires** —
don't bake in a platform it doesn't need (a VM-agnostic installer isn't `-ec2`).

**One concept = one word**, repo-wide. State the canonical term per concept and
don't mix synonyms (`digitalocean` not `do`; pick one of `single-vm`/
`single-box`). Don't reuse one verb for two jobs (`provision-` = create infra,
not also "install on the box" — that's `bootstrap-`).

**No abbreviation a newcomer wouldn't know.** Spell it out; allow only
industry-standard short forms (`aws db vm ssh tls api ip ci cd pg`).

**Markdown** — lowercase `kebab-case`, except all-caps landmark files
(`README` `CONTRIBUTING` `AGENTS` `CLAUDE` `SKILL` `NAMING-CONVENTIONS`,
`CODEOWNERS`) and tool-mandated names (`*.instructions.md`,
`pull_request_template.md`). A script and its dedicated runbook doc share the
same stem and are renamed together; topic docs that reference several scripts
keep their topic name.

**Directories** — in scope but higher-risk; propose separately, opt-in per
directory.

## Git workflow

- Branch `<type>/<kebab-desc>` (Conventional-Commit type).
- **Rebase, never merge;** `git pull --rebase`; keep `main` fast-forwarded.
- **Atomic commits;** one rename = `git mv` + all its reference updates in one
  commit. Conventional Commit subjects (`refactor: rename OLD -> NEW`).
- **Renames via `git mv` only;** verify zero orphans with `git grep` before
  committing.
- **Force-push:** `--force-with-lease` only, own feature branch only, only on an
  explicit force instruction — never shared history.
