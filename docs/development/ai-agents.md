# AI agents

This repo's rules are written **once** in `AGENTS.md` (universal) and
the four per-codebase `<dir>/AGENTS.md` files (`backend`, `web`,
`mobile`, `docs`). `AGENTS.md` is the open, cross-agent standard read
natively by Codex, Cursor, Aider, Windsurf, Zed, Gemini CLI, and
GitHub Copilot. Every other agent file in the repo is a **thin pointer**
to one of those canonical files — it holds no rules of its own, so it
cannot drift.

> Default agent is **Claude Code**. Every other agent is supported by
> reading the same `AGENTS.md` files — there is no per-agent CI or
> behavior difference beyond which entry file each one auto-loads.

> **Template note:** the per-codebase `<dir>/AGENTS.md` files are
> authored per app (`stamp.sh` prints the checklist) — they exist in
> every stamped repo but not in the template itself, so they appear as
> plain names, not links, below.

## Plain-language intro (start here)

Think of instructing an AI coding assistant like running a kitchen.
There is now **one** recipe book and a few signs that point at it:

| File(s) | Kitchen analogy | Who reads it |
|---|---|---|
| **`AGENTS.md`** (repo root) | The master recipe book on the counter | **Every agent**, for the house rules |
| **`<dir>/AGENTS.md`** (`backend`, `web`, `mobile`, `docs`) | A station card at each prep station — grabbed when you work that station | **Every agent**, when editing that tree (nearest file wins) |
| `CLAUDE.md`, `.github/copilot-instructions.md`, `.github/instructions/*`, `.claude/skills/*/SKILL.md` | "See the recipe book" notes taped to each cook's own binder | Each tool loads its own note, which just sends it to `AGENTS.md` |

So it is **one** rulebook (split into a universal file + four station
cards), and a handful of one-line signposts so each tool finds it.

**Why one canonical file instead of a copy per tool?** A copy per tool
means every rule change has to be hand-applied to every copy, and any
missed copy silently drifts. With a single canonical `AGENTS.md` and
contentless pointers, there is nothing to keep in sync — you edit one
file and every agent sees it.

**Why split universal vs per-codebase?** The AI has a limited reading
budget per turn (tokens). A backend edit should load the backend station
card, not the web and mobile rules too. Agents that resolve the nearest
`AGENTS.md` (Codex, Cursor, …) do this automatically; Claude Code does
it through its on-demand skills.

## Which AI reads what

| Agent | Auto-loaded entry file(s) | How it reaches the rules |
|---|---|---|
| **Codex / Cursor / Aider / Windsurf / Zed / Gemini CLI** | `AGENTS.md` (root) + nearest `<dir>/AGENTS.md` | Reads the canonical files **directly** — no extra file. |
| **GitHub Copilot** (Chat / Edits / Agent) | [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md) + [`.github/instructions/<dir>.instructions.md`](../../.github/instructions) | Each is a thin pointer to the matching `AGENTS.md`; Copilot also reads root `AGENTS.md` natively. |
| **Claude Code** | [`CLAUDE.md`](../../CLAUDE.md) + `.claude/skills/<dir>/SKILL.md` | `CLAUDE.md` `@AGENTS.md`-imports the universal rules; each skill redirects to the matching `<dir>/AGENTS.md`. |

## Source of truth

| Layer | Canonical file | Pointers that send agents to it |
|---|---|---|
| Universal | [`AGENTS.md`](../../AGENTS.md) | `CLAUDE.md` (`@import`), `.github/copilot-instructions.md` |
| Backend | `backend/AGENTS.md` (authored per app) | `.claude/skills/backend/SKILL.md`, `.github/instructions/backend.instructions.md` |
| Web | `web/AGENTS.md` (authored per app) | `.claude/skills/web/SKILL.md`, `.github/instructions/web.instructions.md` |
| Mobile | `mobile/AGENTS.md` (authored per app) | `.claude/skills/mobile/SKILL.md`, `.github/instructions/mobile.instructions.md` |
| Docs | `docs/AGENTS.md` (authored per app) | `.claude/skills/docs/SKILL.md`, `.github/instructions/docs.instructions.md` |

**Pointers never contain rules.** If you find a rule written in a
pointer file, that's a bug — move it into the matching `AGENTS.md` and
leave the pointer a pointer.

## Changing a rule (the whole protocol)

1. **Edit the canonical file** — `AGENTS.md` for a universal rule, or
   `<dir>/AGENTS.md` for a per-codebase one. That's it; every agent
   picks it up. No mirror step.
2. **Pointers** (`CLAUDE.md`, the `.claude/skills/*`, the Copilot
   files) only change when the *wiring* changes — a new codebase, a
   renamed file, a new agent — not when a rule changes.
3. **Commit message** carries the why — change history lives in git.

Because rules live in exactly one place, there is no per-PR "mirror
into the other copies" protocol — there are no other copies.

## Pointer-integrity check (run before reporting done)

The only thing that can break now is a pointer aiming at the wrong file
(or a canonical file going missing). CI runs the same checks
deterministically —
[`.github/workflows/agents-pointers.yml`](../../.github/workflows/agents-pointers.yml)
triggers on any change to a canonical `AGENTS.md`, a thin pointer, or
the `.claude/` wiring — so a broken pointer cannot merge; run the
commands locally for a faster loop.

```sh
# 1. All five canonical files exist.
ls AGENTS.md backend/AGENTS.md web/AGENTS.md mobile/AGENTS.md docs/AGENTS.md
# (expected: all five listed, no "No such file")

# 2. CLAUDE.md imports the universal canon.
grep -q '^@AGENTS.md' CLAUDE.md && echo "CLAUDE.md @imports AGENTS.md"
# (expected: the confirmation line)

# 3. Every pointer references an AGENTS.md and carries no rule headings
#    of its own (pointers are short; canonical files own the `## ` rules).
for f in .github/copilot-instructions.md .github/instructions/*.instructions.md \
         .claude/skills/*/SKILL.md; do
  grep -q 'AGENTS.md' "$f" || echo "MISSING AGENTS.md pointer: $f"
done
# (expected: no output — every pointer points home)

# 4. No rule content leaked back into a pointer (heuristic: pointers
#    stay short — flag any over ~30 lines for review).
for f in .github/copilot-instructions.md .github/instructions/*.instructions.md \
         .claude/skills/*/SKILL.md; do
  n=$(wc -l < "$f"); [ "$n" -gt 30 ] && echo "REVIEW (>30 lines): $f ($n)"
done
# (expected: no output)
```

## Adding a new AI agent later

If you start using another agent (a new CLI, IDE, or extension):

1. Check whether it reads `AGENTS.md` natively (most modern agents do —
   Codex, Cursor, Aider, Windsurf, Zed, Gemini CLI, Copilot). If so,
   **nothing to add** — it already sees the canon.
2. If it needs its own discovery file (like Claude's `CLAUDE.md` or
   Copilot's `.github/instructions/*`), add a **thin pointer** to
   `AGENTS.md` / the nearest `<dir>/AGENTS.md` — never a copy of the
   rules.
3. Add the agent + its entry file to the **Which AI reads what** table
   above, and extend the pointer-integrity check if the new file
   doesn't already match its globs.

## Enforcement hooks (Claude Code)

Two universal rules are enforced **deterministically** by Claude Code
hooks, not left to the agent to remember — cheaper (no model tokens) and
reliable. Hooks are wired in
[`.claude/settings.json`](../../.claude/settings.json) (committed,
team-wide) and call POSIX-sh scripts in `.claude/hooks/`:

| Hook | Event | Script | Behavior |
|---|---|---|---|
| No-TODO | `PostToolUse` on `Edit\|Write` | [`.claude/hooks/no-todo.sh`](../../.claude/hooks/no-todo.sh) | **Blocks** (exit 2) when a just-edited code file (`.rb/.js/.jsx/.ts/.tsx/.mjs/.cjs/.rake/.erb/.sh/.yml/.yaml`) contains a `# TODO`, `// TODO`, or `FIXME` comment. Prose docs are exempt — the rules files quote the banned forms. |
| Docs-with-code | `Stop` | [`.claude/hooks/docs-with-code.sh`](../../.claude/hooks/docs-with-code.sh) | **Warns** (non-blocking `systemMessage`) when the session's work — uncommitted changes plus commits since the default-branch merge-base — touches `backend/`, `web/`, or `mobile/` but nothing under `docs/`, per the same-turn doc-update rule. |

These are a safety net for the prose rules in [`AGENTS.md`](../../AGENTS.md),
not a replacement — other agents don't run them, so the written rules
remain canonical. After editing `.claude/settings.json` or the scripts,
open `/hooks` once (or restart) so Claude Code reloads the config.

## Why this layout (AGENTS.md canonical + thin pointers)

A layout that keeps a **full copy** of every rule per agent (an agent
file + a Copilot mirror, each policed by a content-diff drift check)
works, but every rule edit is N edits, and a missed copy drifts
silently — the classic failure is a hard-coded count or version that
goes stale in one copy while the others move on.

The `AGENTS.md`-canonical layout removes the duplication entirely:

- **One edit per rule.** Change `AGENTS.md` (or a `<dir>/AGENTS.md`) and
  every agent — current and future — sees it. No mirror step, no drift
  surface.
- **Portability.** `AGENTS.md` is the cross-vendor standard, so moving
  to a new agent (or back) needs no new rules file in most cases. Your
  rules travel with the repo, not with the tool.
- **Tool-specific framing stays thin.** Each tool still gets its own
  discovery file with the banner/frontmatter it needs (`applyTo:` for
  Copilot, `description:` for Claude skills) — but those files only
  *point*, so there is nothing in them to keep in sync.

## Cross-references

- [`AGENTS.md`](../../AGENTS.md) — universal rules (canonical).
- `backend/AGENTS.md` · `web/AGENTS.md` · `mobile/AGENTS.md` ·
  `docs/AGENTS.md` — per-codebase rules (canonical; authored per app).
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — feature-doc checklist.
