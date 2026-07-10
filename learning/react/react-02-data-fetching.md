# Session 2 — Data fetching: the hand-rolled stack vs TanStack Query

Notes for topic 2 of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done. Follows
[`react-01-hooks.md`](react-01-hooks.md).

## What this app does (three layers)

1. `personal_manager/web/src/lib/api.ts` — envelope-aware
   `request<T>` / `upload<T>`, returns `ApiResult<T>`.
2. `src/features/<name>/<name>-client.js` — endpoint functions per
   feature.
3. Screens hold `loading` / `error` / `data` in `useState` + an
   effect — the manual state machine from react-01, including the
   `cancelled`-flag race guard.

## What TanStack Query actually is

It replaces **layer 3 only**: `useQuery({ queryKey, queryFn })` gives
caching, request dedupe, the cancellation dance, refetch-on-focus,
and `useMutation` + `invalidateQueries` (Rails analogy: cache expiry
cascades à la `touch: true`). Layers 1–2 would survive intact as
`queryFn`s. What it does *not* do: fetch (it manages the state around
your fetch).

## The decision (codified — this is the lesson's artifact)

`web/AGENTS.md` already forbids it: *"No axios, react-query, SWR,
ky"*, and the testing section adds *"don't add a third-party
HTTP/state lib to dodge the test setup."* The reasoning, written out
so future-you re-litigates against arguments instead of vibes:

- The hand-rolled pattern is consistent across all features, fully
  tested, and has **no caching bugs because it has no cache**.
- The library earns its dependency-justification paragraph when the
  *pain* appears: stale lists after cross-screen mutations, duplicate
  in-flight fetches, spinner flicker on back-navigation. None are
  user-visible today.
- When that day comes, adopt it as a layer-3 replacement per feature
  (the clients don't change), with `useSuspenseQuery` considered at
  the same time (see react-04). Until then, hand-rolling *fetch state*
  is fine; the rule to keep is **never hand-roll a cache**.

## Verify

```bash
cd web && grep -rn "axios\|react-query\|@tanstack\|swr" src package.json
```

Expected: no dependency hits (only this note's filename pattern in
none — the grep returns nothing or comments only).
