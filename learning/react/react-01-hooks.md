# Session 1 — Hooks mental model

Notes for topic 1 of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done.

## The model (Rails → React)

- A component is a **pure function `props + state → JSX`, re-run on
  every state change** — a view re-rendered per request, not a
  stateful object that mutates.
- `useState` — per-mount state; each render sees a snapshot.
- `useEffect` is **not a lifecycle callback** — it synchronizes the
  component with an external system (network, subscription, DOM). If
  the logic responds to a user action, it belongs in the handler, not
  an effect.
- A custom hook is an extracted concern: shared state*ful logic*, no
  shared state — two callers get independent state.

## The specimen: [`web/src/use-health-check.js`](../../../web/src/use-health-check.js)

Pre-existing anatomy worth internalizing:

- Four `useState`s = the manual fetch state machine
  (`loading → ok | down`).
- The `cancelled` flag set in the effect's **cleanup** is the manual
  race guard: if the component unmounts (or deps change) mid-flight,
  the stale response must not write state. Every hand-rolled fetch
  hook needs this; forgetting it is the classic bug.

## The exercise shipped (this session)

`refetch()` — added the house-rules way (`useState` + `useEffect`
only, web `AGENTS.md`):

- A `attempt` counter in state; `refetch = () => setAttempt(n => n+1)`;
  the effect lists `[apiBaseUrl, attempt]` as deps. The fetch
  lifecycle (cancellation, state writes) never leaves the effect —
  re-running it is *expressed as data* (a dep change), which is the
  hooks idiom the dependency array exists for.
- The effect now resets all four states on entry so a retry after a
  failure shows `loading` again instead of the stale error.
- Consumer (no dead code): a "Re-run check" outline `Button` on the
  BackendHealth screen ([`HomeScreen.jsx`](../../../web/src/HomeScreen.jsx)),
  disabled while loading.
- Tests at both layers, per the web testing pyramid: hook layer
  (`renderHook` + MSW — 500 override, `server.resetHandlers()`,
  `act(() => refetch())`, recovery to `ok`) and component layer
  (mocked hook, button → `refetch` wiring + disabled state).

## Verify (reproduced 2026-06-12)

```bash
cd web && npx jest use-health-check HomeScreen App.integration
```

Expected: `Test Suites: 3 passed` / `Tests: 15 passed`.

```bash
npm run test:coverage
```

Expected: `Test Suites: 80 passed` / `Tests: 545 passed`, coverage
pins (lines/statements 90, branches/functions 80) hold. The
worker-exit warning at the end is the known jsdom/MSW teardown quirk —
it's why `npm test` carries `--forceExit`.

## The full track (all topics complete, 2026-06-12)

[react-02 data fetching](react-02-data-fetching.md) ·
[react-03 forms](react-03-forms.md) ·
[react-04 Suspense](react-04-suspense.md) ·
[react-05 Vite SPA vs RSC](react-05-vite-spa-vs-rsc.md) — the session
that added the decision record to `06-architecture.md` ·
[react-06 shadcn patterns](react-06-shadcn-patterns.md) ·
[react-07 testing](react-07-testing.md)
