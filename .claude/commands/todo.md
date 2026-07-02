---
description: Park the out-of-scope idea under discussion in docs/todo.md so it isn't lost.
argument-hint: [idea to capture — omit to use the latest suggestion in the conversation]
---

# /todo — park an idea for later

Append an entry to [`docs/todo.md`](../../docs/todo.md) capturing a deferred
suggestion, so a good idea raised mid-task isn't lost. This is the sanctioned
home for "later" work (the repo bans `TODO`/`FIXME` code comments); tracked,
scheduled work still goes to GitHub issues.

1. **Pick the idea.** Use `$ARGUMENTS` if given; otherwise the most recent
   out-of-scope suggestion in this conversation. If neither is clear, ask
   which one — never invent an entry.
2. **Skip duplicates.** Read `docs/todo.md`; if the same idea is already
   under **Open**, say so and stop rather than adding a second copy.
3. **Append** it under `## Open` (newest first), using the entry format that
   file defines: imperative title; **Added** = today; **Source** = the PR /
   branch / session it came from; **What**; **Why**; **Pointers** (`file:line`
   or doc refs a cold reader needs to act on it).
4. **Report** the one-line title you added. Don't commit unless asked.
