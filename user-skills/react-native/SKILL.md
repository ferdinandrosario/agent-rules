---
name: react-native
description: Use for idiomatic React Native (Expo) best practices — components, hooks, navigation, lists/performance, styling, async/data, and testing — independent of any one repo. Triggers on "how should I build X in React Native", RN/Expo code review, or mobile UI/state design questions.
---

# React Native (Expo) — idiomatic best practices

Framework-level conventions for Expo + React Native + TypeScript apps.
The [`react`](../react/SKILL.md) skill's component/hook/state rules apply
verbatim (purity, derive-don't-duplicate, effect discipline, memoization
judgment, TypeScript strictness) — this skill covers what's *different* on
mobile. When working inside a project, its `mobile/AGENTS.md` is the source
of truth and **overrides** anything here on conflict (version delta, UI
stack, approved libraries, base-URL-by-environment, API contract, testing
gotchas).

Version context: Expo SDK **56** / RN **0.85** era as of 2026. Default to
the **Expo managed workflow** and TypeScript; check `app.json` /
`package.json` before using newer APIs.

**How to read this:** three layers — Foundations for any reader, Everyday
craft as the working vocabulary, Design as the judgment layer. Every rule
carries its why.

## Layer 1 — Foundations

- **Expo managed first.** Reach for an `expo-*` SDK module before a bare RN
  community package, and a config plugin before ejecting. *Why:* the managed
  happy path keeps upgrades, builds (EAS), and native config declarative —
  every step off it is native maintenance you now own.
- **There is no DOM.** `<View>`/`<Text>`/`<Pressable>`, not div/span/button;
  all text must sit inside `<Text>`; styles are camelCased subsets, not CSS.
- **Two threads, one bridge (mental model).** JS logic runs on the JS
  thread; layout/paint on the UI thread. Jank = the JS thread blocked while
  the user scrolls. This one model explains most RN performance rules.
- **`localhost` means the device, not your laptop.** Resolve the API base
  URL per target (iOS simulator `localhost`, Android emulator `10.0.2.2`,
  physical device = LAN IP) via `EXPO_PUBLIC_*` env — never hardcode a host.
- **Safe areas and touch targets:** wrap screens with
  `react-native-safe-area-context` insets (notches/home bars eat fixed
  layouts); interactive targets ≥ 44×44 pt.

## Layer 2 — Everyday craft

### Navigation
- Use the project's router — Expo Router (file-based) or React Navigation
  (explicit stacks); check before adding either. Type the param lists so a
  renamed route param fails at compile time, not on tap.
- Screens stay thin: layout + wiring only; logic and API calls live in
  `features/<name>/` modules the screen imports.
- Auth gating is a navigator-level branch (signed-in stack vs auth stack),
  not per-screen redirects — one decision point, no flash of the wrong UI.

### Lists & performance
- `FlatList` (or FlashList for long/heavy lists) for anything non-trivial;
  never `.map()` a long array inside `<ScrollView>` — ScrollView mounts
  every child at once; virtualized lists mount the visible window.
- Stable `keyExtractor`; memoized, cheap `renderItem`; no inline
  object/function literals in the hot path (each render re-creates them and
  defeats `memo`).
- Animations on the UI thread: Reanimated worklets (or `useNativeDriver`
  for the legacy API). *Why:* a JS-driven animation freezes the moment the
  JS thread does any real work.
- Use `expo-image` for remote images (caching, priority, placeholders);
  size images to their rendered dimensions — decoding a 4MB photo into a
  64px avatar burns memory and scroll performance.

### Styling
- Use the project's system consistently — NativeWind or
  `StyleSheet.create` — don't mix paradigms in one tree. Raw inline style
  objects re-allocate per render; `StyleSheet.create` (or compiled
  className) doesn't.
- Flexbox for layout (`flex: 1`, gap) over hardcoded dimensions;
  `Platform.select` / `Platform.OS` for the rare per-OS delta, kept small
  and local.

### Platform capabilities
- **Permissions are UX:** request in context (ask for camera when the user
  taps "add photo", not at launch), always handle "denied" with a usable
  fallback — the OS may never re-prompt.
- Secrets: `expo-secure-store` (Keychain/Keystore) for tokens; plain
  `AsyncStorage` only for non-sensitive preferences. Anything in
  `EXPO_PUBLIC_*` ships readable inside the bundle — it is config, not a
  secret store.
- Handle the keyboard (`KeyboardAvoidingView`/scroll-into-view) on every
  form screen; assume the network is intermittent — show cached/stale data
  with a refresh affordance rather than a dead spinner.

### Async & data
- Same rules as the `react` skill: one typed API client, loading **and**
  error states on every screen, abort/ignore stale responses, mirror
  backend validation inline next to fields.
- Data libraries (TanStack Query) only where the project allows one; this
  user's repos deliberately stay on `useState` + fetch client — respect the
  project's ceiling.

## Layer 3 — Design (senior/staff judgment)

- **Keep the JS thread idle during interaction.** Defer non-urgent work
  (`InteractionManager`, `startTransition`), paginate instead of rendering
  everything, and push continuous gestures/animations into worklets. Jank
  is architectural before it's micro-optimizable.
- **Native modules are a boundary decision:** Expo SDK module → community
  module with a config plugin → custom native code, in that order of
  preference; each step down adds a build/upgrade liability. Isolate any
  native-touching API behind one TS module so a swap doesn't ripple.
- **Design for the platform matrix.** Every feature ships iOS + Android:
  test both (jest-expo can run both presets), branch with `Platform`
  narrowly, and treat "works on iOS" as half done.
- **Releases are not web deploys.** Store review takes days; a shipped bug
  lives until the next review cycle. EAS Update (OTA) covers JS-only fixes
  on a disciplined channel setup (dev/preview/production); native changes
  always mean a new build + review. Version deliberately.
- **Offline is a state, not an error.** Decide per feature: read-only cache,
  queued writes, or explicit "you're offline" — silence is the one wrong
  answer.

## Testing

- **jest-expo + React Native Testing Library**: query by role/text/label,
  drive with `user-event`/`fireEvent`, assert what the user sees — not
  component internals.
- Mock at real boundaries: **MSW** for the network; `__mocks__/expo-*.ts`
  for native modules (image picker, location, notifications) — the mock
  answers what the device would. Follow the project's documented
  jest-expo/MSW transform gotchas rather than re-deriving them.
- Run the suite against **both platform presets** (iOS + Android projects
  in one jest run) so `Platform.OS` branches are exercised.
- Show the command **and its expected success output**:

  ```bash
  $ npm test
  Test Suites: 188 passed, 188 total
  Tests:       1226 passed, 1226 total
  ```

## Sources

Distilled from the Expo documentation (managed workflow, config plugins,
EAS Build/Update, SecureStore), the React Native docs' performance and
threading guidance, Shopify's FlashList guidance on list virtualization,
Software Mansion's Reanimated worklet model, and React Native Testing
Library's guiding principles — aligned with the `react` skill for
everything platform-independent.

## When in doubt

Prefer the boring, documented Expo/RN pattern over a clever custom one —
the managed-workflow happy path is well-trodden for a reason.
