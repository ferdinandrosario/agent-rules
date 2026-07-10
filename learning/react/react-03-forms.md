# Session 3 — Forms: the controlled-dialog pattern vs React 19 Actions

Notes for topic 3 of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done. Follows
[`react-02-data-fetching.md`](react-02-data-fetching.md).

## The house pattern (read it, it's load-bearing)

[`web/src/components/entity-form-dialog.jsx`](../../../web/src/components/entity-form-dialog.jsx)
is the one form engine behind every feature's create/edit dialog:

- Four `useState`s: `values` (seeded from `fields` + `record`),
  `errors` (per-field map), `formError`, `saving`.
- `handleSubmit` calls `onSubmit(payload)` → the feature client → the
  shared `ApiResult`; a `validation_failed` failure's `fields` map
  (snake_case, straight from Rails `@record.errors`) lands in the
  per-field `errors` state. The server is the validator; the form is
  the renderer of its verdict — same division of labor as a classic
  Rails form.

## What React 19 Actions would change (known, not adopted)

`<form action={fn}>` + `useActionState(fn, initial)` returns
`[state, formAction, isPending]` — React manages the pending flag and
the returned error state, collapsing the four `useState`s to one
reducer-shaped action. The server `fields` map would slot directly
into the action's returned state.

**Not adopted, deliberately:** web `AGENTS.md` pins the state model to
`useState` + `useEffect` only — `useActionState` is exactly the kind
of alternative state container the rule exists to keep out while one
pattern serves every form. Revisit alongside any future loosening of
that rule; the migration is mechanical (the four states map 1:1 onto
action state + `isPending`) and per-form incremental.

## Verify

`entity-form-dialog.jsx` has **no direct test file** — it's covered
through its consumers (the `entity-tab` flow inside the feature-screen
suites: LifeScreen, VehiclesScreen, TravelScreen, …), the
component-layer pattern from web `AGENTS.md`. So:

```bash
cd web && npx jest LifeScreen VehiclesScreen 2>&1 | tail -4
```

Expected: both feature suites pass — they drive the dialog through
create/edit/validation-error paths, which is what makes a future
Actions migration safe to attempt per-form.
