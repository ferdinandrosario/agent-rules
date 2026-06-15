# agent-rules

A reusable, **cross-agent** AI coding ruleset you can stamp into any new
project in one command — so every repo you start inherits the same
conventions without you rewriting (or an AI re-deriving) them each time.

Originally extracted from the `personal_manager` monorepo (2026-06-16);
the design target is a Rails API + React Native (and optionally React web)
SaaS app, but the universal rules are stack-agnostic.

---

## The model: cross-agent + per-project snapshot

**Cross-agent.** The rules live in plain `AGENTS.md` files — the format
Claude Code, Codex, Cursor, Aider, Gemini CLI, and other coding agents all
read. `CLAUDE.md` is a thin wrapper that imports `AGENTS.md` (`@AGENTS.md`)
and adds Claude-only wiring (skills + enforcement hooks). One source of
truth, every agent honors it.

**Per-project snapshot, not a live link.** Stamping *copies* these files
into the new repo, which then diverges freely. Edits here do **not**
propagate to already-stamped repos, and vice-versa. The trade: each repo is
self-contained and can diverge per project; the cost is that a universal
rule change must be re-applied to each repo by hand. (Chosen deliberately
over a shared/imported base, which other agents can't resolve from outside
the repo anyway.)

**Two layers.** Everything in this repo is the **project-agnostic core**.
Each new project adds its own **delta** (the exact stack, the per-codebase
rules, the docs). The stamp does the core; you author the delta.

---

## What's in here (the agnostic core, copied into every new repo)

| File | Role |
|---|---|
| `AGENTS.md` | Universal rules: ROLE, ABSOLUTE RULES 1–12, output/doc/test/version sections, forbidden list. **Single source of truth.** Ships the full `backend`+`web`+`mobile` superset; `stamp.sh` + the checklist prune what an app doesn't use. |
| `CLAUDE.md` | Thin Claude wrapper: `@AGENTS.md` + skill/hook wiring. |
| `.claude/skills/<dir>/SKILL.md` | Redirects Claude to each `<dir>/AGENTS.md` (backend, web, mobile, docs). |
| `.claude/hooks/no-todo.sh` | `PostToolUse` — **blocks** an edited code file containing a `TODO`/`FIXME`. |
| `.claude/hooks/docs-with-code.sh` | `Stop` — **warns** when code changed but `docs/` didn't. |
| `.claude/settings.json` | Wires the two hooks. |
| `.claude/commands/token-efficiency.md` | Token rules (AGENTS.md rule 7). |
| `stamp.sh` | Bootstraps a new repo from this core (see below). |

## What you author per project (the delta — NOT in here)

- `AGENTS.md` → the `## STACK` block (exact pinned versions).
- `<dir>/AGENTS.md` — `backend/AGENTS.md`, `mobile/AGENTS.md`, `web/AGENTS.md`,
  `docs/AGENTS.md`: the per-codebase rulesets the SKILL redirects point at.
  Fastest start is to copy one from an existing app and adjust.
- `docs/` pages — written same-turn as the code they document (rule 5), not
  upfront.

---

## Stamp a new repo (no Claude required)

`stamp.sh` does the deterministic part and prints the authoring checklist.
`<APP>` = the new repo's absolute path.

```sh
./stamp.sh "<APP>" [codebase ...]
# codebases default to:  backend mobile docs   (i.e. no web)
# Rails + React Native:  ./stamp.sh "/path/to/New App"
# add a web client:      ./stamp.sh "/path/to/New App" backend web mobile docs
```

(The local working copy at `~/.claude/templates/agent-rules/stamp.sh` works
identically — see "Keeping copies in sync" below.)

Expected output (default codebases):

```
✔ copied template core into <APP>
✔ pruned skill: web
✔ docs-with-code.sh now watches: backend|mobile
────────────────────────────────────────────────────────────────────
Mechanical stamp done. Author the rest by hand …
```

The script **refuses to run if `<APP>/AGENTS.md` already exists**, so a
stamped repo can't be clobbered.

**What the script does (deterministic):** copies the core, deletes its own
`README.md`/`stamp.sh` from the target, removes the skill dir for each pruned
codebase, and rewrites the `docs-with-code.sh` watch list.

**What you author by hand (needs judgment — the script lists these):**

1. **`AGENTS.md`** — fill the `## STACK` block; delete any pruned codebase
   from the prose (STACK, "Per-codebase rules", TEST COVERAGE, VERSION).
2. **`CLAUDE.md`** — drop any pruned codebase from the skill list.
3. **`<dir>/AGENTS.md`** for each kept code codebase — port the convention
   skeleton (copy from an existing app and adjust).
4. **`docs/`** — `docs/AGENTS.md` you author up front; the numbered `00-09`
   pages land same-turn with the code they document.

---

## Enforcement — and the cross-agent gap

The `.claude/hooks/` are **Claude Code only**. Other agents read the
`AGENTS.md` *rules*, but they don't run `no-todo.sh` / `docs-with-code.sh`.
To enforce the same invariants for any agent (or a human), wire the checks
into **CI** — the greps in `docs/AGENTS.md` "Verification ritual" are
CI-ready (no-stale-claims, env-var-in-three-places, version-bump audit,
pointer integrity).

Quick local check that the Claude wiring fires after stamping:

- Edit any `.rb` with a `# TODO` comment → `no-todo.sh` blocks the turn (exit 2).
- Change a file under `backend/` (or `mobile/`) without touching `docs/`,
  end the turn → `docs-with-code.sh` prints the ⚠ docs reminder.

---

## Keeping copies in sync

This repo and the local copy at `~/.claude/templates/agent-rules/` are the
same files. Pick **one** as canonical to avoid drift:

- **This repo as canonical:** clone it, run `stamp.sh` from the clone, and
  point your local copy at it (or just `git pull` the clone).
- **Local copy as canonical:** edit `~/.claude/templates/agent-rules/`, then
  `cp -R` back into a clone of this repo and push.

Either way, a universal-rule change is re-applied to existing stamped repos
by hand — that's the snapshot trade-off.
