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

## Output cap

End-of-turn summary: one or two sentences. What changed, what's next.
Nothing else.
