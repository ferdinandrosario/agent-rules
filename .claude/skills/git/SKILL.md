---
name: git
description: Use for any git operation or workflow decision in this repo — committing, branching, pushing, landing PRs, or recovering from divergence. Rebase-only, linear history — pull --rebase, PRs land via "Rebase and merge" only, force-push needs an explicit force-specific instruction.
---

# Git — this repo

The full rebase-only, linear-history workflow — confirmation gates, the
local integration ritual, PR landing, branch naming, atomic commits,
recovery, efficiency — lives in the user-level `git` skill
(`~/.claude/skills/git/SKILL.md`, not a repo link — lives outside this
checkout, in your home directory; versioned in the `agent-rules`
template's `user-skills/git/`). **Read it before nontrivial git work.**

This repo's binding rules — ABSOLUTE RULE 8 plus the "Git workflow"
section in [`AGENTS.md`](../../../AGENTS.md) — **override** the generic
skill on any conflict.

Universal rules: [`AGENTS.md`](../../../AGENTS.md).
