# Learning — how the production pieces work

Standalone learning library (extracted from `personal_manager/docs/learning`
on 2026-07-10): servers, deployment, Rails, React, and TypeScript, written
for someone building the understanding from scratch. It is a **template and
reference for every app** — study a topic here, then apply it in whichever
project you're building. If you want to **ship**, not learn, go straight to
that app's production deploy docs (e.g.
`personal_manager/deploy/README.md`).

Every guide explains *why* each piece exists, not just what to type. The
worked examples reference `personal_manager` (the app these guides were
written against) — `personal_manager/<path>` mentions point into that repo
at `~/Downloads/personal_manager`. No production deployment depends on
anything in this repo.

## Servers & deployment (Linux, SSH, Nginx, PostgreSQL, hardening)

| Guide | What it teaches |
|---|---|
| [aws/aws-ec2-ladder.md](aws/aws-ec2-ladder.md) | **Start here.** The 5-level ladder: one production concern per rung, from a bare EC2 box to containers + CD |
| [deploy/deploy-level-1-plain-rails.md](deploy/deploy-level-1-plain-rails.md) | Ladder Level 1 — one box, Puma serves everything: EC2, security groups, SSH, swap, PostgreSQL/PostGIS, systemd, `RAILS_ENV=production` |
| [deploy/deploy-level-2-nginx.md](deploy/deploy-level-2-nginx.md) | Ladder Level 2 — Nginx in front of Puma: reverse-proxy thinking, static files, `conf.d`, the fullest "pieces in plain words" glossary |
| [devops/devops-01-same-origin-reverse-proxy.md](devops/devops-01-same-origin-reverse-proxy.md) | Why the web app and API share one origin behind the proxy — CORS, cookies, and the Nginx config that does it |
| [aws/aws-deployment-template.md](aws/aws-deployment-template.md) | A reusable, explained AWS deployment template for *any* app — not personal_manager-specific |
| [aws/aws-secure-hosting.md](aws/aws-secure-hosting.md) | The app-agnostic defense-in-depth model (identity → network → edge → host → data → app → detection) with a CIS-aligned audit list |

The runnable forms of the Level 1–2 guides live in
[`deploy/scripts/`](deploy/scripts/deploy-level-1-plain-rails.sh) — each
script is its guide's commands in one idempotent pass.
[`deploy/scripts/deploy-sheet.awk`](deploy/scripts/deploy-sheet.awk)
condenses either guide into a per-step paste sheet
(`deploy/scripts/deploy-sheet.awk deploy/deploy-level-1-plain-rails.md`).

## Rails

| Guide | What it teaches |
|---|---|
| [rails/rails-01-solid-queue.md](rails/rails-01-solid-queue.md) | How Solid Queue runs the app's background jobs and recurring reminders |
| [rails/rails-advanced-curriculum.md](rails/rails-advanced-curriculum.md) | A structured path through advanced Rails topics, keyed to this codebase |

## React (web)

| Guide | What it teaches |
|---|---|
| [react/react-01-hooks.md](react/react-01-hooks.md) | Hooks as used in this codebase |
| [react/react-02-data-fetching.md](react/react-02-data-fetching.md) | Data fetching patterns |
| [react/react-03-forms.md](react/react-03-forms.md) | Form state and validation |
| [react/react-04-suspense.md](react/react-04-suspense.md) | Suspense and loading states |
| [react/react-05-vite-spa-vs-rsc.md](react/react-05-vite-spa-vs-rsc.md) | Why this app is a Vite SPA, versus server components |
| [react/react-06-shadcn-patterns.md](react/react-06-shadcn-patterns.md) | shadcn/ui component patterns |
| [react/react-07-testing.md](react/react-07-testing.md) | Testing the web app |

## TypeScript (mobile)

| Guide | What it teaches |
|---|---|
| [typescript/ts-01-structural-typing.md](typescript/ts-01-structural-typing.md) | Structural typing fundamentals |
| [typescript/ts-02-strict-mode.md](typescript/ts-02-strict-mode.md) | What strict mode catches |
| [typescript/ts-03-serializer-type-drift.md](typescript/ts-03-serializer-type-drift.md) | Keeping API types in step with backend serializers |
| [typescript/ts-04-generics.md](typescript/ts-04-generics.md) | Generics as used in the mobile codebase |
| [typescript/ts-05-typed-navigation.md](typescript/ts-05-typed-navigation.md) | Type-safe navigation with React Navigation (not Expo Router) |
| [typescript/ts-06-native-modules-vs-expo-sdk.md](typescript/ts-06-native-modules-vs-expo-sdk.md) | When you need a native module versus the Expo SDK |
| [typescript/ts-07-typed-storage.md](typescript/ts-07-typed-storage.md) | Typed wrappers over device storage |
| [typescript/ts-08-eas-build-profiles.md](typescript/ts-08-eas-build-profiles.md) | EAS build profiles and what each is for |

## Working through it

[learning-prompts.md](learning-prompts.md) is the prompt pack: ready-made
prompts for studying each of the topics above with an AI assistant against
the reference app.

## Conventions

- One subfolder per topic; this README indexes every guide.
- `rails/`, `react/`, `typescript/`, and `devops/` hold curricula plus
  dated session journals (`rails-NN` / `react-NN` / `ts-NN` /
  `devops-NN`). **A journal existing marks its curriculum topic done** —
  never merge or rename one; a move keeps the filename.
