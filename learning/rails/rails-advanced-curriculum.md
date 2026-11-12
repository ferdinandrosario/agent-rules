# Advanced Rails curriculum — `backend/` as the lab

Produced by prompt 2 of [`learning-prompts.md`](../learning-prompts.md).
Four weeks, one topic per session, every exercise adds or refactors
something real in `backend/`. Assumes everyday Rails fluency; covers
only the advanced layer.

## Session protocol

- **One topic per session.** Paste the master context block from
  [`learning-prompts.md`](../learning-prompts.md), then
  `Progress: see docs/learning/rails/ — start the first topic without a notes file.`
- **Progress tracking is file-based.** A topic is done when its notes
  file (table below) exists. `ls docs/learning/rails/` is the progress line.
- **Every exercise ships with specs.** `backend/` enforces 100% line
  coverage (`backend/spec/spec_helper.rb`); an exercise without specs
  fails CI, so the spec is part of the exercise, not an extra.
- **Every exercise ends with docs.** Each session's (d) lists the doc
  files to update — same rule as any other change
  (`personal_manager/docs/CONTRIBUTING.md`).
- **Confirm before editing.** Each session starts by listing the open
  choices in the exercise and waiting for confirmation (master context
  rule 4).

## Schedule

| Week | # | Topic | Notes file (created when done) |
|---|---|---|---|
| 1 | 1 | Solid Queue internals | `rails-01-solid-queue.md` |
| 1 | 2 | Solid Cache | `rails-02-solid-cache.md` |
| 1 | 3 | Solid Cable | `rails-03-solid-cable.md` |
| 2 | 4 | Locking — optimistic & pessimistic | `rails-04-locking.md` |
| 2 | 5 | Counter caches | `rails-05-counter-caches.md` |
| 2 | 6 | Query objects & N+1 elimination | `rails-06-query-objects.md` |
| 3 | 7 | Concurrency & connection pools | `rails-07-connection-pools.md` |
| 3 | 8 | Rack internals & middleware | `rails-08-rack.md` |
| 3 | 9 | Rate limiting | `rails-09-rate-limiting.md` |
| 4 | 10 | Multi-tenancy patterns | `rails-10-multi-tenancy.md` |
| 4 | 11 | API versioning | `rails-11-api-versioning.md` |
| 4 | 12 | Background-job idempotency | `rails-12-job-idempotency.md` |
| 4 | 13 | Ruby 4 features | `rails-13-ruby-4.md` |

Week 4 carries four sessions — it is the heaviest week. If a week
slips, keep the order; the sequence is deliberate (week 1 makes
development mirror production, which every later session relies on).

---

## Week 1 — the Solid trifecta

The thread of week 1: development runs `memory_store` cache, the
`async` Action Cable adapter, and the default Active Job test/async
adapter, while production runs Solid Cache / Solid Cable / Solid Queue
against dedicated Postgres databases
(`backend/config/environments/production.rb`,
`backend/config/database.yml`). By the end of week 1, development runs
the same engine as production, which is what makes the rest of the
curriculum observable locally.

### 1. Solid Queue internals

**(a)** Solid Queue is a Postgres-backed job backend: enqueueing writes
a row to `solid_queue_jobs` plus an execution row
(`solid_queue_ready_executions` for run-now,
`solid_queue_scheduled_executions` for run-later). A supervisor process
forks workers and a dispatcher: workers poll ready executions with
`SELECT … FOR UPDATE SKIP LOCKED` (lock-free claiming — no two workers
grab the same job), and the dispatcher moves due scheduled executions
to ready in batches (`batch_size` in `backend/config/queue.yml`) and
materializes `backend/config/recurring.yml` entries into
`solid_queue_recurring_executions`, whose unique index is what prevents
a recurring run from firing twice. In this repo the adapter is wired in
production only (`config.active_job.queue_adapter = :solid_queue`
writing to the `queue` database), with one worker process polling all
queues with 3 threads — every job, including every minute-level
reminder job, shares one queue named `default`.

**(b) Exercise — run Solid Queue in development and split the queues:**

1. Mirror the production wiring in development: add a `queue`
   sub-database to the `development:` block of
   `backend/config/database.yml` (database
   `personal_manager_development_queue`, `schema_dump: queue_schema.rb`,
   `migrations_paths: db/queue_migrate`), and add the adapter +
   `connects_to` lines from `production.rb` to
   `backend/config/environments/development.rb`.
2. Introduce `ReminderJob < ApplicationJob` with `queue_as :reminders`,
   make the `Deliver*RemindersJob` classes inherit from it, and set
   `queue: reminders` on their `backend/config/recurring.yml` entries.
3. Give the topology meaning in `backend/config/queue.yml`: one worker
   for `["default"]`, one for `["reminders"]` — reminder fan-out can no
   longer starve interactive jobs like `NotificationFanoutJob`.
4. Watch the lifecycle: enqueue with `set(wait: 30.seconds)`, query the
   `solid_queue_scheduled_executions` row, watch the dispatcher promote
   it.

**(c) Verify:**

```sh
bin/rails db:prepare
# Created database 'personal_manager_development_queue'

bin/jobs   # terminal 2 — leave running

bin/rails runner 'puts SolidQueue::Process.pluck(:kind).tally'
# {"Supervisor(fork)" => 1, "Dispatcher" => 1, "Worker" => 2}

bin/rails runner 'DeliverDueRemindersJob.perform_later; sleep 2;
  j = SolidQueue::Job.order(:id).last
  puts "#{j.class_name} queue=#{j.queue_name} finished=#{j.finished_at.present?}"'
# DeliverDueRemindersJob queue=reminders finished=true
```

**(d) Docs:** [`rails-01-solid-queue.md`](rails-01-solid-queue.md) (notes) ·
`docs/getting-started/running-locally.md` (the `bin/jobs` terminal) ·
`docs/operations/tuning.md` (queue topology: which jobs run where, and why).

### 2. Solid Cache

**(a)** Solid Cache stores cache entries as rows in
`solid_cache_entries`, trading RAM for disk: the cache can be far
larger than memory, survives restarts and deploys, and needs no Redis.
Eviction is background and probabilistic — writes occasionally sample
batches of entries and delete by `max_age`/`max_size`
(`backend/config/cache.yml`, capped at 256 MB here), so the cache is
LRU-ish, not strictly LRU, and reads stay cheap. Production already
uses it (`config.cache_store = :solid_cache_store` writing to the
`cache` database); development runs `:memory_store`, which means cache
behavior — including the Rack::Attack counters that live in
`Rails.cache` — differs between the two.

**(b) Exercise — real caching on the dashboard:**

1. Mirror production: add a `cache` sub-database to `development:` in
   `backend/config/database.yml` and switch
   `development.rb` to `config.cache_store = :solid_cache_store`.
2. `Api::V1::DashboardController#summary` recomputes grouped counts
   over plans/tasks on every request. Wrap the aggregation in
   `Rails.cache.fetch("dashboard/summary/#{current_user.id}/#{Date.current}", expires_in: 5.minutes)`.
3. Decide and document the invalidation story: time-based (the
   `expires_in`) vs event-based (`Rails.cache.delete` from the task
   write path) — implement the one you pick, write down why.
4. Inspect eviction: fill the cache past a small `max_size` in console
   and watch `SolidCache::Entry.count` fall after subsequent writes.

**(c) Verify:**

```sh
bin/rails db:prepare
# Created database 'personal_manager_development_cache'

bin/rails runner 'Rails.cache.write("probe", 1)
  puts Rails.cache.read("probe").inspect, SolidCache::Entry.count'
# 1
# 1            (count is ≥ 1 — other entries may exist)

# hit the summary endpoint twice; the second hit must be visibly cheaper:
grep 'dashboard' log/development.log | tail -2
# first request:  Completed 200 OK in ~50ms (ActiveRecord: >10ms …)
# second request: Completed 200 OK with ActiveRecord time near zero
```

**(d) Docs:** `docs/learning/rails/rails-02-solid-cache.md` ·
`docs/feature/task-planner.md` (the summary endpoint's caching +
invalidation rule) · `docs/operations/tuning.md` (`max_size` formula).

### 3. Solid Cable

**(a)** Solid Cable replaces the Redis pub/sub layer of Action Cable
with a Postgres table: `broadcast` inserts a row into
`solid_cable_messages`, every Puma process polls that table for new
rows on its subscribed channels (`polling_interval: 0.1.seconds` in
production), and old rows are trimmed after `message_retention: 1.day`
— which also makes recent broadcasts inspectable after the fact, a
debugging trick Redis pub/sub can't offer. The development `async`
adapter only delivers within a single process, and session 1 just moved
jobs *out* of the Puma process: any reminder or fan-out job that
broadcasts from `bin/jobs` silently reaches nobody in development.
That cross-process delivery gap is the whole reason this session
exists.

**(b) Exercise — cross-process broadcasts in development:**

1. Demonstrate the bug first: with `development: adapter: async` in
   `backend/config/cable.yml`, broadcast from a job in `bin/jobs` while
   a web client is subscribed — nothing arrives. Capture this in the
   notes; it is the best argument for adapter parity you will ever own.
2. Mirror production: add the `cable` sub-database to `development:` in
   `backend/config/database.yml`, switch `development:` in `cable.yml`
   to `solid_cable` with a short `polling_interval`.
3. Re-run the broadcast from step 1 and watch it arrive.
4. Study retention: find where trimming happens in the solid_cable gem
   source (`bundle open solid_cable`), and note the
   `polling_interval` latency/load trade-off in `docs/operations/tuning.md`.

**(c) Verify:**

```sh
bin/rails db:prepare
# Created database 'personal_manager_development_cable'

bin/rails runner 'ActionCable.server.broadcast("probe", { ping: 1 })
  puts SolidCable::Message.count'
# 1            (≥ 1 — the broadcast became a row)

# end-to-end: web app open on the messages screen, then from console
# send a message as the other participant — it renders without reload.
```

**(d) Docs:** `docs/learning/rails/rails-03-solid-cable.md` ·
`docs/feature/friends.md` (how message broadcasts travel in
development vs production) · `docs/operations/tuning.md` (`polling_interval`,
`message_retention`).

---

## Week 2 — advanced ActiveRecord

### 4. Locking — optimistic & pessimistic

**(a)** Two failure modes, two locks. *Lost update*: web and mobile
both load the same task, both save, the second write silently erases
the first — optimistic locking fixes this with a `lock_version` column
that every `UPDATE` checks-and-increments; a stale writer raises
`ActiveRecord::StaleObjectError` and the API turns that into `409
Conflict` so the client can reload and retry. *Race on a state
transition*: two requests both see `pending` and both perform the
transition — pessimistic locking (`record.with_lock`, i.e.
`SELECT … FOR UPDATE` inside a transaction) serializes them so the
second blocks, re-reads, and sees the first's result. Optimistic costs
nothing until a conflict and suits user-edited columns; pessimistic
holds a row lock for the transaction and suits short, critical
transitions. Neither exists in this schema yet (no `lock_version`
column anywhere in `backend/db/schema.rb`).

**(b) Exercise — conflict-safe task edits:**

1. Migration: `add_column :tasks, :lock_version, :integer, default: 0,
   null: false`.
2. In `Api::V1::TasksController`, permit `lock_version`, and rescue
   `ActiveRecord::StaleObjectError` into the repo's error envelope with
   status `409`. Enforcement only triggers when the client sends
   `lock_version`, so existing web/mobile clients keep working
   unchanged — note that contract decision in the feature doc.
3. Pessimistic side: pick one state transition in the codebase (e.g.
   friendship accept), wrap it in `with_lock`, and write a spec
   proving a double-submit performs the transition once.

**(c) Verify:**

```sh
bin/rails runner 't = Task.first
  a = Task.find(t.id); b = Task.find(t.id)
  a.update!(title: "first writer")
  begin b.update!(title: "second writer")
  rescue ActiveRecord::StaleObjectError => e puts "raised #{e.class}" end'
# raised ActiveRecord::StaleObjectError

bundle exec rspec spec/requests/api/v1/tasks_spec.rb
# expected: all green, including the new 409 example
```

**(d) Docs:** `docs/learning/rails/rails-04-locking.md` ·
`docs/feature/task-planner.md` (the `lock_version` request param + 409
response row in the endpoint table).

### 5. Counter caches

**(a)** `belongs_to :conversation, counter_cache: true` keeps a
`messages_count` column on the parent in sync via
`update_counters` — a single atomic
`UPDATE conversations SET messages_count = messages_count + 1` with no
read-modify-write window, so it is race-safe without locks (compare
session 4: this is the degenerate case where the database's own
atomicity is the lock). The win is on list screens: a conversations
index showing message counts otherwise needs a `COUNT` per row or a
`GROUP BY` join. The costs: every child create/destroy writes the
parent row (lock contention on hot parents), and the counter can drift
if rows are created around the callbacks (`insert_all`, raw SQL) —
`Conversation.reset_counters(id, :messages)` is the repair tool, and a
backfill migration must seed the column for existing rows.

**(b) Exercise — `messages_count` on conversations:**

1. Migration: `add_column :conversations, :messages_count, :integer,
   default: 0, null: false`, plus a backfill that calls
   `reset_counters` for each existing conversation (batched with
   `in_batches`).
2. `counter_cache: true` on `Message#belongs_to :conversation`.
3. Use it: expose `messages_count` in the conversations index response
   and remove any per-conversation count the serializer or client
   derives today.
4. Break it on purpose: `Message.insert_all` one row in console, show
   the drift, repair with `reset_counters` — capture both in the notes.

**(c) Verify:**

```sh
bin/rails db:migrate
# expected: both migrations run, schema.rb gains messages_count

bin/rails runner 'puts Conversation.all.all? { |c|
  c.messages_count == c.messages.count }'
# true

bundle exec rspec spec/models/message_spec.rb spec/requests/api/v1/conversations_spec.rb
# expected: green, including the new counter examples
```

**(d) Docs:** `docs/learning/rails/rails-05-counter-caches.md` ·
`docs/feature/friends.md` (data-model section gains the column; drift +
repair documented).

### 6. Query objects & N+1 elimination

**(a)** A query object is a PORO under `app/queries/` whose `#call`
returns an `ActiveRecord::Relation` — it gives a multi-clause query a
name, a spec file, and composability (callers can chain further
scopes), and it pulls aggregation logic out of controllers, which in
this repo is `Api::V1::DashboardController` building bucketed
status counts inline. N+1 elimination has three tools with distinct
semantics: `preload` (separate `WHERE id IN` query per association),
`eager_load` (one `LEFT OUTER JOIN`, required when the `WHERE`/`ORDER`
references the association), and `includes` (picks between them —
convenient, but it hides which SQL shape you get). The enforcement
tools are already installed here: Bullet logs N+1s in development
(`log/bullet.log`), and `strict_loading` makes any lazy association
load raise instead of silently querying.

**(b) Exercise — extract the dashboard query, then hunt:**

1. Extract the summary aggregation from `DashboardController` into
   `app/queries/dashboard_summary_query.rb` with its own spec; the
   controller keeps only param parsing and rendering. (This object is
   reused in sessions 2 and 7.)
2. Turn on `config.active_record.strict_loading_by_default = true` in
   `development.rb`, click through the web app, and fix every raise
   with the *narrowest* tool (`preload` vs `eager_load` — justify each
   choice in the notes).
3. Empty `log/bullet.log`, replay the same flows, confirm it stays
   empty.

**(c) Verify:**

```sh
bundle exec rspec spec/queries/dashboard_summary_query_spec.rb
# expected: green

: > log/bullet.log
# … exercise the app (dashboard, conversations, tasks) …
wc -l < log/bullet.log
# 0
```

**(d) Docs:** `docs/learning/rails/rails-06-query-objects.md` ·
`docs/development/conventions.md` (new convention: `app/queries/`, naming,
must-return-Relation rule).

---

## Week 3 — runtime & the Rack

### 7. Concurrency & connection pools

**(a)** Every layer multiplies: Puma runs `RAILS_MAX_THREADS` (3)
threads per process (`backend/config/puma.rb`), each request thread
needs a database connection while it touches ActiveRecord, and the pool
(`database.yml`) caps how many connections a process may open — a pool
smaller than the thread count means threads queue on checkout and raise
`ActiveRecord::ConnectionTimeoutError` after `checkout_timeout`
(default 5s) under load. The Solid Queue worker from session 1 is a
*separate process* with its own pool sized by its own thread count, and
`load_async` adds another consumer: it runs the query on a background
executor with its own connections, letting independent queries (like
the dashboard's per-bucket counts) overlap — useful precisely because
Ruby's GVL parallelizes I/O waits (database round-trips) even though it
serializes Ruby execution. The pool formula belongs in
`docs/operations/tuning.md`, not in anyone's head.

**(b) Exercise — see saturation, then overlap the dashboard:**

1. Write the pool math for this app into `docs/operations/tuning.md`: Puma
   threads + Solid Queue threads per process + async executor, with
   the actual numbers from `puma.rb`, `queue.yml`, and `database.yml`.
2. Saturate deliberately: in console, spawn more threads than the pool
   doing `ActiveRecord::Base.connection_pool.with_connection { sleep 6 }`
   and watch `ConnectionTimeoutError` fire; capture `pool.stat` during.
3. Apply `load_async` to the independent aggregates in
   `DashboardSummaryQuery` (session 6's object) and confirm the
   queries overlap in the log.

**(c) Verify:**

```sh
bin/rails runner 'puts ActiveRecord::Base.connection_pool.stat'
# {size: 3, connections: 1, busy: 1, dead: 0, idle: 0, waiting: 0, checkout_timeout: 5.0}
#  ^ size must be ≥ RAILS_MAX_THREADS — that inequality is the lesson

grep 'ASYNC' log/development.log | tail -1
# ASYNC Plan Count (0.8ms) (db time 2.1ms)   ← async executor ran it
```

**(d) Docs:** `docs/learning/rails/rails-07-connection-pools.md` ·
`docs/operations/tuning.md` (the formula with real numbers) ·
`docs/troubleshooting/README.md` (`ConnectionTimeoutError` symptom → pool
math fix).

### 8. Rack internals & middleware

**(a)** Rack is the contract that makes Rails, Puma, and every
middleware interchangeable parts: an app is anything responding to
`call(env)` returning `[status, headers, body]`, and middleware is an
app that wraps another, forming an onion the request descends and the
response ascends. Order is behavior, and this repo already depends on
it: `Rack::Attack` rejects floods before the request spends router or
database time, `rack-cors` must answer preflights before auth would
reject them, and Devise/Warden sits in the stack as middleware too —
`bin/rails middleware` prints the actual onion, much shorter here than
a full-stack app because `config.api_only` strips cookies, sessions,
and flash. Writing one middleware makes the `env` hash, the
`@app.call` convention, and header mutation concrete in a way reading
never does.

**(b) Exercise — a query-count header:**

1. Read the stack: `bin/rails middleware`, identify why `Rack::Attack`
   and `Rack::Cors` sit where they sit; record the order rationale in
   `docs/architecture/overview.md`.
2. Write `QueryCounter` middleware (`backend/lib/middleware/`):
   subscribe to `sql.active_record` via
   `ActiveSupport::Notifications.subscribed` for the duration of
   `@app.call`, count queries, add `X-Query-Count` to the response.
   Insert it in development only (`config.middleware.insert_after
   ActionDispatch::Executor, …`), with a spec driving it via
   `Rack::MockRequest`.
3. Wire it to week 2: the header is now a per-request N+1 smoke alarm
   — note the dashboard's count before/after session 6's work.

**(c) Verify:**

```sh
bin/rails middleware | grep -n 'Rack::Attack\|QueryCounter'
# 4: use Rack::Attack          (position varies — before the router)
# 9: use QueryCounter

curl -is localhost:3000/api/v1/dashboard/summary \
  -H "Authorization: Bearer $TOKEN" | grep -i x-query-count
# X-Query-Count: 7        (exact number = your dashboard's query count)
```

**(d) Docs:** `docs/learning/rails/rails-08-rack.md` ·
`docs/architecture/overview.md` (middleware order + why).

### 9. Rate limiting

**(a)** This repo already runs a serious Rack::Attack setup
(`backend/config/initializers/rack_attack.rb`): per-IP throttles on the
auth endpoints and a JWT-aware key (`api:user:<id>` falling back to
`api:ip:<addr>`) so authenticated users are limited per-account, not
per-NAT — read it before writing anything. The advanced layer: counters
live in `Rails.cache` (`Rack::Attack.cache.store = Rails.cache`), which
week 1 moved to Solid Cache, making counters shared across processes
and durable across restarts — memory-store counters reset on deploy
and diverge per process. Rails 8 also ships a native controller-level
`rate_limit` DSL backed by the same cache; it lives *inside* the
controller (after routing, after auth, with `current_user` available)
whereas Rack::Attack runs before the router — cheaper rejection, but
cruder keys. A polite limiter answers `429` with `Retry-After` so
well-behaved clients can back off correctly.

**(b) Exercise — write-throttle messages, compare both layers:**

1. Add a Rack::Attack throttle for message creation (e.g. 30/min keyed
   by `api_throttle_key`), and extend the throttled responder to set
   `Retry-After` and the repo's JSON error envelope if it doesn't
   already.
2. Implement the same limit as Rails-native
   `rate_limit to: 30, within: 1.minute, by: -> { current_user.id }`
   on `Api::V1::MessagesController#create`; compare where each
   rejects in the stack (session 8 gave you the map), then keep
   exactly one and delete the other — record the reasoning.
3. Spec it: request spec driving 31 creates, asserting the 31st is
   `429` with `Retry-After`.

**(c) Verify:**

```sh
for i in $(seq 1 31); do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST \
    localhost:3000/api/v1/conversations/1/messages \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"message":{"body":"probe"}}'
done | sort | uniq -c
#   30 201
#    1 429

bundle exec rspec spec/requests/api/v1/messages_spec.rb
# expected: green, including the throttle example
```

**(d) Docs:** `docs/learning/rails/rails-09-rate-limiting.md` ·
`docs/security/threat-model.md` (the rate-limit table gains the new throttle).

---

## Week 4 — architecture

### 10. Multi-tenancy patterns

**(a)** This app is already tenant-isolated in the simplest way: every
query hangs off `current_user`'s associations, so the user *is* the
tenant and isolation is enforced by discipline — nothing stops a future
controller from writing `Task.find(params[:id])` and leaking across
users. The pattern ladder, in increasing isolation and cost:
**row-scoping** (a `Current` attributes tenant set per-request, with
every query forced through tenant-scoped finders — discipline made
structural), **Postgres row-level security** (the database itself
filters rows by a session variable, surviving even raw-SQL mistakes),
**schema-per-tenant**, and **database-per-tenant** via Rails horizontal
sharding (`connects_to shards:`) — the last two trade operational
complexity for hard isolation and per-tenant migrations, and only pay
off for B2B SaaS. The realistic trajectory for *this* app is
household tenancy: `family_members` suggests data shared by a household
rather than owned by one user, which is exactly when implicit
user-scoping stops being enough.

**(b) Exercise — make the implicit tenant explicit:**

1. Add `Current < ActiveSupport::CurrentAttributes` with a `user`
   attribute, set it in the auth layer of `ApplicationController`,
   reset automatically per request (CurrentAttributes does this).
2. Refactor one controller's scoping to read from `Current.user`
   inside a query object instead of threading `current_user` through —
   observe what improves (call signatures) and what worsens (hidden
   dependency); both go in the notes.
3. Write the leak-test spec: for two users A and B, every show/update/
   destroy on A's resources with B's token returns `404` — table-drive
   it over the controllers you touch.
4. RLS lab (console + `psql` only, no committed migration): enable
   row-level security on `audit_logs` in a scratch transaction, set the
   tenant via `SET app.user_id`, observe filtering, roll back. Notes
   capture the commands and where RLS would slot in if households land.

**(c) Verify:**

```sh
bundle exec rspec spec/requests/api/v1 -e "cross-tenant"
# expected: green — every cross-tenant example returns 404

bin/rails runner 'Current.user = User.first
  puts Current.user.email; Current.reset; puts Current.user.inspect'
# user-one@example.com
# nil
```

**(d) Docs:** `docs/learning/rails/rails-10-multi-tenancy.md` ·
`docs/architecture/overview.md` (tenancy model: what enforces isolation
today, the household upgrade path).

### 11. API versioning

**(a)** The repo's path versioning (`/api/v1/…`, controllers under
`Api::V1`) is the boring, right default — but a version is a
*contract*, and the discipline is what counts: within v1, changes are
additive only (new keys, new endpoints — never renamed keys, never
changed types); a breaking change means a parallel `v2` namespace
serving both versions while clients migrate. The mechanics worth
owning: route namespaces with shared concerns, `Api::V2` controllers
inheriting from v1 where behavior is unchanged and overriding only the
delta (inheritance beats copy-paste until the versions diverge, then
copy — know both failure modes), and sunsetting with the
`Deprecation`/`Sunset` response headers (RFC 8594) so clients learn the
deadline from the API itself. Versioning by `Accept` header keeps URLs
stable but is harder to demo with curl, harder to cache, and rarer in
API-only Rails — know it exists, choose paths deliberately.

**(b) Exercise — a real v2 of one resource:**

1. Pick the tasks index. Cut `Api::V2::TasksController` whose breaking
   change is a pagination envelope:
   `{ "data": […], "meta": { "page": 1, "pages": 4, "count": 87 } }`
   versus v1's bare array. Share auth/scoping via inheritance from a
   new `Api::V2::BaseController`.
2. Route it under `namespace :v2`, full request specs for both
   versions (v1 specs must pass untouched — that *is* the contract).
3. Add `Deprecation: false` semantics the lab way: set `Sunset` +
   `Deprecation` headers on the v1 tasks endpoint *behind a comment
   explaining no real sunset is scheduled* — the point is owning the
   mechanics, and web/mobile stay on v1.

**(c) Verify:**

```sh
curl -s localhost:3000/api/v1/tasks -H "Authorization: Bearer $TOKEN" | head -c 40
# [{"id":1,"title":"…
curl -s localhost:3000/api/v2/tasks -H "Authorization: Bearer $TOKEN" | head -c 40
# {"data":[{"id":1,"title":"…

bin/rails routes -g tasks | grep -c 'api/v2'
# expected: ≥ 1
```

**(d) Docs:** `docs/learning/rails/rails-11-api-versioning.md` ·
`docs/development/conventions.md` (versioning policy: what counts as breaking,
when to cut vN+1) · `docs/feature/task-planner.md` (v2 endpoint rows).

### 12. Background-job idempotency

**(a)** Solid Queue, like every serious queue, is *at-least-once*: a
worker can crash after the side-effect but before marking the job
finished, `retry_on` re-runs jobs deliberately, and a deploy can kill
an in-flight execution — so "this job may run twice with the same
arguments" is a design input, not an edge case. `NotificationFanoutJob`
is this repo's live example: `perform` calls `create!`, so a retry
after a crash-between-insert-and-ack writes a duplicate notification
row (the schema has no uniqueness to stop it). The standard fixes, in
order of preference: make the operation *naturally idempotent* (an
upsert keyed on real-world identity), or thread an *idempotency key*
through the job and enforce it with a unique index plus an
insert-or-ignore write. Two adjacent tools round out the topic: Solid
Queue's `limits_concurrency` (semaphore rows that serialize jobs
sharing a key — concurrency control, often confused with idempotency),
and `enqueue_after_transaction_commit`, which stops a job from racing
ahead of — or surviving the rollback of — the transaction that spawned
it.

**(b) Exercise — make the fan-out replay-safe:**

1. Migration: `event_id` string column on `notifications` + unique
   index. `Notifications::Dispatch` generates it
   (`SecureRandom.uuid`) at enqueue time and passes it to
   `NotificationFanoutJob`, so retries reuse the same key.
2. In the job, replace `create!` with `insert` using
   `unique_by: :index_notifications_on_event_id` (or
   `create_or_find_by!`) — a duplicate run becomes a no-op, not an
   exception.
3. Uncomment and own the `ApplicationJob` hints:
   `retry_on ActiveRecord::Deadlocked` and
   `discard_on ActiveJob::DeserializationError` — write one spec per
   policy, and document why deserialization failures discard (the
   record is gone; retrying cannot fix it).
4. Add `limits_concurrency key: ->(recipient_id, *) { recipient_id }`
   to the fan-out job and observe the semaphore rows under parallel
   enqueues — note in the docs why this is ordering, not idempotency.

**(c) Verify:**

```sh
bin/rails runner 'u, a = User.first, User.last
  2.times { NotificationFanoutJob.perform_now(u.id, "friend_request", a.id, {}, "evt-probe-1") }
  puts Notification.where(event_id: "evt-probe-1").count'
# 1

bundle exec rspec spec/jobs/notification_fanout_job_spec.rb
# expected: green, including the replay example
```

**(d) Docs:** `docs/learning/rails/rails-12-job-idempotency.md` ·
`docs/feature/friends.md` (notification fan-out: idempotency key
documented in the jobs section, per the feature-doc checklist).

### 13. Ruby 4 features

**(a)** The backend pins Ruby 4.0.9 (`backend/.ruby-version`), and this
session applies AGENTS.md rule 12 to the language itself: the
authoritative inventory is the NEWS file for your exact installed
version, not blog posts — start from
`https://docs.ruby-lang.org/en/4.0/NEWS_md.html` and confirm each
feature in your own `irb` before using it. The headline areas to
evaluate against this codebase: **ZJIT** (the method-based JIT
developed alongside YJIT — measure, never assume, on an I/O-bound API),
**Ractor maturity** (true parallelism for CPU-bound work behind
message-passing isolation — almost everything this API does is
I/O-bound, so the honest finding may be "not applicable here", which
is itself the lesson), **namespaces** (experimental program isolation —
understand, don't adopt; experimental features fail the repo's
stability rule), and the modern-Ruby idioms that are now table stakes:
the `it` implicit block parameter, `Data.define` for immutable value
objects, and pattern matching in service-layer control flow.

**(b) Exercise — verify, measure, adopt selectively:**

1. Inventory: read the NEWS for the pinned version; list in the notes
   each feature with *confirmed in irb? / useful here? / stability*.
2. Measure ZJIT honestly: drive the dashboard endpoint with a fixed
   request count, Puma with and without the JIT flag (check
   `bin/rails runner 'puts RubyVM.respond_to?(:zjit_enabled?)'` and the
   NEWS for the exact flag), record requests/sec for both in
   `docs/operations/tuning.md` — including a null result.
3. Adopt idioms where they reduce noise: `it` in the single-arg blocks
   of `DashboardSummaryQuery` (session 6), and one `Data.define` value
   object where the dashboard buckets pass primitive hashes today.
   Specs unchanged-and-green proves behavior parity.

**(c) Verify:**

```sh
ruby --version
# ruby 4.0.9 (…) +PRISM [arm64-darwin25]   ← exact tags per your build

bin/rails runner 'puts [1, 2, 3].map { it * 2 }.sum'
# 12

bundle exec rspec spec/queries
# expected: green — idiom refactor changed no behavior
```

**(d) Docs:** `docs/learning/rails/rails-13-ruby-4.md` (the feature
inventory table is the artifact) · `docs/operations/tuning.md` (JIT
measurement, even if null) · `docs/development/conventions.md` (which new
idioms are house style).

---

## After week 4

The capstone is already scheduled: prompt 5 of
[`learning-prompts.md`](../learning-prompts.md) (scaling drills) and
prompt 1's architecture-review findings both build directly on
sessions 1–13. Re-run the prompt-1 review after finishing — comparing
it against `docs/archive/architecture-review-2026-06.md` measures what the
month changed.
