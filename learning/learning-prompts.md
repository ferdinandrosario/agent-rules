# AI learning-prompt pack

Reusable prompts for training the maintainer across the full stack —
advanced Rails, modern React, React Native + TypeScript, AWS DevOps,
cost/scaling, billing, store publishing, and AI engineering — using
this repo as the lab. Every session is expected to end with an
artifact committed to the repo (per the
`personal_manager/docs/CONTRIBUTING.md` checklist), so the
learning accumulates into the repo's own handbook instead of
evaporating in chat history.

## How to run sessions — one prompt per session

Paste the [master context block](#master-context-block) first in every
new session, then **exactly one** topic prompt. Do not stack multiple
topic prompts into a single session:

- **Focus.** A model gives noticeably better depth on one topic than
  on nine; stacked prompts get nine shallow answers.
- **Context budget.** Long sessions hit compaction/summarization; the
  early prompts' constraints (docs-first, expected outputs, confirm
  before acting) silently fall out of the summary and quality drifts.
- **Resumability.** One-topic sessions can be picked up days later by
  re-pasting the master block plus one progress line; a mega-session
  cannot be resumed cold.
- **Artifacts.** Each prompt maps to one deliverable in the repo (table
  below); one session per deliverable keeps each change-set a single
  reviewable commit per codebase, as `personal_manager/AGENTS.md`
  requires.

The curriculum prompts (2, 3, 4, 9) span multiple lessons. Run **one
lesson per session**: master block, the topic prompt, plus a progress
line such as `Progress: topics 1–3 done (see git log);
start topic 4.` Pointing at the git log makes the session verify
progress against the repo instead of trusting the claim.

| # | Prompt | Deliverable |
|---|--------|-------------|
| 1 | Architecture review | written report → roadmap entries |
| 2 | Advanced Rails curriculum | [`docs/learning/rails/rails-advanced-curriculum.md`](rails/rails-advanced-curriculum.md) + per-topic notes in `docs/learning/` + the exercise's feature doc |
| 3 | Modern React via `web/` | per-topic notes + updated `03-web-setup.md` if setup changes |
| 4 | TypeScript via `mobile/` | per-topic notes + updated `04-mobile-setup.md` if setup changes |
| 5 | Deploy ladder Levels 6+ | `deploy-level-N-*.md` per level |
| 6 | Cost + scaling plan | staged cost/scale doc |
| 7 | Subscription module design | design doc, then `feature/billing.md` when built |
| 8 | Store publishing | release checklist doc |
| 9 | AI engineering curriculum | per-phase notes + the built feature's doc |
| 10 | Web launch hardening (SEO + performance) | ticks in `personal_manager/deploy/shared/production-readiness.md` + `personal_manager/docs/web/setup.md` |
| 11 | Accessibility (WCAG AA) audit | ticks in `deploy/shared/production-readiness.md` + `personal_manager/docs/feature/ui.md` |
| 12 | Email deliverability (SPF/DKIM/DMARC) | ticks in `deploy/shared/production-readiness.md` + `personal_manager/docs/deployment/README.md` |

## Master context block

```text
CONTEXT (reuse in every session):
I am a senior staff engineer with deep Ruby on Rails experience and some React.
I have NOT worked in DevOps, infra, TypeScript, React Native, or AI tooling — treat
me as expert in Rails, beginner elsewhere. Explain non-Rails concepts by analogy
to Rails where possible.

My project: "personal_manager", a SaaS-style monorepo at three layers:
- backend/  — Rails 8.1 API-only (PostgreSQL + PostGIS, Rails defaults: Solid
  Queue/Cache/Cable), 100% line coverage enforced
- web/      — React 19 + Vite + Tailwind v4 + shadcn/ui (JavaScript + incremental TypeScript)
- mobile/   — Expo + React Native + NativeWind + react-native-reusables (TypeScript)
- docs/     — source of truth: numbered guides 00–10, per-feature canonical
  files under feature/, observability.md, security.md, and the feature
  inventory in FEATURES.md
- deploy/   — production deployment paths (ladder levels 3–5: CD hardening,
  RDS/S3, Docker+Kamal)
- docs/learning/ — teaching material: ladder levels 1–2 (plain Rails → nginx),
  aws-deployment-template.md, curricula, dated session notes

My rules — AGENTS.md in the repo root is the single source of truth (the
ABSOLUTE RULES list plus the sections it references); read it before doing
work. The working subset that binds every session below, each tagged to its
canonical home so you can see when this list has drifted from AGENTS.md:
- Docs are first-class — every code change ships its matching doc update
  (docs/CONTRIBUTING.md checklist).
- Every command you give shows its expected output / success signal
  (docs/AGENTS.md style rules).
- Prefer boring, idiomatic, well-documented choices a future maintainer can
  extend cold (rule 6).
- Before editing any file, list the open choices and planned actions, and wait
  for my confirmation.
- 100% backend line coverage; 90% floor on web/mobile (rule 9).
- Verify every count, version, and path against the live file, never from memory
  (rule 12).

My goal: use this one project to become production-ready in advanced Rails,
modern React, React Native + TypeScript, AWS DevOps, and AI engineering — well
enough that I don't need to search or ask AI for day-to-day work afterward.

End every session by checking the artifact against the docs/AGENTS.md standard
(a zero-context maintainer can rebuild it from the doc alone) and rule 12
(every fact verified against the live repo, not chat memory).
```

## 1 — Architecture review

```text
Act as a principal engineer doing an architecture review of personal_manager.

1. Read docs/architecture/overview.md, docs/development/conventions.md, and the deploy-level
   docs, then scan backend/, web/, and mobile/ for the actual implementation.
2. Produce a review with these sections:
   - WRONG or risky architecture decisions (be blunt; say why and what breaks
     at scale)
   - Improvements ranked by impact/effort, each with the concrete files to change
   - Things I'm doing RIGHT that I should not "modernize" away
   - Mandatory current tools/trends I'm missing (only ones that earn their
     complexity)
   - For each finding: what a 1-user app vs a 10k-user SaaS needs — mark which
     findings only matter at scale so I don't over-engineer now.
3. Do NOT change any code. Output a written report I can turn into a docs/
   roadmap.
```

## 2 — Advanced Ruby / Rails curriculum

```text
Build me a 4-week advanced Rails curriculum that uses ONLY my personal_manager
backend as the lab. I already know everyday Rails — skip basics.

Cover: the Solid trifecta (Solid Queue/Cache/Cable), advanced ActiveRecord
(locking, counter caches, query objects, N+1 elimination), concurrency and
connection pools, multi-tenancy patterns, Rack internals and middleware, rate
limiting, API versioning, background-job idempotency, and current Ruby features.

For each topic: (a) a 1-paragraph explanation, (b) a hands-on exercise that adds
or refactors something real in backend/, (c) how to verify it worked (command +
expected output), (d) the doc file I should write afterward. Before editing
backend/, show the lesson's plan and wait for my go. One topic per session;
start with the next unfinished topic per my progress line.
```

## 3 — Modern React (JavaScript + incremental TypeScript) via `web/`

```text
Teach me modern React using my web/ app, mapping every concept to something
I already shipped. Cover: hooks mental model, data fetching with TanStack Query
vs my current approach, forms, Suspense, when Next.js/RSC matters vs when a
Vite SPA is fine (and why my choice is/isn't right), component patterns in
shadcn/ui, and testing with the repo's existing test stack. Same format:
explain → exercise in web/ → verify command + expected output → doc to write.
Before editing web/, show the lesson's plan and wait for my go. One topic per
session; start with the next unfinished topic per my progress line.
```

## 4 — TypeScript + React Native via `mobile/`

```text
Teach me TypeScript through my mobile/ Expo app, as a Rails developer: map
types to "schema + validations at compile time". Cover: strict mode, typing
API responses end-to-end from my Rails serializers, generics only as far as I
need them, Expo Router, native modules vs Expo SDK, offline/state patterns,
and EAS build profiles. Audit my existing mobile/src/features/* typing first
and fix the worst file together with me as lesson 1. Same format as the Rails
curriculum: explain → exercise in mobile/ → verify command + expected output →
doc to write. Before editing mobile/, show the lesson's plan and wait for my go.
One lesson per session; start with the next unfinished topic per my progress line.
```

## 5 — Deploy ladder Levels 6+

```text
I have docs/learning/deploy/deploy-level-1 through deploy-level-5 (plain Rails → nginx → CD
hardening → RDS/S3 → Docker+Kamal). Continue this ladder as levels 6+, keeping
the same docs-first, one-level-at-a-time style:
- Level 6: infrastructure as code (Terraform vs CDK — pick one, justify)
- Level 7: container orchestration (ECS Fargate vs Kubernetes — pick for a
  solo-maintainer SaaS, justify)
- Level 8: observability (logs/metrics/traces/alerts) and zero-downtime deploys
  beyond what observability.md already covers
- Level 9: security hardening, secrets, backups, disaster-recovery drill beyond
  what security.md and deploy-level-4-rds.md already cover
For the next level only: list open choices, wait for my confirmation, then give
step-by-step instructions where every command shows expected output, and end
with the doc file content for deploy/aws/deploy-level-N.
```

## 6 — Cost cutting + scaling re-architecture

```text
Cost-and-scale plan for personal_manager as a SaaS on AWS. Read
docs/learning/aws/aws-deployment-template.md and the deploy-level docs first.

Give me a staged plan keyed to user count: 0–100, 100–1k, 1k–10k, 10k–100k
users. For each stage: monthly AWS cost estimate (cheapest sane setup), what to
change in architecture BEFORE the next stage hurts, and what NOT to buy yet.
Specifically address: instance right-sizing vs serverless, RDS vs cheaper
Postgres options, S3 + CloudFront, caching layers (when Redis earns its cost
over Solid Cache), background-job hosting, reserved/spot savings, and the
single biggest cost trap for Rails apps on AWS. Rule: cost per user should go
DOWN as users go up — show how each stage achieves that. No code changes;
output a doc for docs/.
```

## 7 — Subscription module (India + abroad)

```text
Design a subscription/billing module for personal_manager (Rails API + React
web + Expo mobile). Requirements:
- India: UPI + cards via Razorpay, RBI e-mandate rules for recurring payments,
  GST invoicing
- Abroad: Stripe, multi-currency pricing, EU VAT awareness
- Mobile: explain Apple/Google in-app purchase rules — when I'm FORCED to use
  IAP vs when web checkout is allowed, and the commission impact
- Plans: free tier, monthly, yearly; proration, grace periods, dunning,
  webhooks as the source of truth (never trust client redirects)
First: present the data model (subscriptions, plans, payments, webhook events),
the provider-abstraction design so Razorpay/Stripe sit behind one interface,
and all open choices. Wait for my confirmation before writing any code.
```

## 8 — Publishing to the app stores

```text
Walk me through shipping mobile/ (Expo + React Native) to both stores as a
first-time publisher. Cover, in order, with expected output for every command:
1. Accounts: Apple Developer ($99/yr) and Google Play ($25 one-time) — exact
   signup steps and India-specific gotchas (D-U-N-S for company accounts)
2. EAS Build + EAS Submit: configure eas.json profiles for my repo
3. Store assets: icons, screenshots, privacy policy (I have
   docs/legal/privacy-policy.md), data-safety forms
4. Review process: common rejection reasons for an app like mine and how to
   avoid them; Google's closed-testing requirement for new personal accounts
5. OTA updates with EAS Update vs store releases — what's allowed
End with a release checklist for docs/ I can rerun for every version.
```

## 9 — AI engineering + prompting

```text
Teach me AI engineering as a Rails developer, using personal_manager as the lab.
Phase 1 — prompting: system vs user prompts, structured output, few-shot,
chain of thought, evals; exercise: design the prompts for an AI feature in my
app (e.g., natural-language task entry → structured Rails params).
Phase 2 — integration: call Claude's API from Rails (recommend the official
SDK or raw HTTP, justify), streaming to my React frontend, token costs,
caching.
Phase 3 — patterns: RAG over my own docs/ folder, tool use / function calling
mapped to my Rails service objects, and when agents are overkill.
Each phase: explain → build a small real feature → verify → write the doc.
Before editing any codebase, show the phase's plan and wait for my go. One phase
per session; start with the next unfinished phase per my progress line.
```

## Launch-readiness prompts (10–12)

Prompts 1–9 build skills; 10–12 close the **launch-readiness gaps** tracked in
`personal_manager/deploy/shared/production-readiness.md` §
"Application launch-readiness" that the earlier prompts don't already cover.
Don't duplicate those: backend performance is prompt 2, deploy
observability/security/backups is prompt 5, cost/scale is prompt 6, and billing
is prompt 7. Each prompt below maps to ticks in `production-readiness.md` plus
one canonical doc.

## 10 — Web launch hardening (SEO + performance)

Per-route SEO (head tags + `sitemap.xml` / `robots.txt` from `src/seo/routes.ts`)
and the dashboard bundle split already shipped — see
`personal_manager/deploy/shared/production-readiness.md` §
"Application launch-readiness" and `personal_manager/docs/web/setup.md` "SEO" /
"Bundle analysis & code-splitting". This prompt covers what remains.

```text
Finish web/ launch hardening. Per-route SEO (head tags + sitemap/robots from
src/seo/routes.ts) and route + bundle code-splitting already shipped — do NOT
redo them. Remaining: (a) set the production canonical origin by building with
VITE_SITE_URL=https://app.<real-domain> and verify dist/sitemap.xml,
dist/robots.txt, and the canonical/OG tags use it (not the app.example.com
placeholder); (b) decide on prerendering the five public auth routes for non-JS
social scrapers — implement the SSG build step or consciously defer it (see the
CSR caveat in docs/web/setup.md "SEO"); (c) wire field Core Web Vitals
(LCP/INP/CLS) through real-user monitoring in production, not a synthetic local
run. Read docs/web/setup.md "SEO" and deploy/shared/production-readiness.md
first. Before editing web/, list the changes and wait for my go. Deliverable:
tick the remaining SEO / Performance items in deploy/shared/production-readiness.md.
```

## 11 — Accessibility (WCAG 2.2 AA) audit

```text
Audit web/ and mobile/ for WCAG 2.2 AA. shadcn/ui (web) and
react-native-reusables (mobile) are Radix-based and accessible by default, so
focus on custom composition: keyboard navigation and focus order, color contrast
against the teal theme, alt text, and ARIA / accessibilityRole on custom
controls. Separately verify every async view renders explicit loading, empty,
and error states. Read docs/feature/ui.md first. Give me a prioritized list with
file:line and the fix; apply the unambiguous ones and show me the diff. Before
editing, list what you'll change and wait for my go. Deliverable: tick the
Accessibility items in deploy/shared/production-readiness.md and record the
conventions in docs/feature/ui.md.
```

## 12 — Email deliverability (SPF / DKIM / DMARC)

```text
Make the app's transactional email deliverable. SMTP credentials are already a
production env var (docs/deployment/README.md) and the Devise auth mailers plus the
friendship mailer send real mail — the gap is sender-domain authentication, so
unauthenticated mail is filtered as spam. Cover, with the exact DNS records to
add and how to verify each: (1) SPF, DKIM, and DMARC for the sending domain;
(2) bounce and complaint handling so hard bounces stop retrying. Hand me the DNS
records in the detailed style I expect — record type, host, value, and the dig
verification command with its expected output — since I add them at the registrar
myself. Before editing any code, list the changes and wait for my go.
Deliverable: tick the Email deliverability items in
deploy/shared/production-readiness.md and document the records in
docs/deployment/README.md.
```
