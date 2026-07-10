# Session 5 — Typed navigation (React Navigation, not Expo Router)

Notes for topic 5 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-04-generics.md`](ts-04-generics.md).

## What this app uses, and why that's fine

The stack is **React Navigation 7** (`@react-navigation/native-stack`),
not Expo Router. Expo Router is file-based routing layered on top of
React Navigation — `app/profile.tsx` becomes `/profile`, Rails-style
convention-over-configuration, with deep links derived from the file
tree. This app instead declares routes explicitly and handles deep
links manually in
`personal_manager/mobile/src/features/auth/linking.ts`
(only the two token-carrying auth screens need them).

**Verdict: stay.** Migrating 20 working, tested routes to a file-tree
layout buys URL-parity features this app doesn't use. Revisit only if
the deep-link surface grows beyond auth.

## How the typing works (the routing face of ts-03's contract idea)

`personal_manager/mobile/src/features/auth/types.ts` is
the single source of truth — `RootStackParamList` maps every route
name to its params (audited 2026-06-12: all 20 routes present;
`undefined` = takes no params; `ResetPassword` / `ConfirmEmail` carry
`{ token?: string }`). `RootStackScreenProps<'Land'>` derives each
screen's full prop type from it — `routes.rb` plus compile-time
checking of every `link_to`.

## Proof it bites (scratch-lab, reproduced 2026-06-12)

```ts
declare const nav: NativeStackNavigationProp<RootStackParamList>;
nav.navigate('ResetPassword', { token: 'abc' }); // compiles — declared param
nav.navigate('Land', { wrongParam: 1 });
// TS2345: Argument of type '{ wrongParam: number; }' is not assignable
//         to parameter of type 'undefined'.
nav.navigate('Nope');
// TS2769: No overload matches this call.
```

Wrong params and unknown routes are compile errors, not runtime 404s.

## Maintenance rule (already implied, now explicit)

Add a screen → add its row to `RootStackParamList` in the same change;
the navigator in `App.tsx` and every `navigate` call site won't
typecheck otherwise — the param list cannot silently drift the way a
hand-mirrored serializer type can.

## Verify

```bash
cd mobile && npm run typecheck
```

Expected: silent, exit 0.
