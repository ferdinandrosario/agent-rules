# Level 1 — Single instance, plain Rails in production (Puma only)

> **EC2 learning ladder · Level 1 of 5** — [the ladder](../aws/aws-ec2-ladder.md).
> This is the simplest rung: one box, one process, no Nginx.
> Next: [Level 2 — add Nginx](deploy-level-2-nginx.md).
>
> "Production mode" here means `RAILS_ENV=production` running on a real
> server — not yet production-*grade* (still plain HTTP, single box, no
> backups). The ladder hardens it level by level.

> **In plain words:** your first server, minimum moving parts — one rented box
> where the Rails process serves both the API and the web page over plain HTTP.
> A throwaway demo for learning EC2, SSH, and systemd; expect to delete the box
> afterwards, not to run users on it.

The same throwaway demo as [deploy-level-2-nginx.md](deploy-level-2-nginx.md),
but with **one less moving part: no Nginx.** Puma (the Rails server) serves
*both* the API and the compiled React files, on a single port. Fewer pieces
to install, configure, and debug — at the cost of the things a real web
server gives you (see [Why no Nginx is a demo-only choice](#why-no-nginx-is-a-demo-only-choice)).

Pick this variant if you want the simplest possible single-process setup
and a clean URL with no port number. Pick the
[Nginx variant](deploy-level-2-nginx.md) if you want the more
production-shaped layout (a dedicated web server in front of the app).

This guide assumes **no prior DevOps experience** — every step says *what*
and *why*.

> **This is a throwaway demo, not production.** Plain HTTP (no TLS),
> database on the same box, secrets in a file, and Puma serving static
> files (fine for a demo, not for load). For the real thing see
> `personal_manager/docs/deployment/README.md`. The
> "[Why no Nginx is a demo-only choice](#why-no-nginx-is-a-demo-only-choice)"
> and "[Why this isn't production](#why-this-isnt-production)" sections
> spell out the trade-offs.

## What changed vs. the Nginx variant

| | Level 2 (Nginx) | Level 1 (this guide) |
|---|---|---|
| Serves the React files | Nginx, on port 80 | **Puma**, on port 80 |
| Serves the API | Puma, on port 3000 | **Puma**, on port 80 (same process) |
| Public ports | 80 **and** 3000 | **80 only** |
| CORS needed? | Yes (page and API are different origins) | **No** (same origin) |
| Extra package | `nginx` | none |
| URL | `http://<EC2_IP>` for page, `:3000` for API | `http://<EC2_IP>` for everything |

Because Puma is a non-root service, binding to port 80 needs one extra
systemd line (`AmbientCapabilities=CAP_NET_BIND_SERVICE`) — explained in
Step 7.

## The pieces, in plain words

| Piece | What it is | Why it's here |
|---|---|---|
| **EC2 instance** | A Linux computer you rent from AWS. | The server that hosts everything. Free tier = a small one (1 GB RAM). |
| **Security group** | AWS's network firewall (web console). | Decides which ports the internet may reach. Here: 22 (SSH) and 80 (the app). |
| **Swap** | Disk used as overflow RAM. | 1 GB RAM can't compile the app; swap stops the build being killed. |
| **PostgreSQL + PostGIS** | The database server (+ location-types add-on). | Stores the app's data. |
| **Ruby / Rails** | Backend language + framework. | The API. |
| **Puma** | The program that runs Rails and listens on a port. | Here it serves **both** the API **and** the static React files — that's the whole point of this variant. |
| **Node / Vite** | JavaScript toolchain. | Compiles React into static files once. Not needed afterwards. |
| **systemd** | Linux's service manager. | Keeps Puma running: starts on boot, restarts on crash. |
| **mise** | A version manager. | Installs the exact Ruby/Node the project pins (Ubuntu's Ruby is too old). |
| **`.env.production`** | A file of `KEY=value` settings. | Config + secrets the app reads at startup. |

There is **no Nginx** in this list — that's the difference.

## How a page load works here (one process, one port)

```
  Your browser
      │  http://<EC2_IP>/  and  http://<EC2_IP>/up, /auth/*, /api/v1/*   (all port 80)
      ▼
   ┌───────────────────── EC2 instance ─────────────────────┐
   │  Puma → Rails (port 80)                                 │
   │    • a request that matches a file in public/  → that   │
   │      file (index.html, the compiled JS/CSS)             │
   │    • anything else  → the Rails router (the API)        │
   │                          │                              │
   │                          ▼                              │
   │              PostgreSQL + PostGIS (port 5432)           │
   │              (4 DBs: primary + cache/queue/cable)       │
   └─────────────────────────────────────────────────────────┘
```

What a beginner should take from this:

- **One public port (80), one process.** Puma answers everything. The page
  and the API share the same origin (`http://<EC2_IP>`), so there's no CORS to
  configure and no second port to open.
- **How Puma "serves the frontend":** Rails has a built-in static-file
  middleware (on by default in this app). For each request it first checks
  `backend/public/` for a matching file; if found it returns it, otherwise
  the request goes to the Rails router (the API). So we just **copy the
  compiled React files into `backend/public/`**.
- **The API URL is still baked into the build.** `VITE_API_BASE_URL` is
  compiled into the JS at build time — here it's `http://<EC2_IP>` (no port,
  same origin). Change the IP → rebuild.
- **One caveat (SPA deep links):** Rails is API-only and has no catch-all
  route, so a *hard refresh* on a client-side route like `/dashboard`
  returns 404 (the server has no such route and no `index.html` fallback).
  The app works fine when you start at `/` and navigate by clicking. The
  Nginx variant avoids this with its `try_files … /index.html` fallback.
  For a demo this is an acceptable limitation.

## Versions (match the repo — do not substitute)

| Tool | Version | Source of truth |
|---|---|---|
| Ubuntu | 26.04 LTS | the AMI you pick |
| Ruby | 4.0.9 | `.ruby-version`, `.mise.toml` |
| Node | 26.13.0 | `.mise.toml` |
| Rails | 8.1.3 | `backend/Gemfile` |
| PostgreSQL | 18 (26.04 default) | apt default cluster |
| PostGIS | 3.x | `postgis` apt package |

Ubuntu 26.04's apt Ruby is 3.3.x — too old for the `ruby "4.0.9"` pin, so
we install the exact version with `mise` (Step 4).

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
  deploy-level-1-plain-rails.md > my-deploy.md
grep -nE '<EC2_IP>|<DB_PASSWORD>' my-deploy.md || echo 'all tokens filled'
# expect: all tokens filled
```

> **`<EC2_IP>` changes on stop/start** unless you attach an Elastic IP. When
> it changes, edit the `EC2_IP=` line, re-run the block, and reapply the env
> file — see [Re-pointing after a stop/start](#re-pointing-after-a-stopstart-the-public-ip-changed).

## Run it as a script, or by hand

Steps 1–8 below are also packaged as one runnable script,
[`docs/learning/deploy/scripts/deploy-level-1-plain-rails.sh`](scripts/deploy-level-1-plain-rails.sh) — the
*scripted form* of this guide. **This doc stays the source of truth**
(read it for the full *why*); the script's comments are the one-line
versions. Step 0 (launch the instance) stays manual — the console part
can't be scripted from inside the box.

The repo is **private**, so a `curl` from `raw.githubusercontent.com`
returns 404 — copy the script up from your laptop's clone instead:

```shell
# on your laptop, from the repo root, after Step 0:
scp -i ~/Downloads/Keys/28_may_2026.pem docs/learning/deploy/scripts/deploy-level-1-plain-rails.sh ubuntu@<EC2_IP>:~/
# then on the box:
ssh -i ~/Downloads/Keys/28_may_2026.pem ubuntu@<EC2_IP>
./deploy-level-1-plain-rails.sh
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

*Why:* this creates the server and decides what the internet can reach. The
**security group** is AWS's firewall — only the ports you list are open.

- **EC2 → Launch instance.** AMI: **Ubuntu Server 26.04 LTS (64-bit
  x86)**. Type: **t3.micro** (or t2.micro — 1 GB RAM, free-tier).
  Create/download a key pair and save it as `~/Downloads/Keys/28_may_2026.pem`.
- **Storage:** bump the root volume to **20 GB**.
- **Security group — inbound rules** (only two, since the API is on 80 too):

  | Port | Source | Purpose |
  |---|---|---|
  | 22 | **My IP** | SSH login, restricted to you |
  | 80 | 0.0.0.0/0 | the whole app (page **and** API) — Puma serves both here |

  > Note: unlike the Nginx variant, you do **not** open port 3000 — Puma
  > listens on 80 instead.

- Launch, then copy the **Public IPv4 address** — that's your `<EC2_IP>` from
  the values table above.

> **Two firewalls, not one.** The security group is the AWS layer. Ubuntu
> may *also* run a host firewall (`ufw`). If active, it can drop inbound 80
> even when the security group allows it (SSH still works, `curl
> http://localhost` on the box works, but external requests never arrive).
> See the host-firewall row in troubleshooting.

```sh
chmod 400 ~/Downloads/Keys/28_may_2026.pem    # SSH refuses a key others can read
ssh -i ~/Downloads/Keys/28_may_2026.pem ubuntu@<EC2_IP>
# expect: "Welcome to Ubuntu 26.04 LTS ..." and a prompt ubuntu@ip-...:~$
```

Everything from Step 1 on runs **on the box**, unless a step says "on your
laptop".

## Step 1 — Swap (mandatory on 1 GB RAM)

*Why:* compiling gems and building the React app needs more memory than
1 GB. Swap is disk used as overflow RAM so the build isn't killed.

```sh
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab   # persist across reboots
free -h
# expect a non-zero Swap line, e.g.:  Swap:  2.0Gi  0B  2.0Gi
```

## Step 2 — System packages

*Why:* bring the OS current, then install the database and everything
needed to compile the app. **No Nginx** in this variant.

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
  git curl \
  build-essential libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev \
  libpq-dev libvips
psql --version    # expect: psql (PostgreSQL) 18.x
```

Groups: `postgresql … postgis` (database + location types); `git curl`
(clone the code + downloads); `build-essential libssl-dev … libgmp-dev`
(C toolchain for native gems); `libpq-dev` (the `pg` gem); `libvips`
(image processing for Active Storage).

## Step 3 — PostgreSQL role

*Why:* a PostgreSQL **role** is a database user. The app logs in as
`personal_manager` (name hard-coded in `database.yml`). `CREATEDB` lets
Rails create its databases; not a superuser (safer).

```sh
sudo -u postgres psql -c "CREATE ROLE personal_manager LOGIN PASSWORD '<DB_PASSWORD>' CREATEDB;"
# expect: CREATE ROLE
```

Remember the password — it goes in the env file (Step 6).

> **Re-running?** If you see `role "personal_manager" already exists`, don't
> recreate — update it instead:
> ```sh
> sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<DB_PASSWORD>' CREATEDB;"
> # expect: ALTER ROLE
> ```

## Step 4 — Install mise (Ruby 4.0.9 + Node 26.13.0)

*Why:* the app pins exact Ruby/Node versions; `mise` installs them.

```sh
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
mise --version                    # expect: 20xx.x.x
mise settings ruby.compile=false  # use a prebuilt Ruby binary
```

**Use the precompiled Ruby binary.** Compiling Ruby 4.0.9 on a 1 GB box
runs out of memory and fails (`BUILD FAILED … virtual memory exhausted`)
even with swap. `ruby.compile=false` downloads a ready-built binary.

## Step 5 — Get the code

*Why:* clone the repo, install the runtimes, and copy up the one secret git
can't carry.

The repo is private — authenticate with a per-host SSH **deploy key**
(generated on the server, registered read-only with the repo):

```sh
ssh-keygen -t ed25519 -C "ec2-demo" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# copy the printed line → add at:
#   https://github.com/ferdinandrosario/personal_manager/settings/keys
#   "Add deploy key", read-only is enough.
git clone git@github.com:ferdinandrosario/personal_manager.git ~/personal_manager
# expect: Cloning into '/home/ubuntu/personal_manager'... done.
```

Install the pinned runtimes. **mise won't use a project's `.mise.toml`
until you trust it** (a safety feature):

```sh
cd ~/personal_manager
mise trust        # without this, mise install errors "not trusted"
mise install      # Ruby 4.0.9 (prebuilt) + Node 26.13.0
mise current      # expect: ruby 4.0.9   node 26.13.0
```

### Copy the master key (run on your laptop, not the server)

*Why:* `backend/config/master.key` decrypts the app's secrets and is
gitignored, so it's not in the clone — without it the API won't boot.

```sh
# on your laptop, from the personal_manager repo root:
scp -i ~/Downloads/Keys/28_may_2026.pem backend/config/master.key \
  ubuntu@<EC2_IP>:/home/ubuntu/personal_manager/backend/config/master.key
# expect: master.key  100%   ...
```

## Step 6 — Backend: env file, gems, database, seeds

*Why:* the app reads config and secrets from environment variables. We put
them in `.env.production`. **Note the differences from the Nginx variant:**
`PORT=80` (Puma will serve on 80), and the IP-based settings use `http://<EC2_IP>`
with **no `:3000`** because everything is one origin now.

```sh
cd ~/personal_manager/backend
cat > .env.production <<'ENV'
RAILS_ENV=production
PERSONAL_MANAGER_DATABASE_PASSWORD=<DB_PASSWORD>
PGHOST=localhost
RAILS_ALLOWED_HOSTS=<EC2_IP>
CORS_ALLOWED_ORIGINS=http://<EC2_IP>
FORCE_SSL=false
PORT=80
WEB_CONCURRENCY=1
SOLID_QUEUE_IN_PUMA=true
SMTP_ADDRESS=localhost
SMTP_USERNAME=demo
SMTP_PASSWORD=demo
ENV
chmod 600 .env.production
```

> **No spaces around `=`.** `KEY=value`, never `KEY= value` — a stray space
> makes the shell run the value as a command when you `source` the file.

Append three **Active Record Encryption** keys (required in production —
they encrypt sensitive columns). Unquoted heredoc (`<<ENV`) so `$(openssl …)`
runs:

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

**Generate these once and keep them fixed** — changing them makes
already-encrypted data unreadable.

> **Real-production box (real user data)?** On re-run the script
> auto-generates any *missing* key — fine for a demo, but the value then
> lives only in this file, so a lost box means unreadable data. Instead
> generate the four keys yourself, **save them in your password manager**,
> and paste them into `.env.production` *before* re-running (a key that's
> already present is left untouched). Full procedure — generation, off-box
> backup, and rebuild rules — in
> `personal_manager/docs/deployment/environment-variables.md`.

| Var | Value | Why / which file reads it |
|---|---|---|
| `RAILS_ENV` | `production` | runs in production mode |
| `PERSONAL_MANAGER_DATABASE_PASSWORD` | the Step 3 password | `database.yml` — DB login |
| `PGHOST` | `localhost` | forces TCP (password auth). Without it the driver uses a Unix socket whose `peer` auth fails. |
| `RAILS_ALLOWED_HOSTS` | `<EC2_IP>` | `production.rb` rejects other `Host` headers |
| `CORS_ALLOWED_ORIGINS` | `http://<EC2_IP>` | `cors.rb` — harmless here (same-origin needs no CORS), kept for safety |
| `FORCE_SSL` | `false` | defaults to `true` (forces HTTPS); leaving it on breaks the HTTP demo |
| `PORT` | `80` | **Puma serves everything on 80** (the key difference from Level 2) |
| `WEB_CONCURRENCY` | `1` | one Puma worker — all a 1 GB box can spare |
| `SOLID_QUEUE_IN_PUMA` | `true` | runs the Solid Queue worker **inside** Puma (`config/puma.rb`). `production.rb` sets `queue_adapter = :solid_queue`; this one-box setup starts no separate worker, so without it the friend-request mail + notification fan-out jobs would enqueue and never run. |
| `SMTP_*` | `localhost`/`demo`/`demo` | required to **boot**; placeholders — mail won't send |
| `AR_ENCRYPTION_*` | random hex | encrypt sensitive columns |
| `PROFILE_ID_FINGERPRINT_KEY` | random hex (`openssl rand -hex 32`) | keys the HMAC blind index that makes Profile government IDs unique; `active_record_encryption.rb` requires it in production (no fallback). Set once — rotating orphans existing fingerprints. |
| `DEVISE_JWT_SECRET_KEY` | random hex (`openssl rand -hex 64`) | signs JWTs; `devise.rb` requires it in production (no `secret_key_base` fallback) |

`RAILS_MASTER_KEY` is not here — the `master.key` *file* (Step 5) supplies it.

> **Email won't actually send.** `SMTP_*` are placeholders so the app boots.
> Log in as a **seeded user** rather than registering. Real mail → set real
> SMTP creds (see `personal_manager/docs/feature/auth.md`).

Install gems and create the database (PostGIS enabled by the superuser
*between* `db:create` and `db:prepare` so the app role stays non-superuser):

```sh
set -a; source .env.production; set +a
mise exec -- bundle install                # expect: Bundle complete!
mise exec -- bundle exec rails db:create   # create the 4 databases
sudo -u postgres psql -d personal_manager_production -c "CREATE EXTENSION IF NOT EXISTS postgis;"
# expect: CREATE EXTENSION
mise exec -- bundle exec rails db:prepare  # migrate + load cache/queue/cable schemas
ALLOW_PRODUCTION_SEED=true mise exec -- bundle exec rails db:seed     # demo data
# expect: seed output ending without errors
```

## Step 7 — Build the web app and put it where Puma serves it

*Why:* compile React into static files, then drop them into
`backend/public/`. Rails' static-file middleware (on by default) will serve
anything found there; everything else goes to the API. One process serves
both.

Build the frontend. `VITE_API_BASE_URL` is baked in at build time — here
it's `http://<EC2_IP>` (no port, same origin as the page):

```sh
cd ~/personal_manager/web
echo "VITE_API_BASE_URL=http://<EC2_IP>" > .env   # same origin → no port
mise exec -- npm ci         # expect: added N packages
mise exec -- npm run build  # compile → web/dist/  — expect: ✓ built in ...
```

Copy the compiled files into the backend's `public/` directory (clearing
any previous build first so old hashed assets don't pile up):

```sh
rm -rf ~/personal_manager/backend/public/assets ~/personal_manager/backend/public/index.html
cp -r ~/personal_manager/web/dist/. ~/personal_manager/backend/public/
ls ~/personal_manager/backend/public/    # expect: index.html  assets/  ...  robots.txt
```

## Step 8 — Run Puma (API + frontend) as a service on port 80

*Why:* **systemd** runs Puma in the background, restarts it on crash, and
starts it on boot. The new line vs. the Level 2 unit is
`AmbientCapabilities=CAP_NET_BIND_SERVICE`: ports below 1024 (like 80) are
privileged, and our service runs as the non-root `ubuntu` user — this
capability is what lets it bind port 80 without running as root.

```sh
sudo tee /etc/systemd/system/personal_manager.service >/dev/null <<'UNIT'
[Unit]
Description=personal_manager (Rails API + web, Puma on :80)
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/personal_manager/backend
EnvironmentFile=/home/ubuntu/personal_manager/backend/.env.production
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/home/ubuntu/.local/bin/mise exec -- bundle exec rails server -b 0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload                   # read the new unit file
sudo systemctl enable --now personal_manager   # start now + on every boot
sudo systemctl status personal_manager --no-pager
# expect: Active: active (running)

curl -sI -H "Host: <EC2_IP>" http://localhost | head -1   # the page (served by Puma)
# expect: HTTP/1.1 200 OK
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/up   # the API
# expect: 200
```

> **Why the `-H "Host: …"`:** the app 403s any request whose `Host`
> header isn't on `RAILS_ALLOWED_HOSTS` — and that list holds only
> `<EC2_IP>`, so a plain `curl http://localhost` is *correctly* blocked.
> Only `/up` is exempt from the check. A 403 here without the header
> means the protection works, not that the deploy failed.

If `status` isn't `active (running)`, read why with
`journalctl -u personal_manager -n 60 --no-pager`. A `Permission denied` on
bind means the capability line is missing or mistyped — see troubleshooting.

## Step 9 — Verify the demo

From your **laptop** (these go through the security group):

```sh
curl -sI http://<EC2_IP> | head -1                              # page
# expect: HTTP/1.1 200 OK
curl -s -o /dev/null -w '%{http_code}\n' http://<EC2_IP>/up     # API
# expect: 200
```

- Open **`http://<EC2_IP>`** in a browser (note: `http://`, not `https://`)
  → the React app loads and its health panel goes green.
- Log in with a seeded user (see `personal_manager/docs/backend/seed-data.md`). Don't
  register — email won't send (Step 6).

If nothing loads, work the troubleshooting table from the network up: is
port 80 open in the security group? is `ufw` dropping it? does `curl
http://localhost` work *on the box*?

## Viewing logs

One process, one log. Puma serves the page **and** the API, and Solid Queue
runs inside Puma (`SOLID_QUEUE_IN_PUMA=1`), so page hits, API requests, and
background jobs all stream to the same systemd journal:

```sh
journalctl -u personal_manager -f                # live, follow (Ctrl-C to stop)
journalctl -u personal_manager -n 60 --no-pager  # last 60 lines, no pager
journalctl -u personal_manager -p err -f         # errors only
journalctl -u personal_manager -f | grep -i SolidQueue   # just background jobs
```

```
Jun 22 09:14:02 ip-10-0-0-1 bundle[1234]: I, [...]  INFO -- : Started GET "/up"
Jun 22 09:14:02 ip-10-0-0-1 bundle[1234]: I, [...]  INFO -- : Completed 200 OK in 3ms
```

There is no separate Nginx or frontend-runtime log: the compiled React app runs
in the **browser** (its `console.*`/JS errors stay client-side), and this level
has no Nginx. (Rails logs reach the journal because `RAILS_LOG_TO_STDOUT=1`.)

## Redeploying after a code change

```sh
cd ~/personal_manager && git pull
cd backend && set -a; source .env.production; set +a
mise exec -- bundle install
mise exec -- bundle exec rails db:migrate
cd ../web && mise exec -- npm ci && mise exec -- npm run build
rm -rf ~/personal_manager/backend/public/assets ~/personal_manager/backend/public/index.html
cp -r ~/personal_manager/web/dist/. ~/personal_manager/backend/public/
sudo systemctl restart personal_manager        # reloads API + serves the new files
```

## Re-pointing after a stop/start (the public IP changed)

*Why:* a plain EC2 public IP changes on every stop/start. It lives in
`RAILS_ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and the compiled-in
`VITE_API_BASE_URL`. After every restart, run this on the box — it reads the
current IP, rewrites all three, rebuilds the web, copies it into `public/`,
and restarts Puma:

```sh
cd ~/personal_manager
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
EC2_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Current public IP: $EC2_IP"
# 169.254.169.254 is the link-local EC2 Instance Metadata Service (IMDS): a
# fixed address every instance queries to read its own info; non-routable, so
# it never leaves the box. (The TOKEN line is IMDSv2 — a short-lived token.)

sed -i -E "s|^RAILS_ALLOWED_HOSTS=.*|RAILS_ALLOWED_HOSTS=${EC2_IP}|" backend/.env.production
sed -i -E "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=http://${EC2_IP}|" backend/.env.production

echo "VITE_API_BASE_URL=http://${EC2_IP}" > web/.env       # no port — same origin
( cd web && mise exec -- npm run build )
rm -rf backend/public/assets backend/public/index.html
cp -r web/dist/. backend/public/

sudo systemctl restart personal_manager
echo "Re-pointed to http://${EC2_IP}"
```

Verify: `curl -sI http://${EC2_IP} | head -1` → `HTTP/1.1 200 OK`. Save the
block as `~/repoint-ip.sh` (`chmod +x`) to re-run with one command.

**To avoid this entirely, attach an Elastic IP** (EC2 → Elastic IPs →
Allocate → Associate). It stays fixed across stop/start. Free while
associated with a running instance. Once it's fixed you can stop detecting it:
the script hard-codes any preset value — `EC2_IP=<your-EIP> ./deploy-level-1-plain-rails.sh`
skips the metadata lookup.

## Operating it

| Need | Command |
|---|---|
| Tail all logs (page + API are one process now) | `journalctl -u personal_manager -f` |
| Restart the app | `sudo systemctl restart personal_manager` |
| Rails console | `cd ~/personal_manager/backend && set -a; source .env.production; set +a; mise exec -- bundle exec rails console` |
| Postgres shell | `sudo -u postgres psql personal_manager_production` |
| Re-point after stop/start | `~/repoint-ip.sh` — see [Re-pointing after a stop/start](#re-pointing-after-a-stopstart-the-public-ip-changed) |

**Watching logs is simpler than the Nginx variant:** because Puma serves
the page *and* the API, **everything is in one log** — the systemd journal.
There's no separate web-server log to merge:

```sh
journalctl -u personal_manager -f
```

Load `http://<EC2_IP>` and watch: you'll see requests for the page/assets
*and* the API calls (`/up`, `/auth/*`, `/api/v1/*`) in this single stream.
No lines at all when loading means the request never reached the box
(security group or host firewall — see troubleshooting).

## Troubleshooting

General app failures are in `personal_manager/docs/troubleshooting/README.md`;
these are demo-specific (roughly in the order you'd meet them).

| Symptom | Cause → fix |
|---|---|
| `sed: can't read deploy-level-1-plain-rails.md: No such file or directory` | the stamping block ran outside `docs/learning/deploy/` — or on the **server**, which has no repo clone yet → run it on your **laptop**: `cd <repo>/docs/learning/deploy`, re-run. `my-deploy.md` stays on the laptop; the server never needs it |
| `CREATE ROLE …` → `role "personal_manager" already exists` | exists from a prior run → update it: `sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<pw>' CREATEDB;"` |
| `mise install` / `mise current` → `Config files … are not trusted` | run `mise trust` in the repo dir, then retry (Step 5) |
| `mise install` → `BUILD FAILED … virtual memory exhausted` | source build OOMs the 1 GB box → `mise settings ruby.compile=false` then `mise install` (Step 4) |
| `npm run build` killed (`Killed`) | swap missing → redo Step 1; `free -h` must show 2 GB |
| `source .env.production` → `<value>: command not found` | stray **space after `=`** → bare `KEY=value` lines only, re-`source` |
| `KeyError: key not found: "SMTP_ADDRESS"` (or `SMTP_USERNAME`/`SMTP_PASSWORD`) | add the three `SMTP_*` lines to `.env.production` (Step 6), re-`source`, retry |
| `KeyError: key not found: "AR_ENCRYPTION_PRIMARY_KEY"` (or the other two) | append the three `AR_ENCRYPTION_*` keys (Step 6), re-`source`, retry |
| `db:create` → `FATAL: Peer authentication failed for user "personal_manager"` | socket `peer` auth → add `PGHOST=localhost` (Step 6), re-`source`, retry |
| `db:create` → `FATAL: password authentication failed` | role password ≠ env → `sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '<env value>' CREATEDB;"` |
| `db:prepare` fails on `CREATE EXTENSION postgis` | superuser pre-create skipped → run it (Step 6), or `sudo -u postgres psql -c "ALTER ROLE personal_manager SUPERUSER;"` then rerun (demo-only) |
| API boots then crashes, `ActiveSupport::MessageEncryptor` error | `master.key` missing/wrong → recopy it (Step 5) |
| Service fails to start; journal shows `Permission denied` / `EACCES` binding port 80 | the service runs as non-root and lacks the privileged-port capability → ensure the unit has `AmbientCapabilities=CAP_NET_BIND_SERVICE` (Step 8), `sudo systemctl daemon-reload && sudo systemctl restart personal_manager`. *Fallback:* set `PORT=3000` in `.env.production`, open port 3000 in the security group, and use `http://<EC2_IP>:3000`. |
| Page loads but assets 404 / blank page | the compiled files aren't in `backend/public/` → re-run the build + copy (Step 7); confirm `ls backend/public/` shows `index.html` and `assets/` |
| Hard refresh on a sub-path (e.g. `/dashboard`) → 404 | expected: API-only Rails has no SPA fallback → start at `/` and navigate by clicking, or use Level 2 (Nginx), which has `try_files … /index.html` |
| API redirects to `https://` and won't load | `FORCE_SSL` not `false` → fix `.env.production`, restart |
| `curl http://localhost` → 403, but the service is active and `/up` is 200 | **expected** — `Host: localhost` isn't on `RAILS_ALLOWED_HOSTS` (only `<EC2_IP>` is); the block is the protection working → test with `curl -H "Host: <EC2_IP>" http://localhost`, or browse `http://<EC2_IP>` from the laptop |
| `Blocked hosts` / 403 from the app at `http://<EC2_IP>` | `RAILS_ALLOWED_HOSTS` ≠ the current `<EC2_IP>` (IP changed on stop/start?) → re-point it (`~/repoint-ip.sh` or re-run the script), restart |
| Page won't load externally though the SG allows 80; SSH works and `curl http://localhost` on the box returns `200`; nothing in the journal | a **host firewall** (`ufw`) is dropping inbound 80 → `sudo ufw status`; if active, `sudo ufw allow 80/tcp` (or `sudo ufw disable` for the demo) |
| Page won't load in **Chrome**, though `curl -sI http://<EC2_IP>` from the laptop returns `200` (and Safari/Firefox load it fine) | Chrome's HTTPS-First silently upgrades the address to `https://`, where nothing listens (no TLS at this level) → paste `http://<EC2_IP>` in a fresh incognito tab; if it still flips, Settings → Privacy and security → Security → turn **off** "Always use secure connections" — or just use another browser until the TLS rung |
| Browser shows `ERR_INTERNET_DISCONNECTED` (dino game) | your **laptop** is offline → reconnect Wi-Fi; confirm `https://google.com` loads |
| Browser hangs / `ERR_CONNECTION_TIMED_OUT` | port 80 not reachable → open inbound `80` (`0.0.0.0/0`) in the security group; if open, check the host-firewall row above |
| After a stop/start nothing loads | the public IP changed → run `~/repoint-ip.sh`, or attach an Elastic IP |
| Verdict says the API health check failed though the service is `active` and the page loads | Rails was still booting when checked (`systemd` reports "active" the moment Puma starts, before Rails finishes booting — several seconds on a 1 GB box). The script now polls for ~30s; for a manual check, wait and re-run `curl -s -o /dev/null -w '%{http_code}\n' http://localhost/up` → `200`. A *persistent* failure is real → `journalctl -u personal_manager -n 60 --no-pager`. |

## Why no Nginx is a demo-only choice

Dropping Nginx is what makes this variant simpler, but it's also why it's a
*demo* shortcut. A real deployment keeps a dedicated web server (or load
balancer) in front of the app because it provides things Puma serving files
does not:

- **Static files tie up app threads.** Every CSS/JS/image request occupies a
  Puma thread that could be answering API calls. Nginx serves files far more
  efficiently and frees the app for actual work.
- **No SPA fallback.** Nginx's `try_files … /index.html` makes deep-link
  refreshes work; the API-only Rails app here 404s them.
- **TLS, compression, caching, rate-limiting** normally live in the web
  server / load balancer in front — not in the app.

For a click-through demo none of this matters; for production, use the
[Nginx variant](deploy-level-2-nginx.md) as the starting point and then
`personal_manager/docs/deployment/README.md`.

## Why this isn't production

Same trade-offs as the [Nginx variant](deploy-level-2-nginx.md#why-this-isnt-production):
no TLS (plain HTTP), database on the app box with its password in a file and
no backups, a single Puma worker with no monitoring, manual deploys with
downtime, and a plain public IP that changes on stop/start. Read
`personal_manager/docs/deployment/README.md` and
[aws/aws-deployment-template.md](../aws/aws-deployment-template.md) for the real
production setup.
