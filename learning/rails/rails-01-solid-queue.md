# Session 1 — Solid Queue internals

Notes for topic 1 of
[`rails-advanced-curriculum.md`](rails-advanced-curriculum.md). This
file existing marks the topic done.

## What Solid Queue actually is

- `perform_later` writes a `solid_queue_jobs` row plus an execution
  row: `solid_queue_ready_executions` for run-now,
  `solid_queue_scheduled_executions` for run-later.
- `bin/jobs` boots a **supervisor**, which forks the actors and
  registers every process in `solid_queue_processes` (heartbeated —
  this table is the live fleet inventory):
  - **Workers** poll ready executions with
    `SELECT … FOR UPDATE SKIP LOCKED` — each worker claims rows no
    other worker can see mid-claim, so no Redis, no advisory locks,
    no double-execution.
  - The **dispatcher** promotes due scheduled executions to ready in
    batches (`batch_size: 500` in `config/queue.yml`) and materializes
    `config/recurring.yml` into `solid_queue_recurring_executions`,
    whose unique index on `(task_key, run_at)` is what makes a
    recurring tick fire exactly once even with multiple dispatchers.
- A finished job gets `finished_at` stamped and its execution row
  deleted; `SolidQueue::Job.clear_finished_in_batches` (first entry in
  `recurring.yml`) is the retention sweep.

## What changed in this repo

| File | Change |
|---|---|
| `backend/config/database.yml` | `development:` became multi-db: `primary` + `queue` (`personal_manager_development_queue`), mirroring production. |
| `backend/config/environments/development.rb` | `queue_adapter = :solid_queue` + `connects_to` — dev runs the production job engine. |
| `backend/app/jobs/reminder_job.rb` | New base class, `queue_as :reminders`; home for future shared reminder policy. |
| `backend/app/jobs/deliver_*_reminders_job.rb` | All ten sweeps now inherit `ReminderJob` (dropped their per-class `queue_as :default`). |
| `backend/config/recurring.yml` | The ten `deliver_*` entries moved to `queue: reminders`. |
| `backend/config/queue.yml` | Two workers: `default` (3 threads, 0.1 s poll, scales via `JOB_CONCURRENCY`) and `reminders` (1×1, 1 s poll). |
| `backend/spec/jobs/reminder_job_spec.rb` | Routing specs + a drift guard: every `recurring.yml` entry's `queue:` must match its job class's queue. |

## Decisions and why

- **Separate dev queue database** (not reusing the primary): identical
  shape to production, exercises the `connects_to` wiring, and keeps
  `db/queue_schema.rb` honest. Cost: one extra `db:prepare` artifact.
- **`ReminderJob` base class** (not ten `queue_as :reminders` lines):
  one place for shared retry/instrumentation policy later — session 12
  (idempotency) hangs `retry_on`/`discard_on` decisions here.
- **`recurring.yml` keeps explicit `queue:` keys** (file-local
  consistency with the non-reminder entries) — and because Solid Queue
  enqueues recurring jobs onto the *entry's* queue, overriding
  `queue_as`, the spec-level drift guard is load-bearing, not paranoia.
- **Recurring schedule stays production-only.** A dev schedule would
  fire reminder sweeps every minute against seed data. In dev,
  scheduled jobs are fired by hand
  (`bin/rails runner '<Job>.perform_now'`).

## Observed lifecycle (real outputs)

Fleet registration after `bin/jobs`:

```sh
bin/rails runner 'puts SolidQueue::Process.pluck(:kind).tally'
# {"Supervisor(fork)" => 1, "Dispatcher" => 1, "Worker" => 2}
```

Queue routing + execution end-to-end:

```sh
bin/rails runner 'DeliverDueRemindersJob.perform_later; sleep 3
j = SolidQueue::Job.order(:id).last
puts "#{j.class_name} queue=#{j.queue_name} finished=#{j.finished_at.present?}"'
# DeliverDueRemindersJob queue=reminders finished=true
```

Dispatcher promoting a scheduled execution (enqueue with
`set(wait: 5.seconds)`, then watch the scheduled row drain):

```sh
bin/rails runner 'j = DeliverDueRemindersJob.set(wait: 5.seconds).perform_later
puts "scheduled rows: #{SolidQueue::ScheduledExecution.count}"
sleep 8
row = SolidQueue::Job.find_by(active_job_id: j.job_id)
puts "after dispatch: scheduled=#{SolidQueue::ScheduledExecution.count} finished=#{row.finished_at.present?}"'
# scheduled rows: 1
# after dispatch: scheduled=0 finished=true
```

## Gotchas learned

- **The docs were ahead of the code.** `docs/feature/friends.md` and
  two `10-troubleshooting.md` entries already instructed `bin/jobs` in
  dev — but with no dev queue database and the `:async` adapter, that
  command crashed on missing tables. The wiring now matches the docs.
- **Behavior change in dev:** under `:async`, jobs ran inside Puma
  automatically; under Solid Queue nothing runs until `bin/jobs` is up
  (jobs wait, they are not lost). Notification fan-out and
  friend-request email in dev now require terminal 3.
- **The supervisor renames its process title** to
  `solid-queue-fork-supervisor(…)`, so `pkill -f bin/jobs` matches
  nothing — and the orphaned supervisor keeps running. Ctrl-C, or
  `pkill -TERM -f solid-queue`, then confirm
  `SolidQueue::Process.count` → `0`.
- **`recurring.yml` `queue:` beats `queue_as`.** Splitting queues by
  editing only the job classes would have silently changed nothing for
  recurring runs — hence the drift-guard spec.

## Verification (full transcript signals)

```sh
bin/rails db:prepare
# Created database 'personal_manager_development_queue'

bundle exec rspec
# 905 examples, 0 failures
# Line Coverage: 100.0% (2515 / 2515)

bin/rubocop app/jobs spec/jobs/reminder_job_spec.rb
# 19 files inspected, no offenses detected
```

Doc updates shipped with this session: `docs/getting-started/running-locally.md`
(terminal 3 + stop instructions), `docs/backend/setup.md`
(multi-db dev config), `docs/operations/tuning.md` (topology table + process
memory math), `docs/deployment/README.md` (`JOB_CONCURRENCY` semantics),
`docs/troubleshooting/README.md` (three new entries + presence-sweep fix),
`docs/feature/friends.md` (four terminals, sweep-by-hand),
root `AGENTS.md` (four terminals).

## Next session

Topic 2 — Solid Cache (`rails-advanced-curriculum.md` week 1). Dev
still runs `:memory_store`; the Rack::Attack counters live there too,
which is part of session 2's material.
