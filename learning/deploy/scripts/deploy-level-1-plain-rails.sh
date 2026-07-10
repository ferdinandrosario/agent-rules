#!/usr/bin/env bash
# deploy-level-1-plain-rails.sh
#
# Sets up THIS Ubuntu EC2 server and deploys personal_manager on it —
# the runnable form of docs/learning/deploy/deploy-level-1-plain-rails.md
# (Level 1 of the hosting ladder: one server, Puma serves the API and
# the web page together on port 80, no Nginx).
#
# HOW TO RUN
#   On the server, as the `ubuntu` user, after launching the instance
#   in the AWS console (guide Step 0):
#
#     ./deploy-level-1-plain-rails.sh
#
# WHAT IT NEEDS FROM YOU
#   - The server's public IP:   nothing — it asks AWS itself.
#   - The database password:    asked once, typed hidden (or pre-set
#                               via DB_PASSWORD=...). Re-runs reuse the
#                               stored one automatically.
#   - Two short manual moments: adding a key on GitHub, and copying one
#                               secret file from your laptop. The script
#                               pauses and tells you exactly what to do.
#
# SAFE TO RE-RUN ANY TIME
#   Finished steps are detected and skipped. Your data and settings are
#   kept — the settings file is never overwritten (only the server's IP
#   inside it is refreshed), and the database is only migrated forward,
#   never wiped.
#
# The guide stays the source of truth — read it for the full *why* of
# every step; the banners and comments here are the plain-words version.

set -euo pipefail

REPO_SSH="git@github.com:ferdinandrosario/personal_manager.git"
REPO_DIR="$HOME/personal_manager"
KEY_URL="https://github.com/ferdinandrosario/personal_manager/settings/keys"

HR="────────────────────────────────────────────────────────────"
say()  { printf '\n%s\n==> %s\n' "$HR" "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf '\n%s\nERROR: %s\n%s\n' "$HR" "$*" "$HR" >&2; exit 1; }

# Poll an HTTP endpoint until it returns the wanted status, up to ~30s. Rails
# takes several seconds to finish booting after a `systemctl restart` (more so
# on a 1 GB box), so a one-shot check right after a restart races the boot and
# false-negatives. Usage: wait_http <expected-code> <curl args...>
wait_http() {
  local want="$1"; shift
  for _ in $(seq 1 15); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$@")" = "$want" ] && return 0
    sleep 2
  done
  return 1
}

# ---------- The plan, before anything runs ----------

printf '%s\n personal_manager — Level 1 deploy (one server, Puma on :80)\n%s\n' "$HR" "$HR"
cat <<'PLAN'
 This script sets up THIS Ubuntu server and deploys the app. In order:

   1. add swap memory          (so builds don't crash on 1 GB RAM)
   2. update Ubuntu            + install PostgreSQL and build tools
   3. create the app's database login
   4. install the exact Ruby + Node the app needs (via mise)
   5. get the code from GitHub   <- pauses twice: you add a key on
                                    GitHub, then copy one secret file
   6. configure the app, create its databases, load demo data
   7. build the web page files
   8. start the app as a system service on port 80

 Then it checks the result and prints a clear PASS / FAIL verdict.

 Safe to re-run any time: finished steps are skipped; your data and
 settings are kept.
PLAN

# ---------- Before starting: right user, the server's IP, the password ----------

[ "$(id -un)" = ubuntu ] || die "run as the ubuntu user (not root, not deploy)"

# The server can ask AWS for its own current public IP — a built-in
# internal address (169.254.169.254) answers questions about this
# instance. That's why you never type the IP, even after it changes.
#
# DYNAMIC by default; HARD-CODE once you own a static (Elastic) IP. Any preset
# EC2_IP wins and the IMDS lookup below is skipped — so after attaching an
# Elastic IP (fixed across stop/start) you pin it once and stop chasing the
# changing public IP:  EC2_IP=203.0.113.10 ./deploy-level-1-plain-rails.sh
if [ -z "${EC2_IP:-}" ]; then
  TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
  EC2_IP=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
            http://169.254.169.254/latest/meta-data/public-ipv4 || true)
fi
[ -n "$EC2_IP" ] || die "could not detect the public IP — not on EC2? Set EC2_IP=... and re-run"

# Re-runs: reuse the password already stored in the app's settings file,
# so the database login and the settings can never drift apart.
ENVF="$REPO_DIR/backend/.env.production"
if [ -z "${DB_PASSWORD:-}" ] && [ -f "$ENVF" ]; then
  DB_PASSWORD=$(grep -m1 '^PERSONAL_MANAGER_DATABASE_PASSWORD=' "$ENVF" | cut -d= -f2-)
  [ -n "$DB_PASSWORD" ] && note "Re-run detected: using the DB password from the existing settings file"
fi

# First run: take it from $DB_PASSWORD if exported, otherwise ask (hidden).
if [ -z "${DB_PASSWORD:-}" ]; then
  note "Tip: generate a strong one with  openssl rand -hex 24  (length beats charset)"
  read -rsp "Choose the personal_manager DB password (letters/digits/dashes): " DB_PASSWORD; echo
  read -rsp "Repeat it: " DB_PASSWORD2; echo
  [ "$DB_PASSWORD" = "$DB_PASSWORD2" ] || die "passwords did not match"
fi
# Only letters/digits/dashes: the value lands unquoted inside SQL, a
# sourced settings file, and (by-hand path) sed — special characters are
# *syntax* there, not strength. Strength comes from length instead:
# openssl rand -hex 24 gives 192 bits with no specials at all.
[[ "$DB_PASSWORD" =~ ^[A-Za-z0-9-]+$ ]] || die "password must be letters, digits, dashes only — generate one: openssl rand -hex 24"

say "Deploying to http://$EC2_IP (Level 1 — Puma only)"

# ---------- Step 1 — Swap: breathing-room memory for a 1 GB server ----------
# Compiling gems and building the web page needs more memory than the
# box has; swap (disk used as overflow RAM) keeps builds from being killed.

if swapon --show | grep -q /swapfile; then
  say "1/8 Swap — already active, skipping"
else
  say "1/8 Swap — creating a 2G overflow-memory file"
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi
free -h | grep -i swap

# ---------- Step 2 — Ubuntu packages: patch the OS, then install what the app needs ----------
# A fresh instance ships with weeks of pending security updates (the
# image is a snapshot); apply them first, then install the database and
# the compilers the app's native pieces are built with.

say "2/8 Ubuntu — applying pending updates (a fresh image always has some)"
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove --purge -y
sudo apt clean

if [ -f /var/run/reboot-required ]; then
  say "A kernel update needs a reboot before continuing."
  note "Run:  sudo reboot"
  note "SSH back in (~30s) and re-run this script — finished steps skip."
  exit 0
fi

say "2/8 Ubuntu — installing PostgreSQL, git, and the build tools"
sudo apt install -y \
  postgresql postgresql-contrib postgis \
  git curl \
  build-essential libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev \
  libpq-dev libvips
psql --version

# ---------- Step 3 — Database login: the account the app connects as ----------
# A PostgreSQL "role" is a database user. CREATEDB lets Rails create its
# databases; deliberately NOT a superuser (safer).

say "3/8 Database login — role 'personal_manager'"
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='personal_manager'" | grep -q 1; then
  note "role exists — updating its password to match"
  sudo -u postgres psql -c "ALTER ROLE personal_manager LOGIN PASSWORD '$DB_PASSWORD' CREATEDB;"
else
  sudo -u postgres psql -c "CREATE ROLE personal_manager LOGIN PASSWORD '$DB_PASSWORD' CREATEDB;"
fi

# ---------- Step 4 — Ruby + Node: the exact versions the app is tested with ----------
# Ubuntu's packaged Ruby is too old for this app; mise installs the
# pinned versions. The prebuilt-binary setting matters: compiling Ruby
# from source runs out of memory on a 1 GB box, even with swap.

say "4/8 Ruby + Node — installing mise (version manager) + pinned runtimes"
if [ ! -x "$HOME/.local/bin/mise" ]; then
  curl -sS https://mise.run | sh
  # shellcheck disable=SC2016  # the $(...) must land literally in .bashrc
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
fi
eval "$("$HOME/.local/bin/mise" activate bash)"
mise settings ruby.compile=false   # download a prebuilt Ruby, don't compile

# ---------- Step 5 — Get the code: GitHub key, clone, secret file ----------
# The repo is private, so this server needs its own read-only key
# registered on GitHub before it can download the code.

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "ec2-demo" -f "$HOME/.ssh/id_ed25519" -N ""
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  say "5/8 ACTION REQUIRED — allow this server to read the GitHub repo"
  note "Open: $KEY_URL  →  'Add deploy key' (read-only is enough):"
  echo
  cat "$HOME/.ssh/id_ed25519.pub"
  echo
  read -rp "    Press Enter once the key is added... " _
  until git clone "$REPO_SSH" "$REPO_DIR" 2>/dev/null; do
    read -rp "    Clone failed — is the key added? Press Enter to retry... " _
  done
else
  say "5/8 Code — already cloned, pulling the latest"
  git -C "$REPO_DIR" pull --ff-only
fi

cd "$REPO_DIR"
mise trust         # mise won't read a project's version file until you trust it
mise install       # Ruby 4.0.5 (prebuilt) + Node 26.3.1, per the repo's pins
mise current

# master.key decrypts the app's stored secrets. It is deliberately NOT
# in git, so it must come from your laptop's copy of the repo.
MASTER_KEY="$REPO_DIR/backend/config/master.key"
if [ ! -s "$MASTER_KEY" ]; then
  say "5/8 ACTION REQUIRED — copy the secret master.key from your laptop"
  note "From your laptop, repo root:"
  note "  scp -i ~/Downloads/Keys/28_may_2026.pem backend/config/master.key ubuntu@$EC2_IP:$MASTER_KEY"
  printf '    Waiting for master.key'
  until [ -s "$MASTER_KEY" ]; do printf '.'; sleep 5; done
  echo " found."
fi

# ---------- Step 6 — App settings + databases + demo data ----------
# The app reads its configuration from .env.production. Written once;
# on re-runs only the server-IP lines inside it are refreshed, so your
# secrets and encryption keys are kept (regenerating the encryption
# keys would make already-encrypted data unreadable).

cd "$REPO_DIR/backend"
if [ -f .env.production ]; then
  say "6/8 Settings — file exists; refreshing the server IP inside it (secrets kept)"
  sed -i -E "s|^RAILS_ALLOWED_HOSTS=.*|RAILS_ALLOWED_HOSTS=$EC2_IP|" .env.production
  sed -i -E "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=http://$EC2_IP|" .env.production
  # Backfill SOLID_QUEUE_IN_PUMA on a box whose .env predates it, so background
  # jobs run in-Puma (see the first-write branch below for the full why).
  grep -q '^SOLID_QUEUE_IN_PUMA=' .env.production || echo 'SOLID_QUEUE_IN_PUMA=true' >> .env.production
  # Backfill DEVISE_JWT_SECRET_KEY on a box whose .env predates the fail-closed
  # prod requirement (config/initializers/devise.rb) — boot raises without it.
  grep -q '^DEVISE_JWT_SECRET_KEY=' .env.production || printf 'DEVISE_JWT_SECRET_KEY=%s\n' "$(openssl rand -hex 64)" >> .env.production
  # Backfill PROFILE_ID_FINGERPRINT_KEY on a box whose .env predates the fail-closed
  # prod requirement (config/initializers/active_record_encryption.rb) — boot raises
  # without it. Safe to generate when absent: a missing key means this fail-closed app
  # never booted, so no Profile fingerprints exist yet to orphan (re-run the fingerprint
  # backfill for any rows predating the feature). The grep guard appends only when
  # missing, so a present key is never regenerated.
  grep -q '^PROFILE_ID_FINGERPRINT_KEY=' .env.production || printf 'PROFILE_ID_FINGERPRINT_KEY=%s\n' "$(openssl rand -hex 32)" >> .env.production
else
  say "6/8 Settings — writing .env.production"
  # SOLID_QUEUE_IN_PUMA=true runs Solid Queue inside Puma: production.rb sets
  # queue_adapter = :solid_queue and this one-box setup starts no separate worker,
  # so without it the friend-request mail + notification fan-out jobs would
  # enqueue and never run.
  cat > .env.production <<ENV
RAILS_ENV=production
PERSONAL_MANAGER_DATABASE_PASSWORD=$DB_PASSWORD
PGHOST=localhost
RAILS_ALLOWED_HOSTS=$EC2_IP
CORS_ALLOWED_ORIGINS=http://$EC2_IP
FORCE_SSL=false
PORT=80
WEB_CONCURRENCY=1
SOLID_QUEUE_IN_PUMA=true
SMTP_ADDRESS=localhost
SMTP_USERNAME=demo
SMTP_PASSWORD=demo
ENV
  cat >> .env.production <<ENV
AR_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
AR_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
AR_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
PROFILE_ID_FINGERPRINT_KEY=$(openssl rand -hex 32)
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
# First admin login (rails admin:ensure). UNSET on purpose: no shared default
# password = no backdoor. Set BOTH (password: >=1 letter +1 digit, 6-128 chars),
# then re-run. docs/deployment/environment-variables.md "First admin account".
# ADMIN_EMAIL=you@yourdomain.com
# ADMIN_PASSWORD=change-me-to-something-strong
ENV
  chmod 600 .env.production
fi

say "6/8 Database — install gems, create the 4 databases, load demo data"
set -a
# shellcheck source=/dev/null  # generated above; not available to the linter
source .env.production
set +a
mise exec -- bundle install
mise exec -- bundle exec rails db:create
# PostGIS (map/location support) is switched on by the database admin,
# so the app's own login never needs elevated rights.
sudo -u postgres psql -d personal_manager_production \
  -c "CREATE EXTENSION IF NOT EXISTS postgis;"
mise exec -- bundle exec rails db:prepare   # run any new migrations (never wipes data); on a fresh DB also auto-runs db:seed, which self-skips in prod (db/seeds.rb)
# First admin account — from ADMIN_EMAIL/ADMIN_PASSWORD in .env.production (idempotent).
# No-op if ADMIN_PASSWORD is unset; set both and re-run. docs/deployment/environment-variables.md "First admin account".
mise exec -- bundle exec rails admin:ensure
# Demo data is shared-password accounts — OFF by default so a real production
# database never gets them. Opt in on a throwaway demo box: SEED_DEMO_DATA=true.
if [ "${SEED_DEMO_DATA:-false}" = true ]; then
  ALLOW_PRODUCTION_SEED=true mise exec -- bundle exec rails db:seed  # docs/backend/seed-data.md
else
  echo "Skipping demo seed — set SEED_DEMO_DATA=true on a demo box to load it (docs/backend/seed-data.md)."
fi

# ---------- Step 7 — Build the web page files ----------
# React compiles into plain static files. They go into backend/public/,
# where the app serves them itself — that's the "no Nginx" trick of
# Level 1. The server's address is baked in at build time.

say "7/8 Web page — compiling React and placing the files where Puma serves them"
cd "$REPO_DIR/web"
echo "VITE_API_BASE_URL=http://$EC2_IP" > .env
mise exec -- npm ci
mise exec -- npm run build
rm -rf "$REPO_DIR/backend/public/assets" "$REPO_DIR/backend/public/index.html"
cp -r "$REPO_DIR/web/dist/." "$REPO_DIR/backend/public/"

# ---------- Step 8 — Run the app as a system service ----------
# systemd keeps the app alive: starts it at boot, restarts it on crash.
# The AmbientCapabilities line is what lets a non-root process use
# port 80 (ports below 1024 are normally root-only).

say "8/8 Service — installing + starting 'personal_manager' (Puma on :80)"
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

sudo systemctl daemon-reload
sudo systemctl enable --now personal_manager
sudo systemctl restart personal_manager   # pick up new code/settings on re-runs
sleep 3
sudo systemctl status personal_manager --no-pager | head -5

# ---------- Final check — say PASS or FAIL loudly ----------

say "Verify (on the server)"
SERVICE_OK=no; PAGE_OK=no; HEALTH_OK=no
systemctl is-active --quiet personal_manager && SERVICE_OK=yes
# The page check must claim the server's real address: the app rejects
# requests for any address not on its allow-list (only the EC2 IP is),
# so a plain "localhost" request is *correctly* refused with 403.
# The /up health route is exempt from that check.
wait_http 200 -H "Host: $EC2_IP" http://localhost && PAGE_OK=yes
wait_http 200 http://localhost/up && HEALTH_OK=yes
note "service running   : $SERVICE_OK"
note "web page answers  : $PAGE_OK"
note "health check (/up): $HEALTH_OK"

if [ "$SERVICE_OK$PAGE_OK$HEALTH_OK" = yesyesyes ]; then
  printf '\n%s\n✔ DEPLOYMENT SUCCESSFUL — personal_manager is live\n%s\n' "$HR" "$HR"
  note "App URL : http://$EC2_IP   (http, not https — a browser that forces"
  note "          https will fail; see the guide's troubleshooting table)"
  note "Server  : Puma — systemd service \"personal_manager\", port 80, on this box"
  note "Code    : $REPO_DIR"
  note "Login   : a seeded user (docs/backend/seed-data.md) — don't register; demo SMTP doesn't send"
  echo
  note "Watch it run:"
  note "  journalctl -u personal_manager -f                # live log (page + API, one stream)"
  note "  journalctl -u personal_manager -n 60 --no-pager  # last 60 lines"
  note "  sudo systemctl status personal_manager           # service state"
  echo
  note "From your laptop:  curl -sI http://$EC2_IP | head -1   # expect: HTTP/1.1 200 OK"
else
  printf '\n%s\n✖ DEPLOYMENT INCOMPLETE — one or more checks failed\n%s\n' "$HR" "$HR"
  note "Read why:  journalctl -u personal_manager -n 60 --no-pager"
  note "Then work the guide's troubleshooting table from the network up."
  exit 1
fi
