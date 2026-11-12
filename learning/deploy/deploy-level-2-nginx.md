# Level 2 — Add Nginx in front of Puma

> **EC2 learning ladder · Level 2 of 5** — [the ladder](../aws/aws-ec2-ladder.md).
> Previous: [Level 1 — plain Rails, Puma only](deploy-level-1-plain-rails.md).
> Next: `personal_manager/deploy/aws/deploy-aws-single-vm.md`.
>
> Level 2 adds a dedicated web server (**Nginx**) in front of Puma — the
> standard production front door for serving static files and (later)
> terminating TLS.

> **In plain words:** the same demo box as Level 1 plus Nginx — the dedicated
> web server production setups put in front of Rails. You learn what a real
> front door does (static files, buffering, the one place TLS will later live),
> and you end up on the layout every later level builds on.

The **minimal** path to a clickable demo of personal_manager on one AWS
free-tier EC2 box: Rails API + the React web build + PostgreSQL/PostGIS,
all on the same host, reachable over plain HTTP at the instance's public
IP. Goal: a working public demo in well under an hour, and a first,
beginner-friendly taste of provisioning a Linux server by hand.

This guide assumes **no prior DevOps or Nginx experience**. Every step
says *what* you run and *why*, and the troubleshooting table at the end
lists every error we actually hit, with the exact fix.

> Want one less moving part? [deploy-level-1-plain-rails.md](deploy-level-1-plain-rails.md)
> is the same demo **without Nginx** — Puma serves the React build *and* the
> API on a single port. Simpler to set up; this Nginx variant is the more
> production-shaped layout.

> **This is a throwaway demo, not production.** It serves HTTP (no TLS)
> and keeps the database on the same box with its password in a file. For the real thing — TLS, hardening,
> backups — use `personal_manager/docs/deployment/README.md` (this app) or
> [aws/aws-deployment-template.md](../aws/aws-deployment-template.md) (reusable,
> explained); managed Postgres/S3 and the Kamal container CD are
> Levels 4–5. The "[Why this isn't production](#why-this-isnt-production)"
> section at the end lists exactly what was traded away — read it to see
> the gap between "a demo that works" and "production".

## The pieces, in plain words

You're going to install and wire together a handful of programs. Here's
what each one is and why it's here — skim this once and the steps make
sense:

| Piece | What it is | Why it's here |
|---|---|---|
| **EC2 instance** | A Linux computer you rent from AWS, running in their data center. | The server that hosts everything. "Free tier" = a small one (1 GB RAM) at no cost for the first year. |
| **Security group** | AWS's network firewall, configured in the web console. | Decides which ports the public internet may reach (e.g. 22 for SSH, 80 for the web page). Closed by default. |
| **SSH** | An encrypted remote terminal (`ssh`). | How you log into the box to run commands. |
| **Swap** | Disk space used as overflow when RAM runs out. | 1 GB RAM isn't enough to compile the app; swap stops the build from being killed. |
| **PostgreSQL** | The database server. | Stores all the app's data. **PostGIS** is an add-on giving it map/location column types this app needs. |
| **Ruby / Rails** | The backend language + framework. | The API: it answers data requests and talks to the database. |
| **Puma** | The program that runs Rails and listens on a network port. | This is the actual "backend process" — when people say "the API is running", they mean Puma is up on port 3000. |
| **Node / Vite** | JavaScript toolchain. | Used once, to *compile* the React frontend into plain static files (HTML/CSS/JS). Not needed afterwards. |
| **Nginx** | A web server. | Hands the compiled frontend files to browsers on port 80. It's the standard, fast "front door" for web apps — far better at serving files than the app itself. |
| **systemd** | Linux's service manager. | Keeps the API (Puma) running: starts it on boot, restarts it if it crashes. Without it you'd have to babysit a terminal. |
| **mise** | A version manager. | Installs the *exact* Ruby and Node versions this project pins. Ubuntu's built-in Ruby is too old. |
| **`.env.production`** | A file of `KEY=value` settings. | Secrets and config (DB password, allowed hostnames, mail settings) the app reads when it starts. Kept out of git. |

## How a page load actually works (the mental model)

```
 Your browser  (on your laptop)
   │
   │  1. GET http://<EC2_IP>/          →  port 80  (downloads the page)
   │  2. its JS then calls /auth, /api  →  port 80  (same origin; Nginx proxies)
   ▼   every request hits ONE public port:
 ┌───────────────────────────── EC2 instance ─────────────────────────────┐
 │ port 80   →  Nginx  ┬─ serves index.html + the compiled React          │
 │                     └─ proxies /auth /api /up /rails /cable to Puma ─┐  │
 │ port 3000 →  Puma → Rails   (localhost only — NOT a public port)  ◄──┘  │
 │                │                                                       │
 │                ▼                                                       │
 │ port 5432 →  PostgreSQL + PostGIS                                      │
 │              (4 DBs: primary + cache + queue + cable)                  │
 └────────────────────────────────────────────────────────────────────────┘
```

Key things a beginner trips on, all explained by this diagram:

- **One public port, not two.** Port **80** serves the page *and* the API.
  The browser downloads the page from 80, and its JavaScript then calls
  `/auth`, `/api`, … on that **same origin**; Nginx forwards
  (reverse-proxies) those paths to Puma on `127.0.0.1:3000`. Only **80** is
  open in the security group — port **3000 stays bound to localhost**,
  unreachable from the internet.
- **The frontend is not "running".** It's just files. `npm run build`
  compiles React into `web/dist/`, and Nginx serves those files. There's
  no frontend process and no frontend port of its own.
- **No CORS for the web app.** Page and API share one origin
  (`http://<EC2_IP>`), so every data call is same-origin — there's no
  cross-origin check to pass, and the web app needs no entry in
  `CORS_ALLOWED_ORIGINS`. (That setting still exists for the *mobile*
  app's Expo-web target, and local dev still needs it: there the web app
  on `:5173` calls the API on `:3000` cross-origin.)
- **No host/IP baked into the build.** `VITE_API_BASE_URL` is left
  **empty**, so the compiled JS calls the API with relative paths
  (`/auth/login`) on whatever origin served the page. The same bundle runs
  on any host or IP — no rebuild when the public IP changes.

> New to *why* same-origin behind a proxy matters (origins, CORS, the two
> firewalls, build-time vs runtime config)? See the networking case study:
> [`docs/learning/devops/devops-01-same-origin-reverse-proxy.md`](../devops/devops-01-same-origin-reverse-proxy.md).

## Versions (match the repo — do not substitute)

| Tool | Version | Source of truth |
|---|---|---|
| Ubuntu | 26.04 LTS | the AMI you pick |
| Ruby | 4.0.9 | `.ruby-version`, `.mise.toml` |
| Node | 26.13.0 | `.mise.toml` |
| Rails | 8.1.3 | `backend/Gemfile` |
| PostgreSQL | 18 (26.04 default) | apt default cluster |
| PostGIS | 3.x | `postgis` apt package |

Ubuntu 26.04's apt Ruby is 3.3.x — **too old** for the `ruby "4.0.9"`
pin in `backend/Gemfile`. That's exactly why we use `mise` (Step 4) to
install the precise version instead of `apt install ruby`. The build
deps in Step 2 and the swap in Step 1 are still needed: native gems
compile during `bundle install` and the Vite build is memory-hungry.

## Your deployment values (fill in once)

Two values are unique to your deployment. Each appears in the commands
below as a `<TOKEN>`. **You never edit this guide itself.** Copy the
block below into your laptop's terminal, change only the two assignment
lines to your real values, and run it. It *generates* `my-deploy.md` — a
personal copy of this guide with every command paste-ready. That file is
not in the repo and never will be: it contains your real IP and database
password, so it is gitignored — never commit it. When a value changes,
edit its one line and re-run the block; the copy regenerates everywhere.

**Where the files live — two terminals.** The guide and `my-deploy.md`
exist only on your laptop; the server is never deployed *to* from them.
Work with two terminals: one reading `my-deploy.md`, one SSH'd into the
box receiving the pasted commands. (After Step 5's clone, the unstamped
docs also exist on the box at `~/personal_manager/deploy/`; if you
want your stamped copy there too, `scp -i ~/Downloads/Keys/28_may_2026.pem my-deploy.md
ubuntu@<EC2_IP>:~/` — it holds your real password, so treat it like the
env file.) For a **command-sheet view** — each step's paste units on
one line each (commands joined with `&&`, explanations stripped,
`# expect:` success signals kept; heredoc file-writes stay verbatim) —
run [`scripts/deploy-sheet.awk`](scripts/deploy-sheet.awk):

```shell
scripts/deploy-sheet.awk docs/learning/deploy/my-deploy.md | less    # laptop, repo root
~/personal_manager/scripts/deploy-sheet.awk ~/my-deploy.md  # on the box, after the Step 5 clone
```

| Token | What it is | Where it's set | Example |
|---|---|---|---|
| `<EC2_IP>` | Public IPv4 of the instance | Step 0 — copy from the console | `203.0.113.10` |
| `<DB_PASSWORD>` | Password for the `personal_manager` Postgres role — **letters, digits, dashes only** (it is stamped via `sed` and pasted unquoted into shell and psql commands, so shell- and sed-special characters are excluded) | Step 3 — you choose it; reused in `.env.production` (Step 6) | `s3cret-pg-pass` |

```sh
# on your laptop, from the docs/learning/deploy/ directory — edit the two values, run the rest unchanged:
EC2_IP=203.0.113.10           # from Step 0
DB_PASSWORD=s3cret-pg-pass    # letters, digits, dashes only
sed "s/<EC2_IP>/$EC2_IP/g; s/<DB_PASSWORD>/$DB_PASSWORD/g" \
  deploy-level-2-nginx.md > my-deploy.md
grep -nE '<EC2_IP>|<DB_PASSWORD>' my-deploy.md || echo 'all tokens filled'
# expect: all tokens filled
```

> **`<EC2_IP>` changes on stop/start** unless you attach an Elastic IP. When
> it changes, edit the `EC2_IP=` line, re-run the block, and reapply the env
> file — see [Re-pointing after a stop/start](#re-pointing-after-a-stopstart-the-public-ip-changed).

## Run it as a script, or by hand

Steps 1–8 below are also packaged as one runnable script,
[`docs/learning/deploy/scripts/deploy-level-2-nginx.sh`](scripts/deploy-level-2-nginx.sh) — the
*scripted form* of this guide. **This doc stays the source of truth**
(read it for the full *why*); the script's comments are the one-line
versions. Step 0 (launch the instance) stays manual — the console part
can't be scripted from inside the box.

The repo is **private**, so a `curl` from `raw.githubusercontent.com`
returns 404 — copy the script up from your laptop's clone instead:

```shell
# on your laptop, from the repo root, after Step 0:
scp -i ~/Downloads/Keys/28_may_2026.pem docs/learning/deploy/scripts/deploy-level-2-nginx.sh ubuntu@<EC2_IP>:~/
# then on the box:
ssh -i ~/Downloads/Keys/28_may_2026.pem ubuntu@<EC2_IP>
./deploy-level-2-nginx.sh
```

What it handles for you:

- **Dynamic values at run time** — the public IP is read from the EC2
  metadata service (no `<EC2_IP>` filling), and the DB password comes
  from `$DB_PASSWORD` if exported, otherwise a silent prompt.
- **The two un-scriptable steps pause with instructions**: it prints the
  generated deploy key and waits while you add it on GitHub, then prints
  the exact laptop-side `scp` for `master.key` and polls until the file
  arrives.
- **Re-run safe** — every step skips when already done; an existing
  `.env.production` is never overwritten (only its two IP values are
  re-pointed), so secrets and encryption keys survive. If the OS upgrade
  wants a reboot, it tells you to reboot and re-run.

The stamped `my-deploy.md` + paste-by-step path below teaches each piece —
prefer it the first time; the script is for the second box, the redo
after a teardown, and the IP re-point after a stop/start.

## Step 0 — Launch the instance (AWS console)

*Why:* this creates the server and decides what the outside world can
reach. The **security group** is AWS's firewall — think of it as the list
of doors left unlocked. By default everything is locked; you open exactly
the ports you need.

- **EC2 → Launch instance.** AMI: **Ubuntu Server 26.04 LTS (64-bit
  x86)**. Type: **t3.micro** (or t2.micro — both free-tier eligible, 1 GB
  RAM). Create/download a key pair and save it as `~/Downloads/Keys/28_may_2026.pem` — this is
  your SSH login key; keep it safe.
- **Storage:** bump the root volume to **20 GB** (free tier allows 30 GB;
  Ruby + node_modules + Postgres need more than the 8 GB default).
- **Security group — inbound rules** (the doors you open):

  | Port | Source | Purpose |
  |---|---|---|
  | 22 | **My IP** | SSH — your terminal login. Restricted to your IP so only you can log in. |
  | 80 | 0.0.0.0/0 | the web page **and** the API (Nginx proxies API paths to Puma). `0.0.0.0/0` = anyone, so the demo is public. |

  **Do not open 3000.** The browser never talks to Puma directly — Nginx
  proxies API paths to it over localhost — so 3000 stays closed to the
  internet. (If you opened it in an earlier, non-proxied setup, remove that
  inbound rule now.)

- Launch, then copy the instance's **Public IPv4 address** — that's your
  `<EC2_IP>` from the values table above.

> **There are TWO firewalls, and beginners only think about one.** The
> security group above is the *AWS* layer. The instance may *also* run a
> host firewall (`ufw`/`iptables`) inside Ubuntu. If it's active, it can
> drop inbound `80` even when the security group allows it. The
> symptom is maddening: SSH works, `curl http://localhost` on the box
> returns `200`, but external requests never arrive (Nginx's log stays
> silent). If that happens, jump to the host-firewall fix in the
> troubleshooting table. (We hit exactly this.)

Connect to the box:

```sh
chmod 400 ~/Downloads/Keys/28_may_2026.pem    # SSH refuses to use a key others can read
ssh -i ~/Downloads/Keys/28_may_2026.pem ubuntu@<EC2_IP>
# expect: "Welcome to Ubuntu 26.04 LTS ..." and a prompt like ubuntu@ip-...:~$
```

Everything from Step 1 on runs **on the box** (over that SSH session),
unless a step explicitly says "on your laptop".

## Step 1 — Swap (mandatory on 1 GB RAM)

*Why:* compiling Ruby gems and building the React app needs more memory
than a 1 GB box has. Without swap, Linux's out-of-memory killer abruptly
kills the build (`Killed`). Swap is disk space used as slow overflow RAM —
not fast, but enough to finish the build.

```sh
sudo fallocate -l 2G /swapfile          # reserve a 2 GB file
sudo chmod 600 /swapfile                # only root may read it
sudo mkswap /swapfile                   # format it as swap
sudo swapon /swapfile                   # turn it on now
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab   # turn it on at every boot
free -h
# expect a non-zero Swap line, e.g.:  Swap:  2.0Gi  0B  2.0Gi
```

## Step 2 — System packages

*Why:* bring the OS current, then install everything the OS needs to run
the database and web server and to compile the app. One `apt` call for
the installs; dependencies pull themselves in.

A fresh instance still has pending upgrades (`apt update` reports e.g.
"47 packages can be upgraded"). That's normal: the AMI is a snapshot
frozen on its build date, and Ubuntu publishes security/bug fixes to the
archive continuously — `apt update` only refreshes the package index, it
applies nothing. Upgrade first so you start patched:

```sh
sudo apt update                    # refresh the package index
sudo apt full-upgrade -y           # apply all pending updates (the AMI lags the archive)
sudo apt autoremove --purge -y     # drop orphaned deps and their config files
sudo apt clean                     # empty the downloaded-.deb cache (frees disk)
apt list --upgradable              # verify — expect: "Listing... Done" and nothing else
[ -f /var/run/reboot-required ] && sudo reboot   # kernel/libc updated → reboot; ssh back in after ~30s
```

> If `apt` reports `Could not get lock /var/lib/dpkg/lock-frontend`,
> Ubuntu's first-boot unattended-upgrades run is still active — wait a
> minute and re-run.

```sh
sudo apt install -y \
  postgresql postgresql-contrib postgis \
  nginx git curl \
  build-essential libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev \
  libpq-dev libvips
psql --version    # expect: psql (PostgreSQL) 18.x
nginx -v          # expect: nginx version: nginx/1.x
```

What the groups are for:
- `postgresql postgresql-contrib postgis` — the database server + the
  PostGIS location-types add-on this app requires.
- `nginx git curl` — the web server, version control (to clone the code),
  and a download tool.
- `build-essential libssl-dev … libgmp-dev` — the C compiler and headers
  that native Ruby gems compile against during `bundle install`.
- `libpq-dev` — headers for the `pg` gem (Ruby's PostgreSQL driver).
- `libvips` — image library the `image_processing` gem uses for Active
  Storage image variants.

## Step 3 — PostgreSQL role

*Why:* a PostgreSQL **role** is a database user. The app logs into the
database as a role named `personal_manager` (that name is hard-coded in
`config/database.yml`). We create it with a password and the `CREATEDB`
privilege so Rails can create its databases — but **not** superuser, which
is safer.

```sh
sudo -u postgres psql -c "CREATE ROLE personal_manager LOGIN PASSWORD '<DB_PASSWORD>' CREATEDB;"
# expect: CREATE ROLE
```

`sudo -u postgres psql` runs the database admin shell as the `postgres`
superuser (the account apt set up). Pick a real password and remember it —
it goes into the env file in Step 6 as `PERSONAL_MANAGER_DATABASE_PASSWORD`.

> **Re-running this?** If you see `ERROR: role "personal_manager" already
> exists`, the role is already there from a previous attempt — don't
> recreate it, just (re)set its password and privileges:
> ```sh
> sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<DB_PASSWORD>' CREATEDB;"
> # expect: ALTER ROLE
> ```

## Step 4 — Install mise (Ruby 4.0.9 + Node 26.13.0)

*Why:* the app pins exact Ruby and Node versions in `.mise.toml`. Ubuntu's
packaged Ruby is too old, so we use **mise**, a version manager that
downloads and manages those exact versions per project.

```sh
curl https://mise.run | sh                                   # install mise
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc # load it in new shells
source ~/.bashrc                                              # load it in this shell now
mise --version                    # expect: 20xx.x.x
mise settings ruby.compile=false  # use prebuilt Ruby — see note
```

**Use the precompiled Ruby binary, don't build from source.** Compiling
Ruby 4.0.9 on a 1 GB box exhausts memory and fails (`BUILD FAILED ...
virtual memory exhausted`) even with the Step 1 swap. `ruby.compile=false`
tells mise to download a ready-built binary instead — faster, and the
default mise itself adopts in 2026.8.0. (The Step 2 build deps still
matter: the app's native *gems* compile against them later.)

## Step 5 — Get the code

*Why:* clone the repository onto the box, then have mise install the
runtimes the project pins, then copy up the one secret git can't carry.

The repo is private, so we authenticate with a per-host SSH **deploy
key** — a key generated *on the server* and registered with the GitHub
repo as read-only. (More secure than pasting a personal token, and scoped
to this one repo.)

```sh
ssh-keygen -t ed25519 -C "ec2-demo" -f ~/.ssh/id_ed25519 -N ""   # make a key, no passphrase
cat ~/.ssh/id_ed25519.pub
# copy the printed line → add it at:
#   https://github.com/ferdinandrosario/personal_manager/settings/keys
#   click "Add deploy key", paste it, read-only is enough.
git clone git@github.com:ferdinandrosario/personal_manager.git ~/personal_manager
# expect: Cloning into '/home/ubuntu/personal_manager'... done.
```

Now install the pinned runtimes. **mise refuses to use a project's
`.mise.toml` until you mark it trusted** (a safety feature, since that
file can run code) — so trust it first, then install:

```sh
cd ~/personal_manager
mise trust        # expect: ... trusted    (without this, mise install errors "not trusted")
mise install      # reads .mise.toml → Ruby 4.0.9 (prebuilt, per Step 4) + Node 26.13.0
mise current      # expect: ruby 4.0.9   node 26.13.0
```

### Copy the master key (run on your laptop, not the server)

*Why:* `backend/config/master.key` decrypts the app's secrets
(`credentials.yml.enc`) and derives its `secret_key_base`. It's
deliberately gitignored, so it is **not** in the clone — without it the
API won't boot. Copy your local one up:

```sh
# on your laptop, from the personal_manager repo root:
scp -i ~/Downloads/Keys/28_may_2026.pem backend/config/master.key \
  ubuntu@<EC2_IP>:/home/ubuntu/personal_manager/backend/config/master.key
# expect: master.key  100%   ...
```

## Step 6 — Backend: env file, gems, database, seeds

*Why:* the production app reads its configuration and secrets from
environment variables, not from code. We put them in `.env.production`.
This file is the single most error-prone part of the setup — every value
maps to something a specific config file demands at boot.

Create the file (run on the box, in `backend/`):

```sh
cd ~/personal_manager/backend
cat > .env.production <<'ENV'
RAILS_ENV=production
PERSONAL_MANAGER_DATABASE_PASSWORD=<DB_PASSWORD>
PGHOST=localhost
RAILS_ALLOWED_HOSTS=<EC2_IP>
CORS_ALLOWED_ORIGINS=http://<EC2_IP>
FORCE_SSL=false
PORT=3000
WEB_CONCURRENCY=1
SOLID_QUEUE_IN_PUMA=true
SMTP_ADDRESS=localhost
SMTP_USERNAME=demo
SMTP_PASSWORD=demo
ENV
chmod 600 .env.production
```

> **Formatting matters: no spaces around `=`.** `KEY=value`, never
> `KEY= value`. A stray space makes the shell run the value as a command
> (`100.31.66.24: command not found`) when you later `source` the file.

Append three **Active Record Encryption** keys. The app encrypts sensitive
columns (e.g. government-ID fields) and *requires* real random keys in
production. This heredoc is **unquoted** (`<<ENV`, not `<<'ENV'`) so the
`$(openssl …)` commands actually run and generate the random values:

```sh
cat >> .env.production <<ENV
AR_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
AR_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
AR_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
PROFILE_ID_FINGERPRINT_KEY=$(openssl rand -hex 32)
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
ENV
grep -c AR_ENCRYPTION .env.production            # expect: 3
grep -c PROFILE_ID_FINGERPRINT .env.production   # expect: 1
```

**Generate these once and leave them fixed.** Rewriting `.env.production`
with *different* keys makes any already-encrypted data unreadable.

What every variable is for (each one is read by a specific file — if it's
missing or wrong, that file errors at boot):

| Var | Value | Why / which file reads it |
|---|---|---|
| `RAILS_ENV` | `production` | runs the app in production mode |
| `PERSONAL_MANAGER_DATABASE_PASSWORD` | the Step 3 password | `database.yml` — how the app logs into Postgres |
| `PGHOST` | `localhost` | forces the DB connection over TCP. Without it, the driver uses a Unix socket whose `peer` auth requires the OS user to equal the DB role — it doesn't, so it fails. `localhost` switches to password auth, which works. |
| `RAILS_ALLOWED_HOSTS` | `<EC2_IP>` | `production.rb` rejects requests whose `Host` header isn't in this list (anti-spoofing). Must include your IP. |
| `CORS_ALLOWED_ORIGINS` | `http://<EC2_IP>` | `cors.rb` raises at boot if this is unset in production, so it must hold a value — but the web app no longer relies on it (it's same-origin behind the proxy, see CORS above). The page origin is a harmless, correct value to satisfy the guard. |
| `FORCE_SSL` | `false` | `production.rb` defaults to `true`, which force-redirects HTTP→HTTPS. Since this demo is plain HTTP, leaving it on breaks every page. |
| `PORT` | `3000` | the port Puma listens on |
| `WEB_CONCURRENCY` | `1` | run one Puma worker — all a 1 GB box can spare |
| `SOLID_QUEUE_IN_PUMA` | `true` | runs the Solid Queue worker **inside** Puma (`config/puma.rb`). `production.rb` sets `queue_adapter = :solid_queue`; this level runs no separate worker, so without it the friend-request mail + notification fan-out jobs would enqueue and never run. |
| `SMTP_*` | `localhost`/`demo`/`demo` | `production.rb` requires these to **boot**, but they're placeholders — see note |
| `AR_ENCRYPTION_*` | random hex | encrypt sensitive DB columns; required in production |
| `PROFILE_ID_FINGERPRINT_KEY` | random hex (`openssl rand -hex 32`) | keys the HMAC blind index that makes Profile government IDs unique; `active_record_encryption.rb` requires it in production (no fallback). Set once — rotating orphans existing fingerprints. |
| `DEVISE_JWT_SECRET_KEY` | random hex (`openssl rand -hex 64`) | signs JWTs; `devise.rb` requires it in production (no `secret_key_base` fallback) |

`RAILS_MASTER_KEY` is **not** here because the `master.key` *file* from
Step 5 already supplies it.

> **Email won't actually send.** The `SMTP_*` values are placeholders so
> the app can start; real mail (signup confirmation, password reset) will
> error. For the demo, **log in as a seeded user** rather than registering
> a new account. To enable real mail later, set real SMTP credentials —
> see `personal_manager/docs/feature/auth.md`.

Now install the gems and create the database. The order matters: the
PostGIS extension must be enabled by the **superuser** *between* creating
the databases and migrating them, so the app's non-superuser role never
needs elevated rights:

```sh
set -a; source .env.production; set +a    # load the vars into this shell
mise exec -- bundle install                # install Ruby gems — expect: Bundle complete!
mise exec -- bundle exec rails db:create   # create the 4 databases
sudo -u postgres psql -d personal_manager_production -c "CREATE EXTENSION IF NOT EXISTS postgis;"
# expect: CREATE EXTENSION
mise exec -- bundle exec rails db:prepare  # run migrations + load cache/queue/cable schemas
ALLOW_PRODUCTION_SEED=true mise exec -- bundle exec rails db:seed     # load demo data (backend/db/seeds/*)
# expect: seed output ending without errors
```

(`mise exec --` runs the following command using the project's pinned Ruby/
Node. `set -a; source …; set +a` loads every line of the env file into the
current shell so these manual commands see the same config the service
will.)

## Step 7 — Run the API as a service (systemd)

*Why:* so far Puma would only run while you sit in the terminal. **systemd**
is Linux's service manager: it runs Puma in the background, restarts it if
it crashes, and starts it automatically when the box reboots. We describe
the service in a "unit file".

```sh
sudo tee /etc/systemd/system/personal_manager.service >/dev/null <<'UNIT'
[Unit]
Description=personal_manager Rails API (Puma)
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/personal_manager/backend
EnvironmentFile=/home/ubuntu/personal_manager/backend/.env.production
ExecStart=/home/ubuntu/.local/bin/mise exec -- bundle exec rails server -b 0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload            # make systemd read the new unit file
sudo systemctl enable --now personal_manager   # start it now + on every boot
sudo systemctl status personal_manager --no-pager
# expect: Active: active (running)

curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/up
# expect: 200   (the API answers locally)
```

What the unit file says, in plain words: run as the `ubuntu` user, from the
`backend/` directory, after loading `.env.production`, by launching Puma
bound to `0.0.0.0` (all network interfaces), and restart it if it fails.
If `status` is not `active (running)`, read the cause with
`journalctl -u personal_manager -n 60 --no-pager`.

## Step 8 — Build the web app and serve it with Nginx

*Why:* the frontend is React, which must be **compiled** into static files
before a browser can use it. Then **Nginx** — a web server — serves those
files on port 80. Nginx is the standard front door for web apps: it's fast
at serving files and is where you'd later add HTTPS, caching, etc.

First, compile the frontend. Leave `VITE_API_BASE_URL` **empty** so the
built JS calls the API with relative paths on the page's own origin —
Nginx (next step) proxies those paths to Puma, so there's no host or IP to
bake in:

```sh
cd ~/personal_manager/web
echo "VITE_API_BASE_URL=" > .env   # empty = same-origin: JS calls /auth, /api, … relative
mise exec -- npm ci         # install JS dependencies — expect: added N packages
mise exec -- npm run build  # compile React → web/dist/  — expect: ✓ built in ...
```

> **The web→API wiring is one knob:** `web/.env` → `VITE_API_BASE_URL`. **Empty**
> = same-origin (this single-box setup). Set an absolute origin only for a
> separate API host. It's gitignored, so it persists across rebuilds. On this
> demo everything runs as `ubuntu` (app in `/home/ubuntu/personal_manager`); the
> hardened Level-3 box splits the same steps across the `deploy` and `ubuntu`
> users — see `personal_manager/deploy/aws/deploy-aws-single-vm.md`
> § "Migrating an existing box to same-origin".

Now configure Nginx. We put the config in `/etc/nginx/conf.d/` because
`nginx.conf` includes `/etc/nginx/conf.d/*.conf` on **every** Nginx build.
(The Debian `sites-available`/`sites-enabled` layout you'll see in many
tutorials does **not** exist on some builds — the `ln -s … sites-enabled/…`
fails — so `conf.d` is the portable choice.)

```sh
sudo tee /etc/nginx/conf.d/personal_manager.conf >/dev/null <<'NGINX'
server {
    listen 80 default_server;                     # answer HTTP on port 80
    server_name _;                                # for any hostname
    root /home/ubuntu/personal_manager/web/dist;  # serve the compiled files from here
    index index.html;

    # Forwarded to Puma on every proxied location below. Host must stay the
    # real client Host (not 127.0.0.1) so Rails' host check (RAILS_ALLOWED_HOSTS)
    # and any generated URLs see the public address.
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # API surface → Puma on localhost:3000. These match BEFORE `location /`,
    # so they win over the SPA fallback. Keep this list in sync with
    # config/routes.rb: /up (health), /auth (Devise), /api (v1 endpoints),
    # /rails (Active Storage blobs).
    location = /up   { proxy_pass http://127.0.0.1:3000; }
    location /auth/  { proxy_pass http://127.0.0.1:3000; }
    location /api/   { proxy_pass http://127.0.0.1:3000; }
    location /rails/ { proxy_pass http://127.0.0.1:3000; }

    # Action Cable WebSocket (presence, chat, reminders). The HTTP/1.1
    # Upgrade handshake needs these headers; the long read timeout keeps an
    # idle socket from being culled. Re-set Host here — a location that
    # declares its own proxy_set_header stops inheriting the server-level ones.
    location /cable {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host       $host;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    location / {
        # SPA fallback. No $uri/ directory probe — it 403s when a route name
        # collides with a built dir (e.g. the /assets screen vs Vite's dist/assets/).
        try_files $uri /index.html;
    }
}
NGINX

# A fresh Nginx often ships a stock site that also claims port 80; two
# "default_server" blocks make `nginx -t` fail with "duplicate default
# server". Disable any stock one (the "|| true" ignores "not found"):
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled 2>/dev/null || true
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test the config, then make sure Nginx is running and will start on boot.
# Use the FULL path: plain `sudo nginx` can fail "command not found" when
# /usr/sbin isn't on sudo's PATH.
sudo /usr/sbin/nginx -t                  # expect: syntax is ok / test is successful
sudo systemctl enable --now nginx        # start Nginx now + on every boot
sudo systemctl reload nginx              # apply the new config
```

> `enable --now` matters: `systemctl reload` only works if Nginx is
> *already* running. On a box where Nginx never started, `reload` silently
> does nothing and port 80 stays dead. `enable --now` guarantees it's up.

One file-permission detail: Nginx (running as user `www-data`) must be able
to walk *into* `/home/ubuntu` to reach `web/dist`. Open the traverse bit:

```sh
chmod o+x /home/ubuntu       # lets www-data enter the dir (not read your files)
```

Confirm Nginx is actually serving and listening on port 80:

```sh
sudo ss -tlnp | grep ':80'           # expect: a LISTEN line on 0.0.0.0:80 (nginx)
curl -sI http://localhost | head -1  # expect: HTTP/1.1 200 OK
```

## Step 9 — Verify the demo

From your **laptop** (these go through the security group, unlike the
`localhost` checks above which never leave the box):

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://<EC2_IP>/up   # API via Nginx proxy
# expect: 200
curl -sI http://<EC2_IP> | head -1                            # page
# expect: HTTP/1.1 200 OK
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://<EC2_IP>:3000/up  # direct API
# expect: 000 (timeout) — 3000 is NOT public; the proxy reaches Puma over localhost
```

- Open **`http://<EC2_IP>`** in a browser (note: `http://`, **not**
  `https://` — there's no TLS) → the React app loads and its health panel
  shows the API reachable (the `/up` check goes green).
- Log in with a seeded user (see `personal_manager/docs/backend/seed-data.md` for the demo
  credentials). Don't register a new account — email won't send (Step 6).

If the page doesn't load, work the troubleshooting table from the bottom
(network) up: is port 80 open in the security group? is `ufw` dropping it?
does `curl http://localhost` work *on the box*?

## Redeploying after a code change

*Why:* to ship new code, pull it, update gems/DB, rebuild the frontend, and
restart the service.

```sh
cd ~/personal_manager && git pull
cd backend && set -a; source .env.production; set +a
mise exec -- bundle install
mise exec -- bundle exec rails db:migrate
sudo systemctl restart personal_manager        # reload the API
cd ../web && mise exec -- npm ci && mise exec -- npm run build
sudo systemctl reload nginx                     # serve the new build
```

## Re-pointing after a stop/start (the public IP changed)

*Why:* a plain EC2 public IP is **not stable** — AWS releases it when you
stop the instance and assigns a new one on the next start. Because the web
build is same-origin (no IP compiled in), only the **backend** env carries
the IP: `RAILS_ALLOWED_HOSTS` (the host check) and `CORS_ALLOWED_ORIGINS`
(boot-required). After every stop/start, run this one block on the box — it
reads the **current** public IP, rewrites both, and restarts the API. No
web rebuild is needed:

```sh
cd ~/personal_manager
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
EC2_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Current public IP: $EC2_IP"
# 169.254.169.254 is the link-local EC2 Instance Metadata Service (IMDS): a
# fixed address every instance queries to read its own info; non-routable, so
# it never leaves the box. (The TOKEN line is IMDSv2 — a short-lived token.)

# backend: rewrite the two IP-bearing values in .env.production
sed -i -E "s|^RAILS_ALLOWED_HOSTS=.*|RAILS_ALLOWED_HOSTS=${EC2_IP}|" backend/.env.production
sed -i -E "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=http://${EC2_IP}|" backend/.env.production

# web: nothing to do — the build is same-origin, so no IP is compiled in.

# restart the API so systemd re-reads .env.production
sudo systemctl restart personal_manager
echo "Re-pointed to http://${EC2_IP}"
```

Verify: `curl -s -o /dev/null -w '%{http_code}\n' http://${EC2_IP}/up`
prints `200`, and `http://${EC2_IP}` loads in the browser. Nginx needs no
reload — the `web/dist` it serves is unchanged.

Save the block as `~/repoint-ip.sh` (`chmod +x ~/repoint-ip.sh`) to re-run
it with one command after each restart.

**To avoid this entirely, attach an Elastic IP** (EC2 → Elastic IPs →
Allocate → Associate to the instance). It stays fixed across stop/start, so
you set the IP once and never re-point. Within the free tier an Elastic IP
is free *while associated with a running instance* — it bills only when
allocated but left unattached. Once it's fixed you can stop detecting it: the
script hard-codes any preset value — `EC2_IP=<your-EIP> ./deploy-level-2-nginx.sh`
skips the metadata lookup.

## Operating it

| Need | Command |
|---|---|
| Tail API + job logs | `journalctl -u personal_manager -f` (Solid Queue runs in Puma, so jobs log here too) |
| Restart API | `sudo systemctl restart personal_manager` |
| Nginx config test + reload | `sudo /usr/sbin/nginx -t && sudo systemctl reload nginx` |
| Rails console | `cd ~/personal_manager/backend && set -a; source .env.production; set +a; mise exec -- bundle exec rails console` |
| Postgres shell | `sudo -u postgres psql personal_manager_production` |
| Re-point after stop/start (IP changed) | `~/repoint-ip.sh` — see [Re-pointing after a stop/start](#re-pointing-after-a-stopstart-the-public-ip-changed) |

### Watching backend + frontend logs together

The two halves log to different places: the **API** (Puma/Rails) logs to
the systemd journal (`production.rb` logs to STDOUT), and the **frontend**
is static files whose only logs are Nginx's request logs. So "the app's
logs" means both of these:

| Half | Live log | Shows |
|---|---|---|
| Backend (API + jobs) | `journalctl -u personal_manager -f` | every API request, errors, boot failures — **and** Solid Queue jobs, which run inside Puma (`SOLID_QUEUE_IN_PUMA=1`); isolate them with `… -f \| grep -i SolidQueue` |
| Frontend (Nginx) | `sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log` | every page/asset hit + status code; permission/path errors |

To see **both in one stream**, prefix each source with a label and run
them together (Ctrl-C stops both):

```sh
sudo bash -c '
  trap "kill 0" EXIT
  journalctl -u personal_manager -f -o cat        | sed -u "s/^/[API] /" &
  tail -f /var/log/nginx/access.log /var/log/nginx/error.log | sed -u "s/^/[WEB] /" &
  wait'
```

Then load `http://<EC2_IP>` and watch the order: `[WEB]` lines for the
page/assets, then — because the API is proxied — each data call appears
**twice**: a `[WEB]` line (Nginx received it) immediately followed by an
`[API]` line (Nginx forwarded it to Puma). Reading the pattern localizes
any failure:
- `[WEB]` for `/auth` or `/api` with no matching `[API]` → Nginx isn't
  forwarding to Puma (a proxy `location` is missing/typo'd, or Puma is
  down) → `sudo nginx -t`, then `systemctl status personal_manager`.
- **No lines at all** → the request never reached the box (security group
  or host firewall — see troubleshooting).

The cleaner alternative is two panes: `tmux`, then `Ctrl-b "` to split,
`journalctl …` in one pane and the Nginx `tail` in the other.

## Troubleshooting

Every row below is an error we actually hit, in roughly the order you'd
meet it. General app failures are in
`personal_manager/docs/troubleshooting/README.md`; these are demo-specific.

| Symptom | Cause → fix |
|---|---|
| `sed: can't read deploy-level-2-nginx.md: No such file or directory` | the stamping block ran outside `docs/learning/deploy/` — or on the **server**, which has no repo clone yet → run it on your **laptop**: `cd <repo>/docs/learning/deploy`, re-run. `my-deploy.md` stays on the laptop; the server never needs it |
| `CREATE ROLE …` → `role "personal_manager" already exists` | the role exists from a prior run → don't recreate, update it: `sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<your pw>' CREATEDB;"` |
| `mise install` / `mise current` → `Config files … are not trusted` | mise won't run an untrusted `.mise.toml` → from the repo dir run `mise trust`, then retry (Step 5) |
| `mise install` → `BUILD FAILED … virtual memory exhausted` compiling Ruby | source build OOMs the 1 GB box → `mise settings ruby.compile=false` then `mise install` (Step 4) |
| `npm run build` killed (`Killed`) | swap missing → redo Step 1; `free -h` must show 2 GB |
| `source .env.production` → `<value>: command not found` (e.g. `100.31.66.24: command not found`) | a stray **space after `=`** — `KEY= value` makes bash run the value as a command → remove all spaces around `=`, bare `KEY=value` lines only, re-`source` |
| any `rails` command → `KeyError: key not found: "SMTP_ADDRESS"` (or `SMTP_USERNAME`/`SMTP_PASSWORD`) | `production.rb` fetches these with no default → add the three `SMTP_*` lines to `.env.production` (Step 6), re-`source`, retry |
| any `rails` command → `KeyError: key not found: "AR_ENCRYPTION_PRIMARY_KEY"` (or `…_DETERMINISTIC_KEY`/`…_KEY_DERIVATION_SALT`/`"PROFILE_ID_FINGERPRINT_KEY"`) | `active_record_encryption.rb` requires all four in production → append them to `.env.production` (Step 6), re-`source`, retry |
| `db:create` → `FATAL: Peer authentication failed for user "personal_manager"` | connection used the Unix socket (`peer` auth needs OS user = role) → add `PGHOST=localhost` to `.env.production` (Step 6) to force TCP password auth, re-`source`, retry |
| `db:create` → `FATAL: password authentication failed` | role password ≠ `PERSONAL_MANAGER_DATABASE_PASSWORD` → `sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<env value>' CREATEDB;"`, retry |
| `db:prepare` fails on `CREATE EXTENSION postgis` | the superuser pre-create was skipped → run it (Step 6), or as a demo-only shortcut `sudo -u postgres psql -c "ALTER ROLE personal_manager SUPERUSER;"` then rerun |
| API boots then crashes, `ActiveSupport::MessageEncryptor` error | `master.key` missing/wrong → recopy it (Step 5) |
| API redirects to `https://` and won't load | `FORCE_SSL` not `false` → fix `.env.production`, `sudo systemctl restart personal_manager` |
| `Blocked hosts` / 403 from API | `RAILS_ALLOWED_HOSTS` ≠ `<EC2_IP>` → set it, restart |
| Browser console CORS error | the web build isn't same-origin — it's still calling the API on another origin (e.g. `:3000`) instead of through the proxy → rebuild with `VITE_API_BASE_URL=` **empty** (Step 8). (For the *mobile* Expo-web client, add its origin to `CORS_ALLOWED_ORIGINS` and restart.) |
| `sudo nginx -t` → `sudo: nginx: command not found` | nginx is at `/usr/sbin/nginx` but not on sudo's PATH → call it by full path: `sudo /usr/sbin/nginx -t` |
| `ln … /etc/nginx/sites-enabled/…` → `No such file or directory` | this nginx build has no `sites-enabled/` dir → put the config in `/etc/nginx/conf.d/personal_manager.conf` (Step 8), which `nginx.conf` always includes |
| `nginx -t` → `duplicate default server` | a stock site also claims `listen 80 default_server` → `grep -rl default_server /etc/nginx/conf.d /etc/nginx/sites-enabled 2>/dev/null`, rename the stock one to `*.disabled`, re-test |
| `curl http://localhost` returns nothing and `ss` shows no `:80` listener, though `nginx -t` is OK | Nginx isn't running (a `reload` did nothing because it was never started) → `sudo systemctl enable --now nginx` |
| Nginx 403 on `/` | `www-data` can't traverse the home dir → `chmod o+x /home/ubuntu` |
| Page won't load externally though the security group allows 80; SSH works and `curl http://localhost` on the box returns `200`; the Nginx access log stays idle | a **host firewall** (`ufw`/`iptables`) on the instance is dropping inbound 80 (loopback + SSH still pass) → `sudo ufw status`; if active, `sudo ufw allow 80/tcp` (or `sudo ufw disable` for the demo) |
| Page won't load in **Chrome**, though `curl -sI http://<EC2_IP>` from the laptop returns `200` (and Safari/Firefox load it fine) | Chrome's HTTPS-First silently upgrades the address to `https://`, where nothing listens (no TLS at this level) → paste `http://<EC2_IP>` in a fresh incognito tab; if it still flips, Settings → Privacy and security → Security → turn **off** "Always use secure connections" — or just use another browser until the TLS rung |
| Browser shows `ERR_INTERNET_DISCONNECTED` (dino game) | your **laptop** is offline, not the server → reconnect Wi-Fi; confirm `https://google.com` loads, then retry |
| Browser hangs / `ERR_CONNECTION_TIMED_OUT` on `http://<EC2_IP>`; from the laptop `curl -sv http://<EC2_IP>` stalls at `Trying <EC2_IP>:80…` (never reaches `Connected to`) and the Nginx access log stays idle | the **security group denies all inbound by default**, and a freshly launched instance opens **only 22** — so AWS *silently drops* inbound 80 before it reaches the box. (A dropped packet makes the client hang until timeout; a *refused* connection would return instantly — that's how you tell a closed firewall port from a process that isn't listening.) This is the AWS-layer sibling of the host-firewall row above. → EC2 → your instance → **Security** tab → the security group → **Edit inbound rules**; add **HTTP `80`**, source `0.0.0.0/0`. That's the *only* public port — Nginx serves the page **and** proxies the API to Puma over localhost, so you do **not** open 3000. Effective in ~1 s, no restart. Verify from the laptop: `curl -sI http://<EC2_IP> \| head -1` → `HTTP/1.1 200 OK` |
| After a stop/start nothing loads | the public IP changed → run the re-point block (`~/repoint-ip.sh`), or attach an Elastic IP |
| Script verdict says `API health (:3000/up): no` though the service is `active` and the page loads | Rails was still booting when checked (`systemd` reports "active" the moment Puma starts, before Rails finishes booting — several seconds on a 1 GB box). The script now polls `/up` for ~30s; for a manual check, wait and re-run `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/up` → `200`. A *persistent* failure is real → `journalctl -u personal_manager -n 60 --no-pager`. |

## Why this isn't production

This demo deliberately trades safety and robustness for speed. Each item is
what `personal_manager/docs/deployment/README.md` and
[aws/aws-deployment-template.md](../aws/aws-deployment-template.md) do properly — read
them to learn the real production setup:

- **No TLS (no HTTPS).** HTTP only — login credentials and session cookies
  cross the wire in clear. Fine for a throwaway demo IP, never for real
  data. Production terminates TLS (Let's Encrypt / a load balancer) and
  leaves `FORCE_SSL` on its `true` default.
- **Database on the app box.** Same host, password in a `600` file, no
  backups, no point-in-time recovery. Production uses managed Postgres
  (RDS) with automated backups.
- **Single worker, no monitoring.** `WEB_CONCURRENCY=1`, no error tracking
  wiring, no uptime check, no log shipping.
- **Manual deploys.** `git pull` + rebuild by hand, with downtime.
  Production uses Kamal for zero-downtime releases (see
  `personal_manager/deploy/aws/deploy-level-5-docker.md`).
- **Plain public IP.** Changes on every stop/start. Production uses a
  stable Elastic IP or a DNS name behind a load balancer.