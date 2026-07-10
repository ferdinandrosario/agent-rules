---
name: git
description: Use for any git operation or workflow decision in any repository — integrating changes, branching, committing, pushing, landing PRs, or recovering from divergence. Encodes the rebase-only, linear-history workflow — pull --rebase, rebase integration, PRs land via "Rebase and merge" only, force-push gated on an explicit force-specific instruction. Triggers on commit/push/merge/rebase/branch-naming/PR-landing questions.
---

# Git — rebase-only, linear-history workflow

The invariant: **history is linear, everywhere — local and remote, every
repo.** Changes integrate by rebase; a merge commit never lands; PRs land
via "Rebase and merge" only. When working inside a project, its `AGENTS.md`
git rules are the binding ruleset and **override** this skill on any
conflict (confirmation gates, protected commands, branch ritual).

## Confirmation gates

- **Read-only git runs free:** `status`, `diff`, `log`, `show`, `branch`
  (list), `remote -v`, `fetch`. *Why:* they cannot lose or publish work.
- **Mutating / remote-visible commands need explicit per-invocation user
  confirmation:** `push`, `add -A`/`add .`, `reset --hard`,
  `checkout -- <path>`, `clean -f`, `rebase`, `merge`, `branch -D`,
  `stash drop`, `tag`, `cherry-pick`, `revert`, `mv`, `rm`. Past approval
  does **not** carry over to the next invocation. An explicit instruction
  in the task itself ("push this", "open a PR", "commit+push+merge")
  counts as the confirmation for those commands — this is how remote / CI
  sessions work, where nobody can confirm interactively.
- **`commit` is exempt** — stage by exact path and commit on the local
  branch autonomously. *Why:* a local commit is always recoverable via
  reflog; everything else on the list can destroy or publish work.
- **Force-push is never covered by a general "push".**
  `git push --force` / `--force-with-lease` needs its own explicit,
  force-specific go-ahead in that very turn. When a rebase would need a
  force-push to an already-published branch, do **not** force —
  `git revert` the redundant commits instead so the push stays a
  fast-forward, or ask. *Why:* force-push is the one irreversible step
  that rewrites shared history; it always needs a human sign-off.

## Local integration — rebase, never merge

- **`git pull --rebase` always** (`git config pull.rebase true` if
  unset). Never `git pull` with a merge, never `git merge` a branch in.
- **Keep local `main` fast-forwarded from `origin/main`** before
  branching, rebasing, cherry-picking, or **pushing** — local `main` is
  often behind, and "push" is not a shortcut around the sync: fetch
  first, then push, even when it turns out to be a no-op.

  ```shell
  git fetch origin && git rev-list --left-right --count main...origin/main
  # expected: 0	0   (left = ahead, right = behind; nonzero right → pull --rebase first)
  ```

- **Drop a commit whose changes are already on `main`.** Rebase auto-skips
  it (patch-id match — the output says `skipped previously applied
  commit <sha>`); when force-push isn't allowed on a published branch,
  `git revert` it on the branch instead.

## Landing a PR — "Rebase and merge" only

Never merge-commit, never squash. *Why:* rebase-merge keeps every atomic
commit and a linear `main`, so `git bisect` and `git log` stay honest.

```shell
gh pr merge <num> --rebase --delete-branch   # after CI is green: gh pr checks <num> --watch
git checkout main && git pull --rebase
# expected: Fast-forward … then `git log --oneline -1` shows the landed commit
```

- Wait for CI before merging; a red or pending check never gets merged
  over.
- After the merge, fast-forward local `main` and confirm the branch is
  gone — `--delete-branch` removes both the remote and local copies.

## Branches and commits

- **One branch per change:** `<type>/<kebab-desc>` with
  Conventional-Commit types — `feat/`, `fix/`, `docs/`, `chore/`,
  `refactor/`, … (e.g. `feat/subscriptions-billing`).
- **Atomic commits.** One commit = one logical change with everything it
  needs to stay self-consistent and bisectable. A file rename is the
  `git mv` plus every reference update, together in one commit.
- **Conventional Commit subjects:** `feat(scope): …`, `fix: …`,
  `docs: …`, `refactor: rename OLD -> NEW`. The body carries the *why*;
  change history lives in git, not in the docs.
- **Renames use `git mv` only** — never delete + recreate. *Why:* keeps
  history and the executable bit. Prove zero orphaned references with
  `git grep <old-name>` before committing.

## Recovery

- Rebase rewrote a published branch and force is not authorized →
  `git revert` the redundant commits so the push stays a fast-forward.
- Diverged local `main` (accidental local commits) → move them to a
  branch (`git branch <type>/<desc>`), then reset `main` to
  `origin/main` — with the user's confirmation, since that is a
  `reset --hard`.
- Anything already pushed is shared history: fix forward (revert),
  never rewrite.

## Efficiency

- Stage by exact path; never `git add -A` / `git add .` unless every
  change in the tree is intentional.
- Commit messages inline with `-m`. No editor, no temp files.
- No post-commit `git status` / `git log` "to verify" — the commit either
  succeeded or the tool errored. Same for push.
- Chain related commands into one call:
  `git add <path> && git commit -m "…" && git push`.
- Don't run `git status` before a commit unless the working tree is
  genuinely unknown.
