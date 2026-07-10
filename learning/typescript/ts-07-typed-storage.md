# Session 7 — Offline state and typed storage boundaries

Notes for topic 7 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-06-native-modules-vs-expo-sdk.md`](ts-06-native-modules-vs-expo-sdk.md).

## The principle

Device storage and the network both hand you **untyped strings**. The
type system only helps if each boundary has exactly one owner module
that converts `string | null` (or `any` from `JSON.parse`) into a
domain type — after that, `strict` carries the guarantee everywhere.
Rails mapping: it's the attribute-casting layer; raw params never
leak past it.

## This app's boundaries (audited 2026-06-12 — all owned, no leaks)

| What | Store | Owner module | Conversion at the boundary |
|---|---|---|---|
| JWT | `expo-secure-store` (Keychain/Keystore) | `personal_manager/mobile/src/features/auth/auth-client.ts` `getStoredToken` / `setStoredToken` | Plain `string \| null`, no parse needed. `try/catch` → `null`/no-op because SecureStore is absent on the Expo web target — degradation is *typed* (`Promise<string \| null>`), not thrown. |
| Theme | `AsyncStorage` | `personal_manager/mobile/src/lib/theme.ts` `getStoredTheme` | **User-defined type guard** — the pattern to copy: `isThemeMode(value): value is ThemeMode` narrows the raw string; anything else falls back to `'system'`. A corrupt or stale value can never produce an invalid `ThemeMode`. |
| WebSocket frames | network | `personal_manager/mobile/src/features/friends/cable.ts`, `features/task-planner/reminders.ts` | `JSON.parse` result assigned into an annotated local (`{ type?; identifier?; message?: T }`) — an **assertion, not a check** (`JSON.parse` returns `any`, which assignment silently trusts). Acceptable here: the `identifier` equality gate drops foreign frames, and the payload type is the serializer contract from ts-03. |
| Token in flight | secure store → React state | `App.tsx` gate via `getStoredToken()` on boot | Kill-and-relaunch stays logged in; the only persistence of auth is the SecureStore entry. |

Why token ≠ theme storage: SecureStore is encrypted keychain storage
for secrets; AsyncStorage is plaintext for non-sensitive UI state —
credentials vs cookies. The *why* comments live in both owner modules.

## The two patterns to remember

1. **`value is T` type guard** (`isThemeMode`) — the honest way to
   turn runtime strings into union types. This is the runtime
   validation `strict` cannot do for you, at the only place it's
   needed.
2. **`JSON.parse` is `any` in disguise** — annotating the receiving
   variable is a *claim*, not a *check*. Fine for trusted,
   identifier-gated channels; if an untrusted or versioned payload
   ever crosses this boundary, upgrade the claim to a guard like
   pattern 1.

## Verify

```bash
cd mobile && npm run typecheck && npx jest theme auth-client --silent 2>&1 | tail -3
```

Expected (reproduced 2026-06-12): typecheck silent (exit 0), then
`Test Suites: 6 passed, 6 total` / `Tests: 40 passed, 40 total`
(theme, theme-toggle, and auth-client suites × iOS/Android presets).
In the simulator: log in, kill the app, relaunch → still logged in
(SecureStore survives process death; that's the offline story for
auth).
