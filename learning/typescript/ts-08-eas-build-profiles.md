# Session 8 — EAS build profiles

Notes for topic 8 (final) of the TypeScript-via-`mobile/` track
([`learning-prompts.md`](../learning-prompts.md) prompt 4). This file
existing marks the topic done. Follows
[`ts-07-typed-storage.md`](ts-07-typed-storage.md).

## The Rails mapping

EAS build profiles are **environments for binaries**: one codebase,
per-profile build configuration — except unlike `RAILS_ENV`, the env
is **baked into the artifact at build time** (`EXPO_PUBLIC_*` vars are
string-substituted into the JS bundle). You can't repoint a built
binary at a different API; you rebuild.

## What this session shipped

`personal_manager/mobile/eas.json` — previously absent (the
docs said `eas build:configure` would generate it; it's now committed
and the doc flow updated). Canonical profile table:
`personal_manager/docs/deployment/mobile-eas-build.md`.

The three decisions encoded in the file, and why:

1. **`development` has no baked env** — a development-client build
   loads JS from Metro, so `EXPO_PUBLIC_API_BASE_URL` comes from the
   dev machine at runtime (per-target table in `mobile/AGENTS.md`
   "Base URL by environment"). Baking one would be misleading.
2. **`preview` = internal distribution, production API** — the
   TestFlight/Play-internal rung: release-mode binary, real backend,
   no store review. `https://api.example.com` is the repo's
   placeholder-domain convention (same as the production env tables) —
   set the real origin before building.
3. **`appVersionSource: "local"`** — `ios.buildNumber` /
   `android.versionCode` live in `app.json` and are bumped by hand,
   which is what `09-deployment.md` already documented. `remote` +
   `autoIncrement` is the upgrade if hand-bumping ever produces a
   rejected duplicate upload; until then, local keeps `app.json` the
   single source of truth.

## Verify

Repo side (no Expo account needed):

```bash
node -e "JSON.parse(require('fs').readFileSync('mobile/eas.json','utf8')); console.log('eas.json: valid JSON')"
```

Expected: `eas.json: valid JSON`.

Cloud side (needs `npm install -g eas-cli` — machine install, run
yourself — and `eas login`):

```bash
cd mobile && eas build --profile preview --platform ios
```

Expected: EAS prints the build-details URL
(`https://expo.dev/accounts/<account>/projects/personal_manager/builds/<id>`),
then the `.ipa` download link on completion.
