# The AWS EC2 learning ladder

A step-by-step path for hosting personal_manager on real infrastructure,
built for a **backend developer learning production ops**. Each level is a
self-contained guide that adds *one* new production concern on top of the
previous one, so you understand each piece before stacking the next.

Start at Level 1 and climb. Every level says *what* you do and *why*, and
ends with a troubleshooting table of the real errors you'll hit.

> These guides deploy a **real app in production mode** on AWS, but they are
> a *learning* ladder, not a turnkey production system. The lower levels
> trade safety for simplicity (plain HTTP, one box); each level closes some
> of that gap. The production-grade endpoints are
> `personal_manager/docs/deployment/README.md` (hardened systemd + apt single
> host: TLS, firewall, backups) and Level 5's
> `personal_manager/deploy/aws/deploy-level-5-docker.md`
> — the ladder builds the intuition for both.

## Two ways to use this ladder — pick one

- **Deploying for real on a fresh box → run one script.**
  `personal_manager/deploy/aws/scripts/deploy-aws-single-vm.sh`
  takes a fresh box all the way in a single pass: Rails + Nginx, then the hardened
  non-root `deploy` user + push-to-deploy CD, **built once**. **This is the
  expected path for an actual deploy** — the production index
  (`personal_manager/deploy/README.md`) is where that path starts.
- **Learning production ops → climb the rungs one at a time** (Levels 1→5 below).
  That's the *teaching* route: each rung adds a single concept with its own guide.
  Levels 1 and 2 teach the base box; the combined
  `personal_manager/deploy/aws/deploy-aws-single-vm.md` is the hardening + CI/CD
  step the express script above runs.

## New to infrastructure? Start here

Never set up a server before? You're the target reader. You need four things
first, all free:

- **An AWS account** — the free tier covers a `t3.micro` for 12 months.
- **This repo cloned on your laptop** — the guides run from the repo and copy
  one secret (`backend/config/master.key`) up to the box.
- **An SSH key pair** — AWS generates one when you launch the instance;
  download it and save it as `~/Downloads/Keys/28_may_2026.pem`. It's how you log in.
- **A terminal** — built-in on macOS/Linux, or WSL on Windows.

The 30-second mental model the whole ladder rests on:

1. **EC2** is a Linux computer you rent from AWS.
2. A **security group** is its network firewall — only ports you open are reachable.
3. You log in over **SSH** and install the app's parts (database, Ruby, web server).
4. **systemd** keeps the app alive; **Nginx** (Level 2+) serves the web page.
5. Once CI/CD is wired up, pushing to `main` deploys automatically.

Each guide opens with a **"The pieces, in plain words"** table that defines every
tool the first time it appears — if a term is new, that table (e.g. in
[Level 2](../deploy/deploy-level-2-nginx.md#the-pieces-in-plain-words)) is your glossary.

## The words, in plain language

The recurring vocabulary, one line each.

| Word | Means |
|---|---|
| `provision-` script | creates cloud infrastructure (a VM, a static IP) from your laptop — run once |
| `bootstrap-` script | configures a fresh host into the full architecture, on the box — run once |
| `deploy-` script | ships a release onto infrastructure that already exists — run repeatedly |
| VM · instance · Droplet | the same idea at each provider: a Linux computer you rent |
| static IP / Elastic IP | an address that survives the box being rebuilt, so DNS keeps pointing at you |
| security group / UFW | the provider's network firewall / the on-box firewall — two independent layers |
| fail2ban | watches the SSH log and temporarily bans addresses that keep failing to log in |
| systemd | the OS's process manager: starts the app on boot, restarts it on crash |
| Puma · Solid Queue | the Rails web server · the background-job worker — the two app processes |
| Nginx | the front door: terminates TLS, serves static files, proxies API routes to Puma |
| TLS / Let's Encrypt | HTTPS / the free certificate authority the guides use, auto-renewing |
| PostGIS · `pg_dump` | Postgres's geospatial extension (the Land feature needs it) · the nightly-backup tool |

## The ladder

Levels 1–2 live here in `docs/learning/`; Levels 3–5 are the production guides in
`deploy/` — by Level 3 you are following the same documents a production
deploy uses.

| Level | You add | New concepts | Guide |
|---|---|---|---|
| **1** | One EC2 box running Rails in production mode; **Puma serves the API *and* the React build** | EC2, security group, swap, PostgreSQL/PostGIS, mise, systemd, env files, `RAILS_ENV=production` | [deploy/deploy-level-1-plain-rails.md](../deploy/deploy-level-1-plain-rails.md) |
| **2** | **Nginx** in front of Puma | a dedicated web server, static-file serving, reverse-proxy thinking, `conf.d` | [deploy/deploy-level-2-nginx.md](../deploy/deploy-level-2-nginx.md) |
| **3** | **Hardening + push-to-deploy CI/CD** (the combined one-shot single-vm deploy) | a non-root `deploy` user, SSH hardening, `ufw`, least-privilege sudo, push-to-deploy via GitHub Actions over SSH, secrets in CI, rollback | `personal_manager/deploy/aws/deploy-aws-single-vm.md` |
| **4** | **Externalized state** | managed PostgreSQL (RDS + PostGIS) via `DATABASE_HOST`; uploads on object storage (S3 + Active Storage) via `S3_BUCKET` | `personal_manager/deploy/aws/deploy-level-4-rds.md` (DB) · `personal_manager/deploy/aws/deploy-level-4-s3.md` (uploads) |
| **5** | **Containerization + zero-downtime CD** | Docker images, two-stage builds, a non-root image, `db:prepare` on boot; **Kamal** deploys from GitHub Actions with `/up` health checks + automatic rollback | `personal_manager/deploy/aws/deploy-level-5-docker.md` |

## How to use it

- **Levels 1 and 2 are alternatives — pick one.** Both put the whole app on a
  single box: Level 1 lets Puma serve everything; Level 2 adds Nginx in front
  (the more production-shaped layout). Each guide is self-contained from a fresh
  instance. Most people choose **Level 2**, the layout the single-vm deploy
  uses.
- **Then the `personal_manager/deploy/aws/deploy-aws-single-vm.md` adds
  hardening + CI/CD, and Levels 4 and 5 build on it** — each documents only
  what's *new* and links back for shared steps.
- **One box throughout.** Same `t3.micro`, evolved in place — no new
  infrastructure until Level 4.
- Each level guide pairs with a runnable script in
  [`docs/learning/deploy/scripts/`](../deploy/scripts/deploy-level-1-plain-rails.sh) (Levels 1–2) —
  the script is the guide's commands in one pass, for re-runs after you've
  understood the steps.

## Done climbing?

Everything past the ladder is production territory:
`personal_manager/deploy/README.md` is the pick-your-path index — managed
platforms, the self-managed single VM, the cutover checklist, and the
"beyond one box" hardening list. The *architecture and reasoning* behind that
hardening list is [aws-secure-hosting.md](aws-secure-hosting.md); the reusable
app-agnostic AWS walkthrough is
[aws-deployment-template.md](aws-deployment-template.md).
