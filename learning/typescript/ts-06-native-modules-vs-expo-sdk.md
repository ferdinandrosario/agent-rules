# Session 6 — Native modules vs the Expo SDK

Notes for topic 6 of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-05-typed-navigation.md`](ts-05-typed-navigation.md).

## The three tiers (Rails mapping)

1. **Expo SDK packages** — framework-blessed gems. Versioned with the
   SDK (`~56.x` here), config-plugin native setup, work in Expo Go.
2. **Community native libraries with Expo support** — well-maintained
   gems with C extensions that compile cleanly: native code exists but
   someone else maintains the bridge; config plugins or autolinking
   handle the wiring.
3. **Custom native modules** — writing your own C extension. Commits
   you to development builds (no Expo Go), per-platform expertise, and
   owning the bridge forever. Last resort.

Decision rule: search tier 1 → tier 2 → only then tier 3.

## This app, classified (against `mobile/package.json`, 2026-06-12)

| Tier | Dependencies |
|---|---|
| 1 — Expo SDK | `expo`, `expo-document-picker`, `expo-image-picker`, `expo-location`, `expo-notifications`, `expo-secure-store`, `expo-splash-screen`, `expo-status-bar` |
| 2 — community native | `react-native-maps` (the one residual proprietary tie: Android needs a Google Maps API key, see `mobile/AGENTS.md`), `@shopify/react-native-skia` + `victory-native` (charts render on Skia), `react-native-reanimated` + `react-native-worklets` + `react-native-gesture-handler`, `react-native-safe-area-context`, `react-native-screens`, `react-native-svg`, `@react-native-async-storage/async-storage` |
| 3 — custom native | **none** |
| JS-only (no native code) | `nativewind` + `tailwindcss@3.4.17` (pin: NativeWind v4 lacks Tailwind v4 support), `@react-navigation/*`, `@rn-primitives/*`, `class-variance-authority`, `clsx`, `tailwind-merge`, `lucide-react-native` |

Zero tier-3 entries is the healthy state: every native capability this
app needs ships with maintained bridges, and the empty tier is what
keeps the managed Expo workflow (and EAS builds, session 8) simple.

## What would justify tier 3

A capability with no tier-1/2 coverage that is core to the product —
e.g. a vendor's hardware SDK. The cost side: a dev-client-only
workflow, Kotlin/Swift maintenance, and the bridge breaking on every
RN architecture change. For this app, nothing on the roadmap clears
that bar.

## Verify

```bash
cd mobile && npm test -- --silent 2>&1 | tail -4
```

Expected: all suites pass — the native tier-2 modules are mocked for
Jest (e.g. `__mocks__/react-native-maps.tsx`), which is itself a cost
of native deps worth remembering.
