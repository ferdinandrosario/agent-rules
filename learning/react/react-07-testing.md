# Session 7 — Testing: the stack you have, and the Vitest question

Notes for topic 7 (final) of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done. Follows
[`react-06-shadcn-patterns.md`](react-06-shadcn-patterns.md).

## The stack, named precisely

Jest 30 + React Testing Library + `user-event` + **MSW v2** — *not*
Vitest (a common 2026 assumption for Vite apps; this repo runs Jest
via `babel-jest`, configs in `web/jest.config.js` + `jest.shim.js`).

## The three ideas that matter (all live in this codebase)

1. **Test what a user perceives.** Testing Library queries by
   role/label/text (`getByRole('button', { name: /re-run check/i })`),
   so a correct refactor is invisible to the suite — react-01's
   refetch change passed the existing tests untouched, and that
   non-event is the design working.
2. **Mock at the network, not the module.** MSW intercepts `fetch`
   (`src/mocks/handlers.js` + per-test `server.use(...)` overrides),
   so tests exercise the real `api.ts` envelope parsing — request
   specs, not stubbed-model controller specs. The web `AGENTS.md`
   three-layer table (component = mock the hook; hook = renderHook +
   MSW; integration = no mocks above the network) is the pyramid.
3. **Coverage pins are ratchets** (root `AGENTS.md`): pins hold the
   highest value the suite clears; raise only when already passing,
   never lower, never red-CI the next commit.

## The Vitest verdict

Vitest's case for a Vite app: it *shares `vite.config.js`* (this repo
maintains a parallel Babel pipeline just for Jest — `babel.config.cjs`,
the `import.meta.env` rewrite, jsdom polyfills in `jest.shim.js` —
all of which Vitest would make redundant), ESM-native, faster watch,
near-drop-in API (`jest.fn()` → `vi.fn()`).

Verdict: **legitimate cleanup, not urgent** — zero new capability,
one of the larger config migrations (80 suites, coverage pins, CI).
Per the house upgrade rule it would be its own PR ("one tool per PR,
reason in the description"), triggered when the Babel-parallel-config
maintenance or watch speed actually hurts. Until then the skills are
portable: Testing Library, user-event, and MSW carry over unchanged.

## Verify (reproduced 2026-06-12)

```bash
cd web && npm run test:coverage 2>&1 | tail -6
```

Expected: `Test Suites: 80 passed` / `Tests: 545 passed`; coverage
table prints and the pinned thresholds (lines/statements 90,
branches/functions 80) pass. The force-exit warning at the end is the
known teardown quirk, already accounted for by `--forceExit`.
