# Session 2 — What `strict: true` actually enforces

Notes for topic 2 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-01-structural-typing.md`](ts-01-structural-typing.md).

## The bundle

`strict: true` (on in `personal_manager/mobile/tsconfig.json`
via the flag itself; `expo/tsconfig.base` provides the rest) enables a
family of flags. The four felt daily, with their Rails mapping:

| Flag | Rails mapping |
|---|---|
| `strictNullChecks` | `presence: true` enforced at every **read** — `string \| null` won't pass where `string` is required |
| `noImplicitAny` | an untyped param is a migration without a schema — rejected, not guessed |
| `useUnknownInCatchVariables` | `rescue => e` where `e` is untyped until you check its class |
| `strictFunctionTypes` | callback signatures are contracts, not suggestions |

## Real errors (reproduced 2026-06-12 against our own types)

Lab method from ts-01: scratch file in `src/`, run `tsc`, delete. Each
sin used `NotificationRow` from
`src/features/friends/friends-client.ts` (`read_at: string | null`):

| Sin | Error |
|---|---|
| `row.read_at.slice(0, 10)` | `TS18047: 'row.read_at' is possibly 'null'.` |
| `function shout(label) {…}` | `TS7006: Parameter 'label' implicitly has an 'any' type.` |
| `const when: string = row.read_at` | `TS2322: Type 'string \| null' is not assignable to type 'string'.` |
| `catch (e) { return e.message }` | `TS18046: 'e' is of type 'unknown'.` |

## Idiomatic fixes (in preference order)

1. **Guard clause** — the house idiom, live at
   `personal_manager/mobile/src/features/friends/format.ts`:
   `if (!iso) return 'Offline';` narrows `string | null` → `string`
   for the rest of the function.
2. **`??` fallback** — `row.read_at ?? '—'` when a display default is
   the right semantics.
3. **Honest type** — widen the receiving type to `string | null` and
   let the nil flow to where it's actually handled.
4. **`instanceof` for catch** —
   `e instanceof Error ? e.message : 'unknown error'`.

**Never `!`** (postfix non-null assertion). It is the `update_column`
of null-checks: compiles today, crashes at runtime when the assumption
breaks. The codebase currently has zero of them; keep it at zero.

## Verify

```bash
cd mobile && npm run typecheck
```

Expected: silent, exit 0. When piping `tsc` output through `grep` to
filter a file, remember the pipeline's exit code is **grep's** — exit 1
means "no matching error lines", i.e. success.
