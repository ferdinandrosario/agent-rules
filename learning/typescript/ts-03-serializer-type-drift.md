# Session 3 — Serializer ↔ client type drift

Notes for topic 3 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-02-strict-mode.md`](ts-02-strict-mode.md).

## The risk

Client types are the backend serializer contract **hand-transcribed**.
`strict` can't catch drift because the lie is in the type itself: Rails
renames or re-nullables a field, TS keeps believing the old shape, and
every downstream narrowing is now confidently wrong.

## The audit method (repeatable per feature)

1. **Serializer** — `backend/app/serializers/<model>_serializer.rb`:
   the emitted keys and any `&.iso8601` (nullable) vs `.iso8601`
   (non-null) calls.
2. **Schema + model** — `backend/db/schema.rb` for `null: false`;
   the model for `optional: true` associations and virtual accessors.
3. **TS mirror** — `mobile/src/features/<name>/<name>-client.ts`:
   field-by-field — name, type, `| null`.

## Findings (audited 2026-06-12) — zero drift

| Type | Verdict |
|---|---|
| `LandClaim` | Clean. `flag_note: string \| null` ↔ nullable `text` column; lat/lng `number` ↔ virtual accessors over a `null: false` PostGIS point; timestamps `.iso8601` non-null. |
| `NotificationRow` | Clean. `read_at: string \| null` ↔ `read_at&.iso8601`; `actor … \| null` ↔ `belongs_to :actor, optional: true`. |
| `NotificationEvent` | Clean — **deliberately different from `NotificationRow`**, see below. |

## The instructive part: a justified nullability asymmetry

`NotificationEvent.actor` is **non-null** while `NotificationRow.actor`
is **nullable** — and both are right:

- The live broadcast (`backend/app/services/notifications/dispatch.rb`
  → `deliver`) always builds `actor: { id:, name: }`; all three event
  constructors pass a real user. A broadcast cannot have a nil actor.
- The durable row (`Notification`) has `belongs_to :actor,
  optional: true` — the row outlives its actor (user deletion), so a
  reloaded list can carry `actor: null`.

Lesson: don't "unify" two similar types into one — when their
nullability differs, the difference is usually a domain fact. The T1
double-cast sat exactly on this seam and hid it.

## Rule codified

`mobile/AGENTS.md` → Rules now states: client types mirror backend
serializers field-by-field; a serializer change updates the client
type in the same change (the mobile face of the same-change sync
rule in `personal_manager/docs/CONTRIBUTING.md`).

## Verify

```bash
cd mobile && npm run typecheck
```

Expected: silent, exit 0 (the audit changed no code — a clean audit's
artifact is this note).
