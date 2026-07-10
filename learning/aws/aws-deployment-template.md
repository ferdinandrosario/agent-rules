# AWS deployment template — deploy *any* app to a single EC2 host

A reusable, app-agnostic version of `personal_manager/docs/deployment/README.md`.
That file is the concrete `personal_manager` instance of this recipe; this one
is the **template** — fill in the variables in [§0](#0-fill-these-in-first) and the same commands stand up
a production-grade box for a different app (Rails, Node, Python, Go, …).

**Who this is for:** an engineer who is *not* a DevOps specialist. Every command
says what it does and why it's safe. If a line isn't explained, that's a doc bug
— file it.

**What you get:** one Ubuntu EC2 host running your app behind Nginx with HTTPS,
a local PostgreSQL with nightly backups, the app supervised by systemd
(auto-restart, boot-start, sandboxed), a host firewall + brute-force banning,
and capped logs. No Docker, no Kubernetes — plain `apt` + `systemd`. Cheap
enough to sit in the AWS free tier, hardened enough for real users.

> **Why single-host?** It's the simplest thing that is genuinely production-grade
> for a small app: one server you fully understand, no orchestration layer to
> learn. Scale *up* (bigger instance) first; reach for load balancers / managed
> DB / containers only when one box demonstrably isn't enough.

---

## The shape (read this once)

```
                    DNS A-record → Elastic IP
                              │
  Browser / mobile  ──HTTPS──▶│  EC2 host (Ubuntu LTS)
                              │   ├─ Nginx  :443  (TLS, security headers, static files)
                              │   │     └─ proxies app routes over a Unix socket ──┐
                              │   ├─ Your app (systemd service, unprivileged user) ◀┘
                              │   ├─ PostgreSQL  (localhost only) + nightly pg_dump
                              │   ├─ UFW firewall (only 22/80/443 open) + fail2ban
                              │   └─ systemd supervises every process
```

Key ideas that make it secure and reliable:

- **Nothing the app runs is root.** The app, the DB client, the workers all run
  as an unprivileged `deploy` user. A compromised app process can't own the box.
- **The app never listens on a public port.** Nginx is the only thing the
  internet reaches; it talks to the app over a local Unix socket.
- **Two firewalls.** The AWS Security Group filters at the network edge; UFW +
  fail2ban enforce on the host. One misconfig doesn't expose you.
- **systemd owns lifecycle.** Crash → restart. Reboot → start. No `screen`/`tmux`.
- **Releases are atomic.** A symlink (`current`) flips between release dirs, so a
  deploy is instant and rollback is just re-pointing the symlink.

---

## Who runs what — the two users

The whole guide uses **two Linux users**. You **create one**; the other ships
with the AMI. Getting this split right is what keeps the app off root.

| User | Created? | Privilege | Runs / owns |
|---|---|---|---|
| `ubuntu` | No — Ubuntu AMI default | Passwordless `sudo` (full root) | Every **one-time root setup** step (the `sudo` lines): `apt` installs, PostgreSQL, the systemd unit + Nginx site, UFW/fail2ban ([§4](#4-base-system-updates-swap-packages-auto-patching), [§6](#6-harden-ssh--firewall--fail2ban), [§8](#8-database-postgresql--nightly-backups), [§10](#10-nginx-reverse-proxy--security-headers--tls), [§11](#11-systemd-service-unit-supervise-the-app)). Never owns or runs the app. |
| `$APP_USER` (e.g. `deploy`) | **Yes** — [§5](#5-create-the-deploy-user-least-privilege) | No general sudo; a **NOPASSWD allowlist of only its service-control commands** | The **app account**: owns `$APP_ROOT`, runs the app + workers, receives the deployed code, edits `shared/.env`. CI/CD and day-2 SSH log in as this user. |

**So: two users total, one of which you create** (`$APP_USER`).

| As which user do I … | User | Why |
|---|---|---|
| Install **system / `apt` packages** (build tools, PostgreSQL, Nginx, certbot) | `ubuntu` + `sudo` | They mutate the OS; need real root. [§4](#4-base-system-updates-swap-packages-auto-patching), [§8](#8-database-postgresql--nightly-backups), [§10](#10-nginx-reverse-proxy--security-headers--tls). |
| Install the **language runtime** + **app dependencies** | `$APP_USER` | Per-user under `/home/$APP_USER` (mise/nvm/pyenv); no root. Installing them here is what lets the systemd unit — which runs as `$APP_USER` — find the runtime on its PATH ([§11](#11-systemd-service-unit-supervise-the-app)). [§7](#7-language-runtime). |
| **scp / rsync the source code** | `$APP_USER` | It owns `$APP_ROOT`, so the transfer needs no `sudo` and files land owned by the user that runs them. [§13](#13-deploy-your-code-first-release). |
| **CI/CD** (the pipeline SSHes in to deploy) | `$APP_USER` | The workflow authenticates as `$APP_USER`, rsyncs the build, flips `current`, runs the allowlisted restart — no password, no root. |

> **Rule of thumb:** changes to the *machine* (apt, system services) are
> `ubuntu` + `sudo`; *the app* (its runtime, code, restarts) is `$APP_USER`.
> The narrow sudo allowlist ([§5](#5-create-the-deploy-user-least-privilege))
> is the single bridge — `$APP_USER` restarts its own services without being
> a general admin.

---

## 0. Fill these in first

Set these **once** in your SSH session; every later command references them, so
copy-paste just works. Re-export them if you open a new shell.

| Variable | Meaning | Example |
|---|---|---|
| `APP` | Short app name — used for the dir, DB, systemd unit, Nginx site | `myapp` |
| `APP_USER` | Unprivileged user that owns + runs the app | `deploy` |
| `APP_ROOT` | Where the app lives | `/var/www/myapp` |
| `DB_NAME` | Primary database name | `myapp_production` |
| `DB_USER` | Database role | `myapp` |
| `DOMAIN_APP` | Public hostname for the web UI | `app.example.com` |
| `DOMAIN_API` | Public hostname for the API (omit if same as `DOMAIN_APP`) | `api.example.com` |
| `ADMIN_EMAIL` | Contact for TLS-cert expiry warnings | `you@example.com` |
| `APP_PORT_SOCK` | Unix socket the app binds to | `$APP_ROOT/shared/tmp/sockets/app.sock` |
| `EIP` | Elastic IP of the instance — set **after** you allocate it in [§2](#2-launch-the-ec2-instance), not now | `203.0.113.10` |

```bash
export APP=myapp
export APP_USER=deploy
export APP_ROOT=/var/www/$APP
export DB_NAME=${APP}_production
export DB_USER=$APP
export DOMAIN_APP=app.example.com
export DOMAIN_API=api.example.com
export ADMIN_EMAIL=you@example.com
export APP_PORT_SOCK=$APP_ROOT/shared/tmp/sockets/app.sock
# export EIP=203.0.113.10   # deferred — the instance has no IP yet; set this in §2
```

> **Heredoc note (important):** when a command below writes a config file with an
> **unquoted** heredoc (`<<CONF`), the shell expands `$APP`, `$DOMAIN_APP`, etc.
> into the file — that's the point. Variables that must survive *literally* into
> the file (Nginx's `$host`, systemd's `$MAINPID`) are written as `\$host` /
> `\$MAINPID` — **keep the backslash**, it's not a typo.
>
> If a paste leaves the terminal sitting at a `>` continuation prompt, the shell
> is still reading the here-document, waiting for a line that is exactly `CONF`
> at column 0. A paste that indented `CONF`, dropped its trailing newline, or
> mangled it (e.g. an editor that curls quotes) is the usual cause. Press
> **Ctrl-C** to abort — nothing is written — then paste the whole block again.

---

## 1. AWS account & cost guardrails

Do this before launching anything so a mistake can't run up a bill.

- **Know your free-tier regime.** Accounts created **before 2025-07-15** get the
  legacy **12-month** free tier (per-service monthly allowances). Accounts
  created **on/after** that date get the **Free Plan**: a one-off **$100 credit**
  (up to $200 via onboarding tasks) that auto-closes the account after **6 months
  or when credits run out**. On the Free Plan you watch the *credit balance*, not
  per-service quotas.
- **Set a budget alert now.** AWS Budgets → Create budget → Cost budget → e.g.
  **$5/mo**, alert at **80%**. First two budgets are free. This is your safety net.
- **Public IPv4 is never free by default.** Since **Feb 2024** every public IPv4
  (including an Elastic IP attached to a running instance) costs **$0.005/hr
  (~$3.60/mo)**. The legacy free tier offsets *one* in-use IP; a second IP or an
  unattached EIP bills immediately. Keep to one in-use IP; release EIPs you don't
  need.

---

## 2. Launch the EC2 instance

In the EC2 console → **Launch instance**:

| Setting | Value | Why |
|---|---|---|
| Name | `$APP-prod` | Findable in the console |
| AMI | **Ubuntu Server LTS** (newest, e.g. 26.04) | LTS = 5 yrs of security updates; this guide is `apt`/`systemd`-based |
| Instance type | `t3.micro` (1 GB) to start; size up if RAM-bound | t3.micro is free-tier-eligible (legacy); 1 GB needs swap ([§4](#4-base-system-updates-swap-packages-auto-patching)) |
| Key pair | Create new RSA, save the `.pem`, `chmod 600` it | Your only way in — keep it safe |
| Network | Default VPC, **auto-assign public IP on** | So you can reach it before DNS |
| Security group | SSH **22 from My IP**; HTTP **80** + HTTPS **443** from anywhere | Edge firewall; SSH locked to you |
| Storage | **30 GiB gp3** | Free-tier ceiling; gp3 is the current default SSD |

After launch: allocate an **Elastic IP** and **associate** it with the instance
(so the address survives a stop/start). Capture it as the `EIP` variable from
[§0](#0-fill-these-in-first) — every later command references it:

```bash
export EIP=203.0.113.10   # the Elastic IP you just associated (re-export in each new shell)
```

Point your DNS **A records** (`$DOMAIN_APP`, `$DOMAIN_API`) at that IP. Without
DNS the box still works at `http://$EIP/` for testing.

---

## 3. First SSH in (from your laptop)

```bash
chmod 600 ~/.ssh/$APP-prod.pem            # SSH refuses keys that others can read
ssh -i ~/.ssh/$APP-prod.pem ubuntu@$EIP  # `ubuntu` is the Ubuntu AMI's default admin
```

`ubuntu` has **passwordless sudo** (via cloud-init). Run every setup step that
needs root as `ubuntu`. The `deploy` user you create in [§5](#5-create-the-deploy-user-least-privilege) is deliberately *not*
a general admin.

---

## 4. Base system: updates, swap, packages, auto-patching

```bash
# Update the package index and apply all pending upgrades — start patched.

sudo apt-get update && sudo apt-get -y full-upgrade

# Reclaim disk: drop orphaned deps and superseded kernels the upgrade left
# behind (old kernels are the biggest space hog on a long-lived box), then
# empty the downloaded-.deb cache.

sudo apt-get -y autoremove --purge
sudo apt-get clean
apt list --upgradable    # verify — expect: "Listing... Done" and nothing else

# A fresh-AMI full-upgrade almost always updates the kernel, which only takes
# effect after a reboot. Reboots only when needed; ssh back in after ~30 s.

[ -f /var/run/reboot-required ] && sudo reboot

# Core tools every build needs. Add your runtime's build headers here too
# (e.g. libpq-dev for PostgreSQL client, libvips for image processing).

sudo apt-get -y install build-essential git curl ca-certificates gnupg \
  ufw fail2ban unattended-upgrades libpq-dev

# Swap = disk used as RAM overflow. A 1 GB box can briefly exceed RAM during a
# build or under load; without swap the kernel's OOM-killer kills a process.
# 2 GB is a safe net (counts against the 30 GiB disk).

sudo fallocate -l 2G /swapfile     # reserve a 2 GB file instantly
sudo chmod 600 /swapfile           # root-only: swap can hold secrets from memory
sudo mkswap /swapfile              # format as swap
sudo swapon /swapfile              # activate now
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab   # re-enable on reboot
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swap.conf   # swap only under real pressure
sudo sysctl vm.swappiness=10       # apply now

# Turn on automatic security updates so the box self-patches.

sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 5. Create the deploy user (least-privilege)

The app runs as `deploy`, never root. `deploy` gets a **password-less sudo
allowlist of only the service-control commands** it needs — nothing else.

```bash
# --disabled-password: no password login (key-only); deploy can't be brute-forced.

sudo adduser --disabled-password --gecos "" $APP_USER

# Reuse your SSH key so you can `ssh deploy@$EIP`.

sudo mkdir -p /home/$APP_USER/.ssh
sudo cp ~/.ssh/authorized_keys /home/$APP_USER/.ssh/
sudo chown -R $APP_USER:$APP_USER /home/$APP_USER/.ssh
sudo chmod 700 /home/$APP_USER/.ssh
sudo chmod 600 /home/$APP_USER/.ssh/authorized_keys

# Narrow sudo allowlist. CRITICAL details:
#  • Use /usr/bin/systemctl — sudo matches the resolved binary path literally and
#    does NOT follow the /bin → /usr/bin symlink, so `/bin/systemctl` silently
#    fails to match and falls through to a password prompt deploy can't answer.
#  • List the exact argument vectors you'll run; sudo matches the whole line.
#  • Do NOT add deploy to the `sudo` group — that rule needs a password, and
#    deploy has none, so every fall-through would hang.

echo "$APP_USER ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx, /usr/bin/systemctl restart $APP, /usr/bin/systemctl status $APP, /usr/bin/systemctl status nginx" \
  | sudo tee /etc/sudoers.d/$APP_USER
sudo chmod 0440 /etc/sudoers.d/$APP_USER
sudo visudo -cf /etc/sudoers.d/$APP_USER   # validate — must print "parsed OK"
```

---

## 6. Harden SSH + firewall + fail2ban

A public-IP box is brute-forced within minutes. This reduces it to **key-only
SSH on one port + HTTP/HTTPS**, with auto-banning.

```bash
# SSH: disable root login, disable passwords (key-only), confirm pubkey auth on.
# ^#\? matches the directive whether commented (default) or already set. The
# trailing filename is required — drop it and sed errors "no input files".

sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl restart ssh   # validate config, then apply

# Host firewall: deny all inbound except the ports you open.

sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw allow OpenSSH        # reopen 22 BEFORE enabling, or you lock yourself out
sudo ufw allow 80/tcp         # open 80 + 443 — explicit ports: the 'Nginx Full'
sudo ufw allow 443/tcp        # profile ships with Nginx (installed later, §10)
sudo ufw --force enable

# fail2ban bans IPs that fail SSH repeatedly.

sudo systemctl enable --now fail2ban
```

> ⚠️ **Before logging out, open a second terminal and confirm
> `ssh $APP_USER@$EIP` works.** Once passwords are off, a key problem = locked
> out with no recovery.

---

## 7. Language runtime

Install your app's runtime as `$APP_USER` (so versions are per-user, no root).
[mise](https://mise.jdx.dev/) is a clean multi-language version manager; use it,
or your stack's native tool (`nvm`, `pyenv`, system packages).

```bash
sudo su - $APP_USER     # become deploy
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.profile
source ~/.bashrc

# On a 1 GB box, install runtimes from PRECOMPILED binaries, not from source —
# a source build OOM-kills or fails on missing headers. (mise example:)

mise settings ruby.compile=false
mise use --global ruby@<your-version>     # e.g. mirror your repo's .ruby-version
mise use --global node@<your-version>
mise install
exit                    # back to ubuntu
```

Pin the runtime to the **exact version your code is tested against** — a mismatch
breaks boot. Treat it as an app requirement, not "latest".

---

## 8. Database (PostgreSQL) + nightly backups

```bash
# `postgresql` is the unversioned metapackage — installs the newest major the
# Ubuntu LTS ships, so you never hardcode a version. Derive the major where needed.

sudo apt-get -y install postgresql postgresql-contrib

# Generate a strong DB password and SAVE IT (goes in .env, §9).

DB_PW=$(openssl rand -hex 24); echo "DB password: $DB_PW"

# Create the role + database. The role owns its DB and nothing else.

sudo -u postgres psql <<SQL
CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PW';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
SQL

# Confirm Postgres listens on localhost only (the apt default — never expose it):

sudo grep -E "^listen_addresses" /etc/postgresql/*/main/postgresql.conf \
  || echo "(default = localhost only — OK)"
```

Nightly backup with 14-day rotation (run as `$APP_USER`):

```bash
sudo su - $APP_USER
mkdir -p $APP_ROOT/shared/backups
cat > ~/pg_backup.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
DEST=$APP_ROOT/shared/backups
TS=\$(date +%Y%m%d-%H%M%S)
PGPASSWORD="\$DB_PASSWORD" pg_dump -Fc -h /var/run/postgresql -U $DB_USER $DB_NAME \
  > "\$DEST/$DB_NAME-\$TS.dump"
find "\$DEST" -name '*.dump' -mtime +14 -delete   # keep 14 days
EOF
chmod +x ~/pg_backup.sh

# 03:15 daily; loads .env first so \$DB_PASSWORD is set.

( crontab -l 2>/dev/null; echo "15 3 * * * set -a && . $APP_ROOT/shared/.env && set +a && ~/pg_backup.sh" ) | crontab -
exit
```

---

## 9. App directory layout + secrets

```bash
# releases/ = timestamped deploys; shared/ = files that persist across deploys
# (logs, sockets, the .env, backups); current → releases/<id> is the live symlink.
# Deploy = unpack new release, flip current, restart. Rollback = flip current back.

sudo mkdir -p $APP_ROOT/{releases,shared/{log,tmp/sockets,tmp/pids,backups}}
sudo chown -R $APP_USER:$APP_USER $APP_ROOT   # deploy owns its tree — no sudo at deploy time

# Secrets live ONLY in shared/.env on the host (never in git). Edit as deploy.
# Add your app's env vars; below is the common shape.

sudo su - $APP_USER
cat > $APP_ROOT/shared/.env <<EOF
APP_ENV=production
DATABASE_URL=postgres://$DB_USER@/$DB_NAME?host=/var/run/postgresql
DB_PASSWORD=<the DB_PW from §8>
SECRET_KEY=<a long random secret — e.g. \$(openssl rand -hex 64)>
ALLOWED_HOSTS=$DOMAIN_API,$DOMAIN_APP
EOF
chmod 600 $APP_ROOT/shared/.env   # owner-only: holds every prod secret
exit
```

> Generate cryptographic secrets with `openssl rand -hex 64` (or your framework's
> secret generator). Never reuse a dev secret in production.

---

## 10. Nginx reverse proxy + security headers + TLS

Nginx terminates TLS, serves static files, adds security headers, and forwards
app routes to the Unix socket.

```bash
sudo apt-get -y install nginx
sudo rm -f /etc/nginx/sites-enabled/default   # drop the welcome page

# Unquoted heredoc: $APP / $DOMAIN_* expand; \$host etc. stay literal for Nginx.

sudo tee /etc/nginx/sites-available/$APP > /dev/null <<CONF
upstream app_server {
  server unix:$APP_PORT_SOCK fail_timeout=0;
}

server {
  listen 80;
  listen [::]:80;
  server_name $DOMAIN_APP $DOMAIN_API;

  root $APP_ROOT/current/public;   # adjust to your app's static dir
  client_max_body_size 10M;        # cap upload size (DoS guard)
  gzip on; gzip_types text/css application/json application/javascript image/svg+xml;

  # Security headers — cheap, high-value defence-in-depth:
  add_header X-Content-Type-Options "nosniff" always;          # no MIME-sniffing
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;  # don't leak URLs
  add_header X-Frame-Options "DENY" always;                    # anti-clickjacking
  # Add a Content-Security-Policy tuned to your app's origins for real hardening.

  # App-owned routes → the socket. List your app's path prefixes here.
  location ~ ^/(api|auth|up)(/|\$) {
    proxy_pass http://app_server;
    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 30s;
  }

  # Everything else: serve static files, fall back to index.html (SPA-style).
  # No \$uri/ directory probe — it 403s when a route name collides with a built
  # dir (e.g. the /assets screen vs dist/assets/).
  location / {
    try_files \$uri /index.html;
  }
}
CONF
sudo ln -s /etc/nginx/sites-available/$APP /etc/nginx/sites-enabled/$APP
sudo nginx -t && sudo systemctl reload nginx   # test config, then apply

# TLS via Let's Encrypt — only after DNS for the domains points at the EIP.
# Flags: --nginx = get cert AND edit Nginx; -d = per-domain; --redirect = force
# HTTPS; --agree-tos = accept terms; -m = contact; -n = non-interactive.

sudo apt-get -y install certbot python3-certbot-nginx
sudo certbot --nginx -d $DOMAIN_APP -d $DOMAIN_API \
  --redirect --agree-tos -m $ADMIN_EMAIL -n
systemctl list-timers | grep certbot   # confirm the auto-renew timer exists
```

---

## 11. systemd service unit (supervise the app)

systemd starts the app on boot, restarts it on crash, runs it unprivileged, and
sandboxes it. Replace `ExecStart` with **your app's production start command**.

```bash
# Examples for ExecStart (pick one, full path to the binary via the runtime):
#   Rails/Puma : .../bundle exec puma -C config/puma.rb --bind unix://$APP_PORT_SOCK
#   Node       : .../node server.js          (read PORT/socket from env)
#   Python     : .../gunicorn app:app --bind unix:$APP_PORT_SOCK

sudo tee /etc/systemd/system/$APP.service > /dev/null <<CONF
[Unit]
Description=$APP application server
After=network.target postgresql.service   # start after network + DB
Wants=postgresql.service                   # soft dependency

[Service]
User=$APP_USER                             # unprivileged — never root
Group=$APP_USER
WorkingDirectory=$APP_ROOT/current
EnvironmentFile=$APP_ROOT/shared/.env      # load secrets/config (restart to re-read)
# systemd has a minimal env (no login shell); name the runtime's bin dir on PATH:
Environment=PATH=/home/$APP_USER/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin

ExecStart=<your app's start command, binding to $APP_PORT_SOCK>

Restart=on-failure       # auto-restart on crash
RestartSec=5s            # wait between restarts — no tight crash loop
TimeoutStopSec=30        # let in-flight requests drain before SIGKILL

# Least-privilege sandbox:
NoNewPrivileges=true     # can't gain new privileges (blocks setuid escalation)
ProtectSystem=full       # /usr /boot /etc read-only to the process
ProtectHome=read-only    # other users' homes read-only
PrivateTmp=true          # private /tmp

[Install]
WantedBy=multi-user.target   # start at normal boot
CONF

sudo systemctl daemon-reload          # re-read unit files
sudo systemctl enable --now $APP      # start now + on every boot
sudo systemctl status $APP            # confirm it's "active (running)"
```

---

## 12. Logs (view them, and cap growth so they can't fill the disk)

**View.** The app logs to stdout, which systemd captures in the journal; the web
server (Nginx) writes its own request files. A static frontend has no server log
of its own — its runtime errors stay in the browser.

```bash
journalctl -u $APP -f                # live backend log — app + any in-process workers (Ctrl-C to stop)
journalctl -u $APP -n 60 --no-pager  # last 60 lines
journalctl -u $APP -p err -f         # errors only
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log   # web page (Nginx)
```

> If you run workers as a **separate** systemd unit (e.g. a job queue), tail it
> too: `journalctl -u <worker-unit> -f`, or both at once with
> `journalctl -u $APP -u <worker-unit> -f`. Run these as a user with sudo or in
> the `systemd-journal` group — `journalctl` is not in `$APP_USER`'s allowlist.

**Cap** (unbounded logs are a classic way to fill the root volume and take the
app down):

```bash
# Cap the systemd journal (where stdout logs land):

sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/10-app.conf > /dev/null <<'EOF'
[Journal]
SystemMaxUse=500M       # journal never exceeds 500 MB
SystemKeepFree=1G       # always leave 1 GB free on disk
MaxRetentionSec=14day   # drop entries older than 14 days
EOF
sudo systemctl restart systemd-journald
```

If your app writes file-based logs, add a `/etc/logrotate.d/$APP` rule too (see
`personal_manager/docs/deployment/ec2-server-setup.md` for a worked example).

---

## 13. Deploy your code (first release)

Do this **manually first** — by hand from your laptop — before wiring up any
pipeline. A manual deploy proves every part of [§1](#1-aws-account--cost-guardrails)–[§12](#12-logs-view-them-and-cap-growth-so-they-cant-fill-the-disk)
works end-to-end, and the commands you run here are exactly what CI/CD will
later script. Everything ships to, and runs as, **`$APP_USER`**.

From your laptop or CI, ship the build into a new release dir and flip the symlink:

```bash
# (run from your machine; $EIP = the server)

REL=$(date +%Y%m%d-%H%M%S)
rsync -az --delete ./build/ $APP_USER@$EIP:$APP_ROOT/releases/$REL/
ssh $APP_USER@$EIP "
  ln -sfn $APP_ROOT/releases/$REL $APP_ROOT/current   # atomic flip

  # run DB migrations here if your stack needs them, loading .env first:
  # set -a && . $APP_ROOT/shared/.env && set +a && <migrate command>

  sudo systemctl restart $APP                          # allowlisted in §5 — no password
"

# Rollback = ln -sfn the previous releases/<id> and restart.
```

Verify it's live:

```bash
curl -sI https://$DOMAIN_APP/   # expect: HTTP/2 200 + your security headers
```

> **Then automate, in this order.** Once the manual deploy works: (1) add
> **CI** — lint + tests on every PR, a pure safety net that doesn't change how
> you ship; (2) add **CD** — move the rsync + symlink-flip + restart above into
> a pipeline job that SSHes in as `$APP_USER` on a green main; (3) add a
> **health check + auto-rollback** — curl a health route after the flip and
> re-point `current` to the last release on failure. The rule that keeps it
> safe: never let CD do something you haven't done by hand at least once — the
> manual deploy is the spec CD automates.

---

## 14. Production-readiness checklist

Tick these before pointing real users at it:

- [ ] SSH is key-only, root login off (`sudo sshd -T | grep -E 'permitrootlogin|passwordauth'`).
- [ ] UFW active, only 22/80/443 open (`sudo ufw status verbose`).
- [ ] fail2ban running (`systemctl is-active fail2ban`).
- [ ] App runs as `$APP_USER`, not root (`ps -o user= -C <process>`).
- [ ] PostgreSQL listens on localhost only.
- [ ] `shared/.env` is `chmod 600`, owned by `$APP_USER`, and **not** in git.
- [ ] HTTPS works and HTTP redirects to it; cert auto-renew timer is scheduled.
- [ ] Security headers present on responses (`curl -sI`).
- [ ] Nightly DB backup cron exists and a `.dump` appears the next morning.
- [ ] Unattended security upgrades enabled.
- [ ] AWS budget alert set; only one in-use public IPv4.
- [ ] App auto-starts after `sudo reboot` (test it once).
- [ ] You can SSH in as `$APP_USER` in a fresh terminal (not locked out).

---

## How `personal_manager` uses this template

`personal_manager/docs/deployment/README.md` is this recipe with the blanks filled in:
`APP=personal_manager`, a four-database Rails layout (primary + Solid Cache /
Queue / Cable) with PostGIS, a separate Solid Queue worker unit, a Vite SPA
served from `web/dist/`, and the exact env-var contract the app reads. Read this
template for the *why*; read `09-deployment.md` for the concrete, copy-paste
`personal_manager` commands.