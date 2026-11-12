---
name: react
description: Use for idiomatic React (web) best practices — components, hooks, state/data, effects, lists/keys, performance, forms, and testing — independent of any one repo. Triggers on "how should I build X in React", React/JSX code review, or web UI/state design questions. For React Native use the `react-native` skill.
---

# React (web) — idiomatic best practices

Framework-level conventions for React web apps (Vite SPA by default). For
mobile see the [`react-native`](../react-native/SKILL.md) skill — the
component/hook rules here apply there too; RN adds its own navigation,
lists, and styling. When working inside a project, its `web/AGENTS.md` is
the source of truth and **overrides** anything here on conflict (stack,
version delta, UI stack, approved libraries, API contract, folder layout,
testing/coverage policy).

Version context: React **19.2.x** as of 2026-11. Check `package.json`
before using newer APIs.

**How to read this:** three layers — Foundations for any reader, Everyday
craft as the working vocabulary, Design as the judgment layer. Every rule
carries its why.

## Layer 1 — Foundations

- **Function components + hooks only.** One component per file, named for
  what it renders; co-locate small sub-components under the feature folder.
- **Components are pure functions of props and state.** No side effects
  during render; same inputs → same JSX. *Why:* purity is what makes
  React's re-render model (and StrictMode's double-render check) safe.
- **Props down, events up.** A child never mutates what its parent owns —
  it calls the handler the parent passed.
- **Keep state minimal — derive, don't duplicate.** If a value can be
  computed from existing props/state, compute it during render:

  ```jsx
  const overdue = tasks.filter(t => t.due < today);   // ✓ derived each render
  const [overdue, setOverdue] = useState([]);          // ✗ second copy, will drift
  ```
- **Stable, identity-based `key`s** on list items (an id) — never the array
  index for lists that reorder/insert/delete. *Why:* keys are how React
  matches old and new children; index keys re-associate state (input text,
  animations) with the wrong row after a reorder.
- **Controlled inputs** for anything you validate; every input gets a
  `<label>`; interactive elements are real `<button>`/`<a>`, not `div
  onClick` — semantics is the zero-cost accessibility layer.

## Layer 2 — Everyday craft

### Hooks & effects
- Rules of hooks: top level only, never conditional/looped — call order is
  React's bookkeeping.
- **Most effects shouldn't exist** (react.dev "You Might Not Need an
  Effect"). Not for derived data (compute in render), not for responding to
  a click (do it in the handler), not for resetting state on a prop change
  (use `key` to remount), not for chaining state updates (compute once).
  Effects are for **synchronizing with external systems**: subscriptions,
  imperative DOM/widgets, analytics on mount.
- Every effect declares honest dependencies and returns a cleanup that
  undoes exactly what setup did. An effect that "works" only with a missing
  dep is a stale-closure bug waiting for the second render.
- **`useEffectEvent` (19.2) for non-reactive logic called from an
  effect** (e.g. read the latest `theme` inside a connection handler
  without re-subscribing when `theme` changes). *Why:* it replaces the
  two bad options — a dishonest dependency array or an
  `eslint-disable react-hooks/exhaustive-deps`. Never put it in a
  dependency array or pass it to children.
- Extract repeated effect+state wiring into a custom `use*` hook — the hook
  is the unit of stateful reuse.
- **If the project enables React Compiler, drop hand-written
  `useMemo`/`useCallback`/`memo`** except where referential identity is a
  semantic requirement (effect deps, third-party APIs); the compiler
  memoizes at build time. Without it, the rule below applies.
- **Memoize deliberately, not reflexively.** `useMemo`/`useCallback` earn
  their keep for measured-expensive work or referential stability feeding
  memoized children. Blanket memoization adds reading cost and hides the
  real fix (usually state placed too high).

### State placement (decision ladder)
1. **Local `useState`** — default; most state is one component's business.
2. **Lift** to the nearest common parent when two siblings truly share it.
3. **URL** for state a user should be able to link/refresh into (tab, filter,
   date) — `?date=2026-07-03` beats invisible in-memory state.
4. **Context** for stable app-wide values (theme, session) — sparingly; every
   consumer re-renders on change.
5. **External store / data library** — only when the project's rules allow
   one; many small apps (including this user's) deliberately forbid state
   libs and live on `useState` + props. Respect the project's ceiling.

### Data fetching & async
- Centralize API calls in one typed client module per app; feature code
  calls named functions (`tasksClient.list()`), never sprinkles `fetch`.
  Config comes from typed env (`import.meta.env.VITE_*`) — no hardcoded
  hosts, no secrets in the bundle (client env is public by definition).
- Every screen renders **loading and error** states, not just the happy
  path; surface failures (inline error, boundary) and keep field-level
  validation errors next to their fields.
- Where the project allows a data library (TanStack Query), let it own
  caching/retry/dedup; where it doesn't, keep the manual `useEffect` fetch
  honest — abort on unmount (`AbortController`), branch on `ok`, type the
  envelope.
- Code-split routes with `lazy()` + `Suspense`; keep a >200 KB vendor lib
  behind the route that uses it so it can't block first paint.
- Add an **error boundary** above routes so one crashed component degrades
  to a fallback instead of white-screening the app.

### TypeScript
- `strict: true`. Type props and API responses explicitly; prefer
  **discriminated unions** over optional-flag soup — make illegal states
  unrepresentable:

  ```ts
  type Result<T> = { ok: true; data: T } | { ok: false; code: string };
  ```
- `unknown` + narrowing over `any` (an `any` switches the checker off for
  everything it touches); `satisfies` to validate config objects without
  widening.

## Layer 3 — Design (senior/staff judgment)

- **Feature folders, not layer folders.** `features/<name>/` holds the
  screen, its client, helpers, and tests; `components/ui/` holds the shared
  primitives. *Why:* change locality — a feature edit touches one folder.
- **Composition over configuration:** pass `children`/slots instead of
  growing a component's prop list past ~7 booleans; a `<Card
  header={…}>` beats `<Card showHeader hasBorder isCompact …>`.
- **Business logic lives outside components** — plain modules
  (`format.ts`, `api.ts`) that are unit-testable without rendering.
  Components render state and forward events; that's the whole job.
- **The client owns presentation, the server owns truth.** Mirror backend
  validation inline for fast feedback, but treat the server's answer as
  the verdict; never trust a client-computed total or role check.
- **Performance methodology:** measure with React DevTools Profiler first.
  The usual wins, in order: move state down (shrink the re-render blast
  radius) → memoize the hot leaf → virtualize long lists → code-split. A
  `memo` slapped on everything is noise; one placed after profiling is a fix.
- **Design system discipline:** primitives (owned `components/ui/`) are
  edited at the primitive layer with variants, never forked ad-hoc inside a
  feature — two divergent Buttons is how a UI rots.

## Testing

- Jest/Vitest + **React Testing Library**: query by role/label/text — what
  a user perceives — and drive with `user-event`. If a test reaches for a
  CSS class or component internals, it's testing implementation, and will
  break on refactors that didn't break the app.
- Mock the network at the boundary (**MSW**), not the client module — the
  wiring between client and component is exactly what integration tests
  should cover. Cover error and empty states, not just success.
- Show the command **and its expected success output**:

  ```bash
  $ npm test
  Test Suites: 89 passed, 89 total
  Tests:       621 passed, 621 total
  ```

## Sources

Distilled from the official React docs (react.dev — "Thinking in React",
"You Might Not Need an Effect", "Keeping Components Pure"), the TypeScript
handbook's React guidance, Testing Library's guiding principles
("test what the user sees"), and TanStack Query's async-state model —
cross-checked against React 19 semantics (StrictMode double-render,
`lazy`/`Suspense` routing).

## When in doubt

Prefer the boring, well-documented React pattern a future maintainer will
recognize on first read over a clever abstraction that needs a comment.
