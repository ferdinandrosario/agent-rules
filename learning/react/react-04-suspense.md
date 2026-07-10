# Session 4 — Suspense: code vs data

Notes for topic 4 of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done. Follows
[`react-03-forms.md`](react-03-forms.md).

## Suspense-for-code: already shipped

[`web/src/App.jsx`](../../../web/src/App.jsx) lazy-loads every screen:

- `lazyNamed(loader, name)` adapts `React.lazy` (which wants a
  `default` export) to this codebase's named-export convention — read
  the comment at the top of App.jsx; it documents the why.
- Each route chunk downloads on first navigation; the `<Suspense>`
  fallback renders while it arrives. App.jsx also documents why there
  is **no fallback at the root** (an unauthenticated visitor would see
  a flash for no reason).

This is route-level code splitting — Rails analogy: autoloading.
Vite emits one chunk per `import()`; `npm run build` lists them.

## Suspense-for-data: understood, not shipped

The other meaning: a component reads a promise with React 19's
`use(promise)` and *suspends* until it resolves; the nearest
`<Suspense>` boundary shows the fallback, and errors surface at the
nearest error boundary (this app has one —
`components/error-boundary.jsx`).

Why it's not in this codebase: ergonomic Suspense-for-data needs a
promise *cache* — hand-rolling one is exactly the "never hand-roll a
cache" trap from react-02, and the integrated route
(`useSuspenseQuery`) belongs to the same not-yet-adopted library.
The two decisions are one decision; they travel together.

## Verify

```bash
cd web && npm run build 2>&1 | tail -15
```

Expected (reproduced 2026-06-12): `✓ built` in under a second, and
the asset list shows one JS chunk per lazy screen
(`LandScreen-*.js`, `LifeScreen-*.js`, …) — the splitting, visible.
The `(!) Some chunks are larger than 500 kB` warning is the known
`maplibre-gl` chunk (~1 MB), not a regression.
