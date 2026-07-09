# Todo — deferred ideas & suggestions

Park out-of-scope ideas here instead of losing them. Anything you or an
agent flags mid-task that shouldn't bloat the current change lands as an
entry below, to be picked up in a later PR.

This is the **sanctioned home for "do it later" notes**: the repo bans
`TODO`/`FIXME` comments in code (universal [`AGENTS.md`](../AGENTS.md) →
"Universal forbidden"), so instead of a `# TODO` in the source, add the
thought here. It is **not** a substitute for GitHub issues — those stay the
home for tracked, scheduled, assigned work. This file is the lightweight
"don't forget" list.

Append-only by convention: add to **Open** (newest first); the only edit to
an existing entry is moving it to **Done** with the PR that closed it.

## How an entry gets added

- **On demand:** run `/todo` to capture the suggestion currently under
  discussion, or `/todo <idea>` to capture a specific idea you name inline
  (e.g. `/todo add rate-limiting to the login endpoint`). Either way it
  appends the entry under **Open** and reports back the one-line title it
  added — nothing is committed (see
  [`.claude/commands/todo.md`](../.claude/commands/todo.md)).
- **Proactively:** when an agent surfaces an out-of-scope idea it offers to
  record it; on your go-ahead (or "todo it") it appends the entry here.
  Convention: universal [`AGENTS.md`](../AGENTS.md) → "Todo".

## Entry format

Append under **Open**, newest first — one block per idea:

```text
### <short imperative title>
- **Added:** YYYY-MM-DD · **Source:** PR #, branch, or session topic
- **What:** one line — the concrete change to make.
- **Why:** one line — the value, or the problem it removes.
- **Pointers:** `file:line` / doc refs a cold reader needs to act on it.
```

## Open

*(nothing parked yet)*

## Done

*(nothing yet)*
