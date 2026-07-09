# Contributing — Feature Doc Checklist

A "feature" is anything that changes user-visible behavior, adds an endpoint, adds an env var, or pulls in a new dependency. Doc work is not done until every applicable item below is true.

## Always (every feature)

- [ ] **`docs/feature/<feature>.md`** — canonical reference. Module list / endpoints / contract / threat model / env vars / how-to-extend. Reader has zero prior context.
- [ ] **Commit message** — one-paragraph "why" plus the verification command with its real pass output. Change history lives in git, not in a doc.
- [ ] **`docs/FEATURES.md`** — one bullet per surface (Backend / Web / Mobile), linking to `docs/feature/<feature>.md`. No `🆕`/"NEW" prefixes — they rot.
- [ ] **Test coverage** — feature lands at 100% on every dimension the coverage tool measures (lines/branches/functions/statements); 90% floor only with a one-line *why* in the matching `<surface>/AGENTS.md`. Backend is 100% line, no floor. See `AGENTS.md` "TEST COVERAGE".
- [ ] **Validation at all three layers** — if the feature accepts user input, backend model validators (the source of truth) surface through the app's structured validation envelope, web + mobile forms mirror those rules inline, and every attachment is guarded by a max size + MIME allow-list. See `AGENTS.md` "VALIDATION"; the app's concrete mechanism (envelope shape, shared field schema, attachment validator) is recorded in the matching `<codebase>/AGENTS.md` and its `docs/` page.

## Per affected codebase

- [ ] **`docs/backend/setup.md`** if `backend/` changed — file map, new gems, new sub-sections.
- [ ] **`docs/web/setup.md`** if `web/` changed — same.
- [ ] **`docs/mobile/setup.md`** if `mobile/` changed — same.
- [ ] **`<codebase>/.env.example`** if a new env var was added — one-line comment + dev fallback.

## If user-visible behavior or boot semantics changed

- [ ] **`README.md`** — lede + docs table. Delete anything that flatly contradicts the new feature.
- [ ] **`docs/README.md`** — lede and index. A new page must be linked from here (or a page this index reaches) or the orphan check fails.
- [ ] **`docs/architecture/overview.md`** — request-flow section, replacing any stale "why no X" placeholder.

## If new env vars

- [ ] **`docs/getting-started/running-locally.md`** — env-vars table + `curl`/click-path verification.
- [ ] **`docs/deployment/README.md`** — production env-vars table + deploy recipe. Required-vs-optional explicit.

## If new failure modes

- [ ] **`docs/troubleshooting/README.md`** — symptom→fix per failure mode, exact error message + terse fix.

## If non-default libs added

- [ ] **`<surface>/AGENTS.md`** — move the lib from "Forbidden" to "Already-approved" with a one-line PR-reason link. That file is canonical; the Claude skill and Copilot pointer for that surface need no change.

## If AI rules changed (`AGENTS.md` or any `<surface>/AGENTS.md`)

- [ ] Edit the **canonical file only** — `AGENTS.md` for a universal rule, `<surface>/AGENTS.md` for a per-codebase one. The pointer files (`CLAUDE.md`, `.claude/skills/<surface>/SKILL.md`, `.github/copilot-instructions.md`, `.github/instructions/<surface>.instructions.md`) hold no rules and change only when the *wiring* does (new agent/codebase/renamed file). Model + reasoning in [`docs/development/ai-agents.md`](development/ai-agents.md).
- [ ] **`docs/development/ai-agents.md`** — update the tables only if a new agent or codebase was added. Run the **pointer-integrity check** in that file before reporting done.

## Verification ritual

```sh
# 1. Check for stale "no X" claims
rg -i 'no auth|no users|no sessions|no domain' docs/ README.md

# 2. Verify every new env var appears in docs/getting-started/running-locally.md,
#    the deployment env-vars table, and .env.example
# 3. Read docs/README.md and README.md cold — fix anything misleading
```

> This checklist exists because an early feature in the reference app
> shipped with seven doc gaps that a cold reader hit one by one. It is
> the rule that prevents the next feature from shipping with the same
> drift.
