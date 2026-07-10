# Session 4 — Generics, exactly as far as this codebase needs them

Notes for topic 4 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-03-serializer-type-drift.md`](ts-03-serializer-type-drift.md).

## The Rails mapping

A generic is a **type-level parameter**: `ApiResult<T>` is to types
what a parameterized scope is to queries — one definition, specialized
per call site. You rarely *write* one; you read these three daily.

## The three generics that run this app (all in shipped code)

### 1. `ApiResult<T>` — discriminated union (`personal_manager/mobile/src/lib/api.ts`)

```ts
type ApiResult<T> = ApiSuccess<T> | ApiFailure;
//   ApiSuccess<T> = { ok: true;  data: T; token?: string }
//   ApiFailure    = { ok: false; code: string; message: string; fields?: … }
```

`ok` is the **discriminant**: `if (result.ok)` narrows the whole
object, so `result.data` only typechecks inside the success branch and
`result.code` only inside the failure branch. It's a result object
where the compiler enforces that you wrote the failure branch —
the `rescue` you can't forget.

### 2. `request<T>(path)` — caller declares the deserialized shape

Trace one end-to-end
(`personal_manager/mobile/src/features/land/land-client.ts`):

```ts
land.list = (token) => request<LandClaim[]>('/api/v1/land_claims', { token })
// request<T> unwraps Envelope<T> → ApiResult<LandClaim[]>
// screen: if (res.ok) → res.data: LandClaim[]   (narrowed, T flowed through)
```

`T` enters at the feature client (the serializer mirror from ts-03),
flows through `parse<T>` / `Envelope<T>` inside `api.ts`, and exits
typed at the screen. One annotation per endpoint; inference does the
rest.

### 3. `openChannel<T>` — payload type for a subscription
(`personal_manager/mobile/src/features/friends/cable.ts`)

`openChannel<NotificationEvent>(…)` makes `onMessage(payload)` receive
a typed `NotificationEvent` — the generic carries the type *into a
callback*, which no non-generic signature can express.

## How far is "as far as I need"

- **Read** the three above fluently — that's the bar.
- **Write** a generic only when a function's output type depends on
  its input type *and* it has multiple call sites with different types.
  One call site → use the concrete type. (House rule heritage: "no
  overengineering", root `AGENTS.md` rule 6.)
- `extends` shows up once in shipped code
  (`withPresence<T extends { id: number; last_seen_at: string | null }>`,
  `FriendsScreen.tsx`) — a *constraint*: accept any user-ish shape,
  return the same shape. That's the most generic machinery this app
  has needed.

## Verify

```bash
cd mobile && npm run typecheck
```

Expected: silent, exit 0 (reading session — no code change).
