# Naming conventions

How scripts and docs in this repo are named, and **why**, so a brand-new
contributor can guess a file's job from its name alone — and name a new file
the same way without asking anyone.

Scope: shell scripts (`scripts/**`, `.claude/**`) and Markdown docs. The
condensed rules also live in [`AGENTS.md`](AGENTS.md) ("Naming conventions") so
the AI agents enforce them; this file is the full reference.

## TL;DR

- **Scripts:** lowercase `kebab-case`, `verb-first`. The verb says the
  **lifecycle** (run-once vs run-often); the rest names the **target**
  (env + platform + topology). `bootstrap-single-vm.sh`, not `provision-ec2.sh`.
- **Docs:** lowercase `kebab-case`, except all-caps landmark files
  (`README.md`, `CONTRIBUTING.md`, `AGENTS.md`, this file, …).
- **One concept = one word**, everywhere (`digitalocean`, never `do`).
- **No abbreviation a newcomer wouldn't know.** Spell it out.

## Shell scripts

### 1. Form

Lowercase `kebab-case`, `.sh` extension, executable (`chmod +x`). No
`snake_case`, no `camelCase`, no spaces.

```
provision_do_single.sh                 ✗  snake_case + "do" reads as a verb
provision-digitalocean-single-vm.sh    ✓
```

### 2. Verb first — and the verb encodes lifecycle

The **prefix is a verb from the fixed vocabulary below**. The verb's first job
is to tell you *when* you run the script — **once on a fresh host** vs **over
and over while the app lives**.

**Run-once / idempotent** (run once per host or cloud account; safe to re-run):

| Verb | Means | Runs | Example |
|---|---|---|---|
| `provision-` | Create cloud **infrastructure** (a VM, instance, or managed DB) | off-box, from your laptop/CI against a cloud API | `provision-aws-lightsail-single-vm.sh` |
| `bootstrap-` | Turn a **fresh host** into the full target architecture (services, web server, DB, backups, TLS) | on the box | `bootstrap-single-vm.sh` |
| `setup-` | Install **dependencies / runtimes / prereqs** to get a machine ready (lighter than `bootstrap-`) | on the box | `setup-ubuntu.sh` |
| `migrate-` / `seed-` | One-time data operations | anywhere | — |

**Repeatable / runtime** (run many times over the app's life):

| Verb | Means | Example |
|---|---|---|
| `deploy-` | Ship a new **release of the app** to a target | `deploy-digitalocean-app-platform.sh` |
| `run-` | Run a process in the **foreground** on this box (blocks; Ctrl-C stops) | `run-production-foreground.sh` |
| `start-` | Start a **long-lived / background** service | — |
| `build-` | Produce a build artifact | — |
| `backup-` | Take a backup | — |
| `check-` | Read-only verification / health check | — |

> **Spanning stages?** A script that does several stages in one run (e.g.
> create the box *and* deploy the app) is named for its **end goal** — the state
> you wanted when you ran it.

### 3. Name the target — and only what the script truly needs

After the verb, name the **environment**, **platform**, and **topology** — never
leave them implied:

- **environment:** `-production`, `-staging`, `-local`
- **platform:** `-aws`, `-lightsail`, `-digitalocean`, `-ubuntu`, `-ec2`
  *(use `-ec2` only when the script genuinely needs Amazon EC2)*
- **topology:** `-single-vm`, `-containers`, `-app-platform`, `-nginx`,
  `-foreground`

**Rule: don't bake in a platform the script doesn't require.** An installer that
runs on *any* Ubuntu VM is `bootstrap-single-vm.sh`, **not** `bootstrap-ec2.sh` —
naming it `-ec2` would be a lie a newcomer has to discover.

### 4. One concept = one word

The same idea always gets the same word, repo-wide:

| Concept | Always write | Never |
|---|---|---|
| Create a cloud VM / instance / DB | `provision-` | `setup-`, `bootstrap-` |
| Configure a fresh box into the prod stack | `bootstrap-` | `provision-`, `setup-` |
| Install deps so the app can run | `setup-` | `provision-`, `bootstrap-` |
| One all-in-one server runs everything | `single-vm` | `single`, `single-box`, `one-box` |
| Managed-container deploy | `containers` | `docker`, `ls` |
| DigitalOcean | `digitalocean` | `do` |
| Amazon EC2 (only when EC2-specific) | `ec2` | — |
| Foreground run, no process manager | `foreground` | — |

### 5. Abbreviations

- **Fine** (industry-standard, a newcomer knows them): `aws`, `db`, `vm`,
  `ssh`, `tls`, `api`, `ip`, `ci`, `cd`, `pg`.
- **Spell out** everything else: `do` → `digitalocean`, `prod` → `production`,
  and any app-specific shorthand.

## Markdown docs

- **Landmark files** keep their conventional names and are **never** renamed —
  tools and humans find them by exact name:
  - Top-level references: `README.md`, `CONTRIBUTING.md`, `NAMING-CONVENTIONS.md`
  - Agent / index landmarks: `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, `FEATURES.md`,
    `CODEOWNERS`
  - Tool-mandated exact names: `.github/**/*.instructions.md` (Copilot),
    `.github/pull_request_template.md` (GitHub)
- **Every other doc:** lowercase `kebab-case` — `deployment-guide.md`,
  `seed-data.md`.
- **Script ↔ doc pairing:** a runnable script and its dedicated runbook share
  the same stem and are renamed **together**. A *topic* doc that covers several
  scripts only references them — it keeps its topic name.
- **Numeric taxonomies in filenames:** avoid them; if you must number, keep the
  series **gapless and unique** and pair the number with a word
  (`deploy-level-2-nginx.md`, not a bare `level-2.md`).

## Directories

In scope, but **higher-risk and lower-priority** than file renames (a moved
directory churns every path under it). Rename a directory only when its name is
genuinely misleading, propose it **separately**, opt-in per directory.

## Renaming an existing file

`git mv` only — never delete + recreate (it preserves history **and** the
executable bit). One **atomic commit per rename** = the move plus **every**
reference update (other scripts, all docs, README, Makefile, `package.json`,
Dockerfile, compose, CI), so each commit is self-consistent and bisectable.

```sh
# 1. Move it (history + exec bit preserved):
git mv scripts/shared/provision-ec2.sh scripts/shared/bootstrap-single-vm.sh

# 2. Update every reference, then prove none remain:
git grep -nI 'provision-ec2'
#   (prints nothing = success)

# 3. Commit the move + its references together:
git commit -m "refactor: rename provision-ec2.sh -> bootstrap-single-vm.sh"
```

`git show --stat` then shows the file as a rename (`R…`), not a delete+add.
Full git rules (rebase-only, `--force-with-lease` only, branch naming) are in
[`AGENTS.md`](AGENTS.md) "Git workflow". The `repo-naming` skill
(`.claude/skills/repo-naming/`) drives the whole audit → rename → verify pass.

## Adding a new script

1. Pick the **verb** from the vocabulary — get the lifecycle right.
2. Add the **env + platform + topology** the script actually needs (and nothing
   it doesn't).
3. lowercase `kebab-case`, `.sh`, `chmod +x`.
4. If it has a dedicated runbook doc, give the doc the **same stem**.
5. Line 2 of the file is a one-line purpose comment **matching the filename**.

## Keep this current

When you rename or add a script, update its references here in the **same**
change, and keep a short table of every script + its one-line purpose so a
newcomer sees the whole surface at a glance. Every example in this doc must match
a file that actually exists.
