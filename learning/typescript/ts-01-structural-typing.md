# Session 1 — Structural typing, casts, and the features/ audit

Notes for topic 1 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done.

## The mental model (Rails → TS)

A type is **schema + validations, run at compile time**:

- `strict: true` in `personal_manager/mobile/tsconfig.json`
  = validations enabled globally. `strictNullChecks` makes
  `string | null` a different type from `string`, so every nullable
  serializer field forces a handled-nil branch at every call site —
  `validates :x, presence: true`, but enforced on read, not on save.
- `any` = `save(validate: false)`.
- A single `as T` cast = `update_column` — skips the checks, correct
  only if *you* are right.
- `as unknown as T` (double-cast) = `update_column` with the table name
  taken on faith — it silences **structural** checking entirely. Banned
  in `mobile/AGENTS.md` → Forbidden as of this session.

TypeScript is **structural** (duck typing, checked): an object literal
*is* a `NotificationRow` if its shape matches — no class, no
declaration, no `include`. Compatibility is directional: a non-null
`actor: { id; name }` is assignable to `actor: { id; name } | null`,
never the reverse.

## The audit (repeatable)

```bash
cd mobile
grep -rn -E ': any|as any|any\[\]|<any>|as unknown as' src/features \
  --include="*.ts" --include="*.tsx" | grep -v test
```

Expected today: **no output** (clean). On 2026-06-12 it returned exactly
one hit across all 14 feature dirs — `FriendsScreen.tsx:108` — and the
only other `any` matches repo-wide were the English word "any" in UI
strings (always eyeball grep hits before believing them).

## The one real finding, and the fix

`FriendsScreen.tsx` prepended a live notification as:

```ts
{ id: Date.now(), read_at: null, ...event } as unknown as NotificationRow,
```

But spreading `NotificationEvent` (`category`, `actor`, `metadata`,
`created_at`) plus `id` and `read_at: null` is *structurally* a
`NotificationRow` already. Proven before editing with a scratch file:

```ts
declare const event: NotificationEvent;
const row: NotificationRow = { id: Date.now(), read_at: null, ...event };
```

→ `tsc --noEmit` exit 0. The cast was vestigial (the two types had
converged since it was written) and actively harmful: with it, a future
`NotificationRow` field rename keeps compiling while the line builds a
wrong object. Fix = delete the cast, nothing else.

**Method to reuse:** when you suspect a cast is dead, don't argue —
write the plain assignment in a scratch `.ts` file, run `tsc`, delete
the file. The compiler is the referee.

## Side artifact

`mobile/package.json` gained `"typecheck": "tsc --noEmit"` (web/ already
had one). Verify:

```bash
cd mobile && npm run typecheck
```

Expected: silent, exit 0.

## The full track (all topics complete, 2026-06-12)

[ts-02 strict mode](ts-02-strict-mode.md) ·
[ts-03 serializer↔client drift](ts-03-serializer-type-drift.md) ·
[ts-04 generics](ts-04-generics.md) ·
[ts-05 typed navigation](ts-05-typed-navigation.md) ·
[ts-06 native modules vs Expo SDK](ts-06-native-modules-vs-expo-sdk.md) ·
[ts-07 typed storage](ts-07-typed-storage.md) ·
[ts-08 EAS build profiles](ts-08-eas-build-profiles.md) — the session
that created `mobile/eas.json`.
