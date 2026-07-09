# Token efficiency rules

Loaded by reference from `AGENTS.md` rule 7. Apply on every response.
The goal is **fewer tokens read, fewer tokens written, fewer tool calls** —
without dropping correctness or skipping verification that is actually
necessary.

## Responses

- No preamble or filler. Don't restate the task before doing it.
- No closing summary unless asked. The diff is the report.
- Skip "I'll now…", "Let me…", "Sure!", "Great question!".
- Explain *why*, never *what* — code already shows *what*.
- Markdown only when it earns its keep (lists, code, tables). No headers
  for a one-paragraph answer.
- One clarifying question max per round, and only when ambiguity would
  cause wrong implementation.

## Reading & exploration

- Locate first, open second. `grep -n "pattern" path` before any Read.
- Read with `offset`/`limit` (or `sed -n 'A,Bp'`) — never the whole file
  unless it is genuinely small or unknown shape.
- Don't re-read a file after editing to "verify"; the Edit tool already
  echoes the diff.
- Don't run `ls`/`pwd` when context already shows the layout.
- Don't re-list a directory you just listed.
- For broad fan-out searches across many files or naming conventions,
  delegate to the **Explore** subagent — it spends its own context on
  the file dumps and returns just the conclusion, keeping the main
  context lean. Use it when you need the answer, not the file contents.

## Edits

- `Edit` (targeted) over `Write` (full rewrite). Only use `Write` for new
  files or genuinely full rewrites.
- Smallest change that solves the problem. No drive-by refactors.
- Anchor `old_string` on the minimum unique context — do not paste large
  blocks just for safety.
- `replace_all` only for true rename-style changes.

## Git operations

- **Mutating / remote-visible commands need explicit per-invocation user
  confirmation:** `push`, `add -A` / `add .`, `reset --hard`,
  `checkout -- <path>`, `clean -f`, `rebase`, `merge`, `branch -D`,
  `stash drop`, `tag`, `cherry-pick`, `revert`, `mv`, `rm`. Past
  approval does **not** carry over. An explicit instruction in the
  task itself ("push this", "open a PR") is the confirmation for that
  command (`AGENTS.md` rule 8).
- **Exempt — run autonomously:** staging by exact path and `commit` on
  the local branch (`AGENTS.md` rule 8).
- **Force-push is never covered by a general "push."** `git push --force` /
  `--force-with-lease` needs its own explicit, force-specific go-ahead in that
  turn — "push this" does not authorize it. When a rebase would otherwise need
  a force-push to an already-published branch, `git revert` the redundant
  commits instead so the push stays a fast-forward, or ask.
- **Integrate by rebase, never merge.** Rebase feature branches onto an
  up-to-date `main`; PRs land as "Rebase and merge" only.
- **Keep local `main` synced.** `git fetch` + fast-forward `main` to
  `origin/main` before branching, rebasing, or cherry-picking — local `main`
  is often behind.
- **Drop a commit already on `main`.** Rebase auto-skips it ("skipped
  previously applied commit"); when force-push isn't allowed, `git revert` it
  on the branch instead.
- **Branch names:** `<type>/<kebab-desc>` using Conventional-Commit types
  (`feat/`, `fix/`, `docs/`, `chore/`, …).
- **Read-only git is free to run** without asking: `status`, `diff`,
  `log`, `show`, `branch` (list), `remote -v`.
- Don't run `git status` before a commit unless the working tree is
  genuinely unknown.
- Stage by exact path. Never `git add .` / `git add -A` unless every
  change is intentional.
- Commit messages inline with `-m`. No editor, no temp files.
- No post-commit `git status` / `git log` / `git diff` "to verify". The
  commit either succeeded or the tool errored.
- No `git push` followed by an immediate `git status` to confirm.
- Chain related commands: `git add path && git commit -m "…" && git push`
  is one tool call, not three.

## Planning

- Act on clear tasks immediately. Don't draft a plan for a one-line fix.
- For exploratory prompts ("what could we do about X?"), respond in
  2–3 sentences with a recommendation and the main tradeoff. Don't
  implement until the user agrees.
- Reuse an existing plan; update it instead of writing a parallel one.

## Tool calls

- Batch independent calls in a single message. If A doesn't depend on B's
  output, run them in parallel.
- Don't call a tool to confirm something the conversation already shows.
- No sleep loops, no polling. Use a background process + notify, or a
  single targeted check.
- Prefer a dedicated tool over `Bash` when one fits (`Read`, `Edit`,
  `Write`, `Grep`/search) — the dedicated tool is cheaper to render and
  easier for the user to approve.
- **Extract the signal, don't dump output.** After a command runs, surface
  only the essential result — pass/fail plus the key numbers/paths (e.g.
  "60 examples, 0 failures · 100%"). Pipe to `grep`/`tail -n N` to pull just
  that; don't `cat`/`tail` whole logs, build output, or full test runs once
  the task is done. Show full output only when debugging a failure.

## Context management

- Run `/compact` when the conversation exceeds ~50 k tokens or after a turn that dumped a large file/diff into context. Don't wait until the harness auto-compacts — compacting earlier keeps the summary tighter.
- After receiving a large tool result (full file read, long grep output), compact before the next multi-step task so the result doesn't bloat every subsequent turn.
- Delegate broad fan-out reads to the **Explore** subagent: it burns its own context on file dumps and returns just the conclusion. Use it whenever you'd otherwise open more than 3 unrelated files.
- Prefer `offset`/`limit` on Read over reading a whole file then discarding 90% — unread tokens still cost.

## Output cap

End-of-turn summary: one or two sentences. What changed, what's next.
Nothing else.
