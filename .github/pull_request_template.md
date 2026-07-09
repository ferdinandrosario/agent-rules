<!--
  PR template — mirrors the rules in AGENTS.md and docs/CONTRIBUTING.md.
  Delete any section that genuinely doesn't apply, but don't delete a
  section just to skip the work it asks for.
-->

## What & why

<!-- One paragraph: what this change does and the reason for it. Link the
     issue if there is one. -->

## Surface

<!-- Tick what this PR touches. AGENTS.md forbids cross-codebase changes
     in a single COMMIT — backend / web / mobile each get their own commit
     even within one PR. -->

- [ ] backend (`backend/`)
- [ ] web (`web/`)
- [ ] mobile (`mobile/`)
- [ ] docs (`docs/`)
- [ ] meta / CI (`.github/`, root configs)

## Checklist

- [ ] **Docs updated in the same PR** — every code change has its matching
      doc update (setup · architecture · running · troubleshooting, plus
      the canonical `docs/feature/<feature>.md`). Each commit message
      carries the why; change history lives in git.
- [ ] **Tests** — backend at 100% line coverage; web / mobile at or above
      the `jest.config.js` pins. New behaviour ships with its spec.
- [ ] **Lint / typecheck** clean — `bin/rubocop` (backend) · `npm run lint`
      (web) · `npx tsc --noEmit` (mobile).
- [ ] **Security scans** clean — `bundler-audit` (backend) · `npm audit
      --audit-level=moderate` (web / mobile).
- [ ] **No new dependency** without a one-paragraph justification below
      (what it does, why a stdlib / framework version doesn't cut it,
      exact version pin).
- [ ] **No `TODO` / placeholder / commented-out code.**
- [ ] **Versions** — any pinned-version bump ran the repo-wide
      version-bump audit grep (AGENTS.md "VERSION & STABILITY").

## Verification

<!-- Paste the commands you ran and their expected output — a command
     without its success signal is incomplete (e.g. `bundle exec rspec`
     → `N examples, 0 failures, 100% line coverage`). -->

```
```

## Notes for the reviewer

<!-- Layer-rule violations you're flagging without fixing, follow-ups,
     anything that needs a second opinion. -->
