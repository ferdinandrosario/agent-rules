# Session 5 — Vite SPA vs Next.js / RSC: the architecture verdict

Notes for topic 5 of the modern-React-via-`web/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 3). This file
existing marks the topic done. Follows
[`react-04-suspense.md`](react-04-suspense.md).

## What RSC actually is

React Server Components run on the server, can read data sources
directly (no API layer between component and DB), and stream rendered
output; only Client Components ship JS to the browser. Next.js is the
production vehicle. The framework brings its own server — which is the
crux for this app.

## The three triggers, applied (the artifact lives in the architecture doc)

The canonical decision record is now
`personal_manager/docs/architecture/overview.md`:

1. SEO / anonymous first-paint — **no**: every screen is behind the
   auth gate.
2. Server-colocated data access — **no**: Rails is the server layer;
   RSC would be a second backend-for-frontend duplicating auth,
   serialization, and deployment.
3. Streaming large server-rendered pages — **no**: small JSON CRUD.

Verdict: the existing choice is right, and now written down with its
reversal conditions — future-you re-litigates against the doc, not
from scratch.

## The transferable rule

"Modern" ≠ "for you". RSC is the right default for content-heavy,
SEO-facing products without an existing backend. For an authenticated
dashboard over a real API, SPA + API is not legacy — it's the boring,
separable architecture this repo's ROLE line asks for.

## Verify

```bash
grep -n "Why a Vite SPA" docs/architecture/overview.md
```

Expected: one heading hit — the decision record exists.
