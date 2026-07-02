---
name: ruby
description: Use for idiomatic Ruby best practices — naming, blocks/enumerables, error handling, value objects, and gem/test conventions — independent of Rails. Triggers on "how do I do X idiomatically in Ruby", code review of plain Ruby, or design questions about Ruby classes, modules, and methods.
---

# Ruby — idiomatic best practices

Language- and style-level guidance that applies to **any** Ruby code
(plain scripts, gems, service objects). For Rails-specific conventions
see the [`rails`](../rails/SKILL.md) skill. When working inside a project,
its `backend/AGENTS.md` is the source of truth and **overrides** anything
here on conflict.

Version context (verify against the project): Ruby **4.0.x** upstream as of
2026-05; Ubuntu 26.04 apt ships Ruby 3.3.x. Don't reach for syntax newer
than the project's pinned version — check `.ruby-version` / `Gemfile` first.

**How to read this:** three layers. Foundations are non-negotiable for any
reader; Everyday craft is the working vocabulary; Design is the judgment
layer for structuring larger code. Every rule carries its why — apply the
why, not just the letter.

## Layer 1 — Foundations

- **Names:** `snake_case` methods/variables, `CamelCase` classes/modules,
  `SCREAMING_SNAKE_CASE` constants. Predicates end in `?` (`empty?`),
  dangerous/mutating variants in `!` (`save!` raises where `save` returns
  false). *Why:* the suffixes are a contract — readers decide error handling
  from the name alone.
- **Two-space indent, no tabs; short methods.** A method needing a comment to
  explain *what* it does wants to be split; comments explain *why* only.
- **Guard clauses over nesting:** `return unless order.payable?` at the top
  beats wrapping the body in `if`. *Why:* the happy path reads top-to-bottom
  at one indent level.
- **Enumerable over manual loops:** `map`, `select`/`reject`, `sum`,
  `group_by`, `tally`, `filter_map`, `each_with_object`. *Why:* each names
  its intent; a `for`/`while` accumulator makes the reader reverse-engineer it.

  ```ruby
  totals = orders.group_by(&:status).transform_values { |os| os.sum(&:amount) }
  ```
- **String interpolation over concatenation** (`"Hi #{name}"`), and no
  `puts`-debugging left behind — use a logger with levels.
- **Run the project's linter** (RuboCop / Standard; this user's repos use
  `rubocop-rails-omakase`). Don't hand-tune style a formatter would rewrite.

## Layer 2 — Everyday craft

### Blocks & control flow
- `{ }` for single-line blocks, `do…end` for multi-line; `it`/numbered params
  only for trivial one-liners (`map { it.name }`).
- `case/in` (pattern matching) for structured data — hashes, nested params,
  result tuples; `case/when` for flat value dispatch. *Why:* `in` destructures
  and raises `NoMatchingPatternError` on unhandled shapes — misshapen input
  fails loudly at the boundary instead of nil-ing deep inside.

  ```ruby
  case payload
  in { event: "paid", invoice: { id: String => id } } then settle(id)
  in { event: "failed" }                              then flag_failure(payload)
  end
  ```
- Safe navigation `&.` only for genuinely-optional values. Chaining `&.` to
  silence a nil that "should never happen" converts a crash into a wrong
  answer — the worse bug.

### Objects & data
- **Value objects over loose hashes.** Reach for `Data.define` (immutable,
  compares by value) the moment two methods pass the same hash around:

  ```ruby
  Money = Data.define(:amount, :currency)   # Money.new(amount: 5, currency: "INR")
  ```
  *Why:* a hash has no contract — typos in keys fail silently; a Data class
  fails at construction.
- **Keyword arguments** for any method beyond one or two params — call sites
  stay readable and order-independent. Positional args are for natural order
  (`move(from, to)`).
- **`freeze` mutable constant literals** (`LIST = %w[a b].freeze`). *Why:*
  constants are globally shared; unfrozen ones invite spooky
  action-at-a-distance mutation.
- Mixins (`include`) for shared *behavior* with a real seam (`Comparable`
  via `<=>`, `Enumerable` via `each`); composition (a wrapped collaborator)
  over deep inheritance for everything else.

### Errors & nil
- **Define a domain hierarchy** rooted in `StandardError`, never raise/rescue
  `Exception` (that catches `SignalException`/`SystemExit` — breaks Ctrl-C):

  ```ruby
  class AppError < StandardError; end
  class RateLimited < AppError; end
  ```
- **Rescue the narrowest class you can actually handle.** Bare `rescue => e`
  that logs-and-continues is the classic "it just stopped working" bug —
  re-raise or convert to a typed error with context.
- **Raise for exceptional, return for expected.** A lookup that can miss
  returns `nil` (or a null object); a violated invariant raises. Mixed
  signals force callers to both check nil *and* rescue.
- `ensure` for cleanup, `retry` only with a bounded attempt counter and
  backoff — an unconditioned `retry` is an infinite loop wearing error
  handling's clothes.

### Gems & tooling
- **Stdlib first:** `Set`, `Pathname`, `JSON`, `CSV`, `Net::HTTP`,
  `OpenStruct`-never (slow, duck-typed trouble — use `Data.define`). A gem
  must beat the stdlib clearly to earn its supply-chain risk.
- Vet additions: maintained, sane transitive deps, clear license. Add via
  `bundle add`, commit `Gemfile.lock`. Pinning policy is per-project — this
  user's repos pin exact (`= x.y.z`) with a one-line why on compatibility
  pins; follow the project's `AGENTS.md`.

## Layer 3 — Design (senior/staff judgment)

- **Private by default.** Expose the smallest public API; every public method
  is a promise you must keep through refactors. `private` everything until a
  second caller exists.
- **Inject dependencies through kwargs with defaults** rather than reaching
  for globals/constants inside methods:

  ```ruby
  def initialize(clock: Time, gateway: Billing::Gateway.build) … end
  ```
  *Why:* tests swap the seam without stubbing constants; the dependency list
  is visible in the signature.
- **Metaprogramming discipline:** `define_method` in a loop is fine;
  `method_missing` is a last resort and must pair with
  `respond_to_missing?`. Never monkey-patch core classes in app code — the
  patch applies globally and outlives its context. (Refinements exist but
  read as a trap for the next maintainer; prefer a wrapper class.)
- **Immutability as the default posture:** frozen constants, `Data` values,
  no mutable module-level state. *Why:* it's also the cheapest thread-safety
  story — threads sharing only frozen data can't race on it.
- **Result objects for multi-outcome operations** (`ok?`/`error_code`
  carriers) where callers must branch; exceptions for the truly exceptional.
  Pick one convention per codebase and hold it.
- **Performance is measured, not guessed.** Reach for `benchmark-ips` or a
  profiler before rewriting "slow" code; most Ruby slowness is N+1 I/O or an
  accidental O(n²) `include?` inside a loop (use a `Set`).

## Testing

- RSpec or Minitest — match the project. One behavior per example, named for
  the behavior (`"rejects a foreign task_group"`), not the method.
- Arrange/Act/Assert with a blank line between phases. Don't mock what you
  own — mock true boundaries only (network, clock, randomness); over-mocked
  tests pass while the real wiring is broken.
- Control time with `travel_to`/injected clocks — a test that fails at
  midnight or month-end is a design smell surfaced late.
- Show every command **with its expected success output** in docs/runbooks:

  ```bash
  $ bundle exec rspec
  ........
  Finished in 0.42s (files took 0.8s to load)
  8 examples, 0 failures
  ```

## Sources

Distilled from the community Ruby Style Guide (rubystyle.guide, enforced by
RuboCop), Ruby core's own evolution (pattern matching, `Data.define`,
frozen-string idioms), thoughtbot's guides, and the design vocabulary of
*Practical Object-Oriented Design in Ruby* (Metz) — composition, small public
surfaces, injected dependencies.

## When in doubt

Pick the boring, conventional construct a future maintainer will recognize
on first read. Cleverness that needs a comment is a smell.
