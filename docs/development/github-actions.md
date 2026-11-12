# GitHub Actions — practical guide

How to add a working CI workflow to a new project, with the minimum
necessary parameters and the gotchas already paid for once. The
reference implementations are the per-codebase workflows under
[`.github/workflows/`](../../.github/workflows) —
[`backend.yml`](../../.github/workflows/backend.yml),
[`web.yml`](../../.github/workflows/web.yml), and
[`mobile.yml`](../../.github/workflows/mobile.yml) — read them alongside
this doc. They are split per codebase (rather than one workflow with
three parallel jobs) so a web-only change doesn't spin up the backend
runner.

## When to use it

GitHub Actions runs on every push and pull request to a GitHub repo. Use
it for anything that must always be green before merge:

- Test suites (here: backend RSpec + web Jest + mobile Jest)
- Linters / formatters / type checks
- Security scans (brakeman, bundler-audit, npm audit)
- Build verification (artifact compiles, container image builds)
- Release automation (tagging, publishing)

Don't use it for: long-running jobs (>6h timeout), interactive flows,
anything that needs to read your local filesystem.

## Where workflows live

```
<repo-root>/.github/workflows/<name>.yml
```

**Critical:** GitHub Actions only reads workflow files at the repository
root, under `.github/workflows/`. A file at e.g.
`backend/.github/workflows/ci.yml` is silently ignored — a classic
first-monorepo bug: CI "exists" but never runs.

## The minimum workflow

```yaml
name: Test                    # human-readable name shown in the UI

on:                           # what triggers the workflow
  pull_request:
  push:
    branches: [ main ]

jobs:                         # one or more independent units of work
  build:                      # job id (used in `needs:` references)
    name: Build               # human-readable
    runs-on: ubuntu-latest    # runner OS

    steps:
      - uses: actions/checkout@v7
      - run: echo "hello"
```

Three required top-level keys: `name`, `on`, `jobs`. Inside each job:
`runs-on` and `steps`. That's the floor.

## Required parameters

### Workflow level

| Key | Required | Purpose |
|---|---|---|
| `name` | optional but recommended | What appears in the Actions UI. |
| `on` | **yes** | Trigger events (see next section). |
| `jobs` | **yes** | Map of one or more jobs. Each is an independent VM. |
| `concurrency` | optional | Cancel in-flight runs when a new one starts. Useful for PRs. |
| `permissions` | optional but recommended | Restrict the GITHUB_TOKEN scopes (default is too permissive). |

### Job level

| Key | Required | Purpose |
|---|---|---|
| `runs-on` | **yes** | `ubuntu-latest`, `macos-latest`, `windows-latest`, or self-hosted. |
| `steps` | **yes** | Ordered list of steps. Run sequentially. |
| `name` | optional | UI label for the job (defaults to job id). |
| `needs` | optional | Other jobs that must succeed first. Without this, jobs run in parallel. |
| `services` | optional | Sidecar containers (Postgres, Redis, etc.). |
| `defaults.run.working-directory` | optional | Default cwd for every `run:` step. **Beware** the gotcha below. |
| `env` | optional | Job-wide environment variables. |
| `if` | optional | Conditional execution (`if: github.ref == 'refs/heads/main'`). |
| `timeout-minutes` | optional | Default is 360 (6 hours). Set lower for fast suites. |
| `strategy.matrix` | optional | Run the same job multiple times across a parameter matrix. |

### Step level

Two step shapes — one of these is required per step:

| Key | Purpose |
|---|---|
| `uses` | Run a published action (e.g. `actions/checkout@v7`). Versioned via `@<ref>`. |
| `run` | Execute a shell command on the runner. |

Common optional step keys:

| Key | Purpose |
|---|---|
| `name` | UI label. |
| `with` | Inputs to a `uses:` action. |
| `env` | Step-scoped env vars (override job-level). |
| `if` | Conditional execution. |
| `working-directory` | Override the default cwd for this `run:` step. |

## Trigger events (`on:`)

```yaml
on:
  push:
    branches: [ main ]            # only main, not feature branches
    paths: [ 'backend/**' ]       # only when these files change
  pull_request:                   # every PR, all branches
  schedule:
    - cron: '0 6 * * 1'           # Mondays at 06:00 UTC
  workflow_dispatch:              # manual button in the UI
  release:
    types: [ published ]
```

**Important:** `pull_request` from a fork has reduced permissions and no
secrets. For workflows that need secrets on PRs, use
`pull_request_target` — but be aware of the security implications
(arbitrary fork code with secrets is the #1 supply-chain attack vector
on Actions).

### Skipping unnecessary runs (path filters)

A push that only edits markdown shouldn't burn a runner minute on the
test suite. Filter trigger events by changed paths:

```yaml
on:
  pull_request:
    paths-ignore:
      - '**/*.md'
      - 'docs/**'
  push:
    branches: [ main ]
    paths-ignore:
      - '**/*.md'
      - 'docs/**'
```

How `paths-ignore` decides:

- The filter compares against the **diff for the push/PR**, not the full
  tree. A push that touches `README.md` and `src/foo.js` still runs CI
  (because `src/foo.js` is not ignored).
- A push that touches **only** ignored paths is skipped — the run never
  shows up in the Actions tab. No queue, no minutes spent.
- `paths-ignore` and `paths` are mutually exclusive on the same event.
  If you have a complex inclusion rule, use `paths:` (allow-list) only.
- The same filter must be repeated under each event (`push:`,
  `pull_request:`) — there's no top-level shared block.

The two-line filter above (`**/*.md` + `docs/**`) covers most
documentation-only changes. Add more globs if you have non-markdown
docs (e.g. `'images/**'`, `'mkdocs.yml'`) — but **don't add code
directories** by mistake. A misplaced `'src/**'` would silently disable
CI for every code change.

**Caveat for branch protection rules.** If you use "Require status
checks to pass" with the test workflow as a required check, a skipped
run reports nothing — and the PR may sit forever waiting on a status
that never arrives. Two ways out:

1. Don't make the test job a required check; rely on status reporting
   (the PR shows green when nothing ran).
2. Add a tiny "always-pass" job that runs on every event and is the
   actual required check, while the heavy job uses `paths-ignore`.

## Step actions vs `run:`

```yaml
- uses: actions/setup-node@v7     # invokes a published action
  with:
    node-version: "26.13.0"

- run: npm ci                     # runs a shell command
```

`uses:` is for reusable actions (the entire community ecosystem under
github.com/marketplace/actions). `run:` is for arbitrary shell. Prefer
`uses:` over reinventing — `actions/checkout`, `actions/cache`,
`actions/setup-node` are battle-tested.

## Common actions and their parameters

### `actions/checkout` — fetch the repo

```yaml
- uses: actions/checkout@v7
```

Pin to a major version. `@v6` is the latest stable major. Always the
**first** step that needs the working tree — nothing else can read
source files until this runs.

Optional inputs you may need:

| Input | Default | When to set |
|---|---|---|
| `fetch-depth` | `1` | Set to `0` for full history (e.g. for `git log`-based versioning). |
| `ref` | the triggering ref | Check out a specific branch/tag/sha. |
| `token` | `GITHUB_TOKEN` | Use a PAT for cross-repo or `git push` from CI. |
| `submodules` | `false` | `true` or `recursive` for submodules. |

### `actions/setup-node` — install Node.js

```yaml
- uses: actions/setup-node@v7
  with:
    node-version: "26.13.0"
    cache: npm
    cache-dependency-path: web/package-lock.json
```

`@v6` is the latest stable major (see
[Action version pinning](#action-version-pinning) below for why its
internal Node runtime matters).

Inputs:

| Input | Required | Notes |
|---|---|---|
| `node-version` | one of these | Literal version like `26.13.0` or `26.x`. |
| `node-version-file` | one of these | Path to `.nvmrc` or `package.json`. |
| `cache` | optional | `npm`, `yarn`, or `pnpm`. Caches the package store keyed by the lockfile. |
| `cache-dependency-path` | optional | Glob to the lockfile. Required for monorepos where `package-lock.json` is not at repo root. |

### `ruby/setup-ruby` — install Ruby + bundle

```yaml
- uses: ruby/setup-ruby@v1
  with:
    ruby-version: 4.0.9
    bundler-cache: true
    working-directory: backend
```

Inputs:

| Input | Required | Notes |
|---|---|---|
| `ruby-version` | one of these | Literal version. Pin explicitly to avoid file-lookup ambiguity. |
| `ruby-version-file` | one of these | Path to `.ruby-version`. Resolved **relative to `working-directory`**, which catches everyone once. |
| `bundler-cache` | optional | `true` runs `bundle install` and caches `vendor/bundle` keyed by `Gemfile.lock`. |
| `working-directory` | optional | Where Gemfile lives (and where `ruby-version-file` is resolved from). |

### `actions/cache` — manual caching

For any toolchain not covered by setup-* actions:

```yaml
- uses: actions/cache@v6
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

Cache keys must be unique per dependency-set; `hashFiles()` over the
lockfile is the standard pattern.

## Services (sidecar containers)

Spin up Postgres, Redis, etc. for the duration of a job. The runner can
reach them at `localhost:<port>`.

```yaml
jobs:
  backend:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd="pg_isready"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
    steps:
      - uses: actions/checkout@v7
      - run: psql -h localhost -U postgres -c '\l'
        env:
          PGPASSWORD: postgres
```

The `--health-*` options are critical — without them, your test step
can race the container's startup and fail.

## Secrets and environment variables

Define secrets in **Settings → Secrets and variables → Actions**, then
read them via `${{ secrets.NAME }}`:

```yaml
- run: ./deploy.sh
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Rules of thumb:

- Never `echo` a secret. GitHub auto-masks them in logs, but escaping
  pipes / base64 / etc. can defeat the masking.
- `secrets` are **not available** to `pull_request` workflows from
  forks. If you need them, use `pull_request_target` carefully.
- For short-lived cloud creds, prefer **OIDC** (`id-token: write`
  permission + cloud trust policy) over long-lived secrets.

## The `working-directory` gotcha

`defaults.run.working-directory: backend` applies to **every** `run:`
step in the job. If a `run:` step fires before `actions/checkout`, bash
tries to `cd backend` before checkout has created the directory and the
job dies with "No such file or directory". Always:

```yaml
steps:
  - uses: actions/checkout@v7     # FIRST
  - run: anything                  # any run: step
```

## Least privilege and timeouts

Every workflow in this repo declares a top-level `permissions:` block
and a `timeout-minutes` on every job. *Why:* the default `GITHUB_TOKEN`
can be broader than a CI job needs, so a compromised dependency or
action step inherits that scope; and a hung job (the open-handle Jest
case below) otherwise burns runner minutes for up to six hours.

```yaml
permissions:
  contents: read        # widen per job only when a step needs it

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20 # lint/scan 15 · test 20 · tiny guards 5
```

## Action version pinning

Two reasons to pin major versions:

1. **Security** — `@main` or `@v4` (mutable) means a malicious tag
   force-push could replace the code you thought you were running. Most
   workflows are fine pinning to a major (`@v6`); high-security ones
   pin to a SHA.
2. **Runtime deprecation** — actions are JavaScript apps that GitHub
   runs on a Node.js version baked into the action's `action.yml`
   (`using: node24`). When GitHub deprecates a Node major, every action
   still pinned to a major built against it triggers a warning — bump
   to the newest major (e.g. `setup-node@v4`, Node 20 internally, →
   `@v6`, Node 24) before the cutoff GitHub announces.

To check what runtime an action uses:

```bash
gh api repos/<owner>/<action>/contents/action.yml --jq '.content' \
  | base64 -d | grep using
```

## Local validation

Before pushing, validate the YAML:

```bash
for f in .github/workflows/*.yml; do
  ruby -ryaml -e "YAML.load_file('$f'); puts '$f ok'"
done
# or with python:
for f in .github/workflows/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f')); print('$f ok')"
done
```

For deeper validation (schema + simulated runs), use
[`act`](https://github.com/nektos/act) — runs workflows locally in
Docker. Heavier dependency, only worth it for complex workflows.

## Reading runs from the CLI

Once `gh` is authenticated:

```bash
gh run list --limit 5             # recent runs
gh run watch <id>                 # follow until done
gh run view <id>                  # high-level status of every job
gh run view --job=<job-id>        # dive into one job
gh run view --log --job=<job-id>  # full log
gh run cancel <id>                # cancel a stuck run
gh run rerun <id>                 # rerun the same commit
```

`gh run watch` is the equivalent of `tail -f` for CI. Use it after
every push that changes the workflow itself.

## Reference: the shipped workflows

Three per-codebase **CI** workflows, each `paths`-filtered so a change in
one codebase doesn't spin up the others' runners, plus three repo-wide
guards:

| Workflow | Toolchain | Jobs |
|---|---|---|
| [`backend.yml`](../../.github/workflows/backend.yml) | Ruby 4.0.9 + Postgres 18 service | RuboCop · Brakeman + bundler-audit · `bin/rails db:test:prepare && bundle exec rspec` |
| [`web.yml`](../../.github/workflows/web.yml) | Node 26.13.0 + npm cache | ESLint · `npm ci && npm test -- --watchAll=false --coverage --forceExit` |
| [`mobile.yml`](../../.github/workflows/mobile.yml) | Node 26.13.0 + npm cache | ESLint · `npx tsc --noEmit` · `npm ci && npm test -- --coverage` (iOS + Android Jest projects in one run) |
| [`docs-links.yml`](../../.github/workflows/docs-links.yml) | system Ruby (stdlib only) | [`scripts/check-doc-links.rb`](../../scripts/check-doc-links.rb) — broken-link + orphan check on any markdown change |
| [`agents-pointers.yml`](../../.github/workflows/agents-pointers.yml) | none | AI-rules pointer-integrity check, documented in [ai-agents.md](ai-agents.md) |
| [`secrets-guard.yml`](../../.github/workflows/secrets-guard.yml) | none | Fails if a secret file (master.key, .env, private keys) is ever tracked |

Deploy / CD workflows are deliberately **not** shipped — deployment is
per-app infrastructure (target host, container platform, secrets model).
Author them in the app when the deploy story exists.

Coverage thresholds are enforced inside each runner's config
(SimpleCov / `jest.config.js` pins), not duplicated in the workflows —
the policy is `AGENTS.md` "TEST COVERAGE" (100% target, 90% floor,
backend 100% line mandatory).

The `--forceExit` in the web workflow is a workaround for undici's
global connection pool keeping the event loop alive after tests
finish — locally Jest force-exits with a warning; on the Ubuntu
runner it just hangs.

## Common failures and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `No such file or directory` from a run step | `working-directory` set, but step ran before checkout | Move `actions/checkout` to the first step. |
| Job hangs at "Run Jest" indefinitely | Open handles (undici, sockets, timers) keep the event loop alive | Pass `--forceExit` to Jest. Better: close the leak in `afterAll`. |
| `Node.js 20 actions are deprecated` warning | Action pinned to a major built on Node 20 | Bump to the latest major (e.g. `setup-node@v4` → `@v7`). |
| `Cannot find Gemfile.lock` from setup-ruby | `bundler-cache: true` but `working-directory` not set | Set `working-directory: <where Gemfile is>` on the action. |
| `npm ci` fails with `ELOCKVERIFY` | `package.json` and `package-lock.json` out of sync | Run `npm install` locally and commit the updated lockfile. |
| Postgres connection refused | Service container not ready when test step started | Add `--health-cmd` / `--health-retries` to the `services.<name>.options`. |
| Workflow doesn't run at all | File not at repo-root `.github/workflows/` | Move it. Subdirectory `.github/` is ignored. |
