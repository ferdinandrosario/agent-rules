---
name: rails
description: Use for idiomatic Ruby on Rails best practices — models, migrations, controllers/API design, jobs, mailers, callbacks, queries, and testing — independent of any one repo. Triggers on "how should I structure X in Rails", Rails code review, or API/persistence design questions.
---

# Ruby on Rails — idiomatic best practices

Framework-level conventions for Rails apps (API-first by default). For
plain-language Ruby style see the [`ruby`](../ruby/SKILL.md) skill. When
working inside a project, its `backend/AGENTS.md` is the source of truth and
**overrides** anything here on conflict (version delta, API envelope,
approved gems, callback policy, folder layout).

Version context (verify against the project): Rails **8.1.x** on Ruby 4.0.x
as of 2026-11 (Rails 8.2 is still pre-release — don't target it). Check
the `Gemfile` before using newer APIs.

**How to read this:** three layers — Foundations for any reader, Everyday
craft as the working vocabulary, Design as the judgment layer. Every rule
carries its why.

## Layer 1 — Foundations

- **Convention over configuration.** Pluralized tables, `belongs_to`/
  `has_many`, RESTful resources, standard folders. *Why:* every deviation is
  a fact the next reader must discover; the Rails Doctrine's bet is that
  shared convention beats local preference. Deviate only with a written why.
- **Rails 8 defaults are the stack:** Solid Queue (jobs), Solid Cache,
  Solid Cable (websockets), Propshaft — reach for Sidekiq/Redis only when a
  measured need outgrows them.
- **Rails 8.1 additions worth using:** `Rails.event.notify("order.paid",
  order_id: id)` (Event Reporter) for structured, machine-readable
  events instead of string-interpolated log lines; `ActiveJob::Continuable`
  with `step` blocks so a long job resumes from its last completed step
  after a restart/deploy instead of redoing everything; `config/ci.rb` +
  `bin/ci` as the local CI entry point. *Why:* each replaces a
  hand-rolled pattern (log parsing, ad-hoc checkpoint columns, scripts
  that drift from CI).
- **MVC responsibilities:** controllers translate HTTP ↔ domain (params in,
  envelope out); models own state + invariants; anything orchestrating
  several models is a service object. A fat controller can't be unit-tested
  without HTTP; a fat model turns every feature into a merge conflict.
- **Migrations are reversible and constraint-bearing.** `null: false`,
  `foreign_key: true`, and unique indexes live in the DB — validations alone
  can't stop concurrent duplicates or a console write. One logical change
  per migration.
- **Strong parameters always** (`params.expect(model: [...])` on 8.x, else
  `require(...).permit(...)`). Never mass-assign unfiltered params.

## Layer 2 — Everyday craft

### Models & queries
- Mirror every DB constraint with a model validation. *Why:* the constraint
  guards integrity; the validation produces the human-readable field error.
- **Validate ownership of client-supplied foreign keys.** A permitted
  `*_id` param is an unchecked reference to someone else's row until the
  model (or a scoped lookup) proves it belongs to the caller — a classic
  cross-tenant write hole.
- Index every column you `where`/`order`/join on, in the same migration
  that introduces the query path. Composite `(tenant_id, col)` indexes for
  scoped lists.
- `scope :recent, -> { order(created_at: :desc) }` for reusable fragments;
  `enum` with `prefix: true` to avoid method-name collisions; Rails
  `normalizes :email, with: ->(e) { e.strip.downcase }` for canonical forms.
- **N+1 discipline:** eager-load (`includes`/`preload`) what you iterate;
  wire `bullet` in dev/test or `strict_loading` to make regressions loud.
  Attachments count: a serializer touching `record.file` inside a list
  needs `with_attached_*`/blob includes.
- `find_each` for large batches (bounded memory); `insert_all`/`upsert_all`
  for bulk writes that can skip callbacks knowingly.

### Callbacks (use sparingly)
- Keep a callback only when it **transforms the record itself**
  (normalize a column, set a token/slug). Score it: transformer 5 … external
  operation 1 — extract 1s and 2s.
- Sending mail, HTTP calls, enqueuing jobs, touching other aggregates —
  call those explicitly from the service/controller. *Why:* callback side
  effects fire on *every* persistence path (console, seeds, backfills) and
  are the classic "why did that email send" bug.

### Controllers & API design
- RESTful actions; `before_action` for auth + record loading only. Load
  through the owner: `current_user.tasks.find(params[:id])` → foreign ids
  404 for free.
- **One consistent JSON envelope** for success and error, defined once
  (e.g. `{ status, data, error }` with typed `error.code` and per-field
  validation messages). Status codes match: 201 create, 422 validation,
  404 missing, 401/403 auth — never 200-with-error.
- Serialize explicitly (serializer object/presenter), never raw `to_json`
  on a model. *Why:* the wire contract must survive schema refactors, and
  every accidental new column becomes API surface otherwise.
- Version the API path (`/api/v1/`) from day one; additive changes are free,
  breaking ones get a new version.

### Jobs, mail & webhooks
- Active Job everywhere; jobs are **idempotent** and take ids, not objects
  (the record may change or vanish before the job runs; ids force a fresh,
  authoritative load).
- Mailers send via `deliver_later` — never inline in the request cycle.
- Inbound webhooks: verify the HMAC signature over the **raw body**, store
  an idempotency key (provider event id, unique-indexed), return 2xx fast,
  process in a job. Retries and duplicate deliveries are the norm, not the
  edge case.

### Security
- Scope every query to the current user/tenant — an id from params is a
  claim, not a fact. Parameterized queries only; never interpolate input
  into SQL strings.
- Secrets in credentials/ENV, never code. Fail closed in production when a
  required key is missing (boot error beats silent fallback).
- Rate-limit auth endpoints (`rack-attack`); throttle by real client IP
  (`request.remote_ip` behind trusted proxies, not raw `X-Forwarded-For`).

## Layer 3 — Design (senior/staff judgment)

- **Let the model own its invariant.** The rule "a task's group must belong
  to the task's user" is a model validation, not a controller check — every
  write path (console, jobs, future endpoints) must pass through it.
- **Service objects for cross-aggregate orchestration only** — `.call`
  interface, one responsibility, returning a typed result the controller
  maps to the envelope. If it touches one model, it's a model method; don't
  pre-create `app/services/`.
- **Concerns are shared behavior with a contract** (`Auditable`,
  `AttachmentValidatable`) — named for what they do, tested in isolation.
  A concern that exists to shrink a fat model just hides the fat.
- **Transactions wrap multi-row invariants**; add uniqueness/`RecordNotUnique`
  handling for the concurrent race the validation can't see. Optimistic
  locking (`lock_version`) when concurrent edits of one row are real.
- **The database is the last line of truth:** constraints, not hope. Treat
  "validation exists so the constraint is redundant" as backwards.
- **Multi-tenancy is a query-shape decision** (default scope through the
  tenant, schema-per-tenant, or row-level checks) — pick one mechanism,
  make it impossible to forget (base scopes/lint), and audit any
  client-supplied FK against it.
- **Performance methodology:** measure first (`bullet`, query logs, p95 on a
  realistic dataset). The usual wins, in order: kill N+1s → add the right
  composite index → cap/paginate unbounded lists → cache. Skipping to cache
  hides the first three.

## Testing

- **Request specs are the API contract** — status + envelope + persistence
  side effects; prefer them over controller specs. Model specs cover
  validations/scopes/methods. Include the negative cases: foreign-id 404s,
  cross-tenant rejections, unauthenticated 401s.
- Factories (FactoryBot) over fixtures; `build_stubbed` when the DB isn't
  needed. WebMock/VCR at HTTP boundaries — a spec that really hits a payment
  API is a flake and a bill.
- Coverage gate per project (this user's repos: backend 100% line, enforced
  by SimpleCov — a drop is a missing spec, not a threshold to lower).
- Show the command **and its expected success output**:

  ```bash
  $ bundle exec rspec
  Finished in 12.3s
  1082 examples, 0 failures
  ```

## Running commands in this environment

Non-interactive shells skip `~/.zshrc`, so `mise` shims are absent and
`bin/rails` can hit system Ruby. Prefix Rails/Ruby commands with
`mise exec --` (e.g. `mise exec -- bin/rails db:migrate`).

## Sources

Distilled from the Rails Doctrine and Rails Guides (rubyonrails.org),
`rubocop-rails-omakase` (the 37signals house style), thoughtbot's guides on
callbacks/service extraction, and the "vanilla Rails, rich models, explicit
side effects" school of 37signals/Basecamp — cross-checked against Rails 8
defaults (Solid Queue/Cache/Cable, Propshaft, `params.expect`).

## When in doubt

Do the most conventional Rails thing. The framework's happy path is the
best-documented, best-tested code path in the ecosystem — a future
maintainer already knows it.
