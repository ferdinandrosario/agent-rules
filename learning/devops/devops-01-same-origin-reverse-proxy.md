# DevOps 1 — Same-origin behind a reverse proxy (a networking case study)

A real incident from this app, distilled into the networking and deployment
concepts behind it. The **practical config** lives in
[`deploy-level-2-nginx.md`](../deploy/deploy-level-2-nginx.md); this note is the
**why**. Status of the box it happened on:
`personal_manager/deploy/shared/production-readiness.md`.

## The symptom

Login failed in the browser with **"Failed to fetch"**; the dev-tools console
showed `net::ERR_CONNECTION_TIMED_OUT` on `POST http://<IP>:3000/auth/login`.
The page itself loaded fine — only the data call failed.

## Background: a web app is two separate things

- **Frontend** — static HTML/JS/CSS the browser downloads and runs.
- **API** — the Rails server the frontend's JS calls over HTTP.

The load-bearing definition: an **origin** is the triple `scheme + host + port`.
`http://1.2.3.4` (port 80) and `http://1.2.3.4:3000` are **different origins** —
differing in the port alone is enough.

## The bug: a cross-origin call to a firewalled port

```
BEFORE (broken)
  browser ──GET /──────────────▶ :80   Nginx → serves the page          ✅ 200
  page's JS ──POST /auth/login─▶ :3000  Rails, called DIRECTLY by URL    ⏳ hangs → timeout
                                  └─ blocked by the AWS security group
```

The React build had the API address **hard-coded** as `http://<IP>:3000`. So the
page loaded from port 80, but its JS reached out to port **3000** — a *different
origin*, on a port the cloud firewall never allowed inbound. The browser's
connection attempt got **no response at all**, hung ~30 s, and gave up:
`ERR_CONNECTION_TIMED_OUT`, which `fetch()` reports as the vague "Failed to fetch."

Three networking ideas make this happen — and they're the transferable lessons.

### 1. Two firewalls, not one

A packet to your box must pass **two** independent firewalls:

- The AWS **security group** — a firewall *in front of* the instance (cloud layer).
- The **host firewall** (`ufw`/iptables) — *on* the instance itself.

Here the security group was dropping `:3000`. A common trap is fixing one and
forgetting the other.

### 2. Dropped vs refused — the difference is a diagnostic

| Client sees | What it means |
|---|---|
| **hang → `ERR_CONNECTION_TIMED_OUT`** | a firewall **dropped** the packet (no reply at all) |
| **instant `ERR_CONNECTION_REFUSED`** | host reached, but **nothing is listening** (it sent back a TCP `RST`) |

So: **timeout ⇒ firewall; refused ⇒ wrong port / dead process.** That single
distinction said "security group," not "crashed Rails," before touching the box.
You can confirm from your laptop:

```sh
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://<IP>:3000/up
# 000  = timed out → port blocked by a firewall
# 200  = reachable and answering
```

### 3. Build-time vs runtime config

`VITE_API_BASE_URL` is read by Vite **when you build** and *inlined* into the
compiled JS — it is **not** read at runtime. So "change the API URL" means
**rebuild**, not restart. This is the classic SPA gotcha: browser env vars are
compile-time constants, unlike server env vars a process reads on boot.

## The fix: a reverse proxy + same-origin

```
AFTER (fixed)
  browser ──GET /──────────────▶ :80 ┐
  page's JS ──POST /auth/login─▶ :80 ┤ Nginx
                                      ├─ /, *.js, *.css   → serve the static build
                                      └─ /auth /api /up /rails /cable
                                                          → proxy to 127.0.0.1:3000 (Rails)
        port 3000: bound to localhost, CLOSED to the internet
```

Two halves:

- **Reverse proxy.** Nginx sits on port 80 and *forwards* the API paths
  (`/auth`, `/api`, …) to Rails on `127.0.0.1:3000`. The browser only ever talks
  to **one public port**. Rails is reachable *only* from inside the box.
- **Same-origin / relative URLs.** With `VITE_API_BASE_URL` **empty**, the JS
  calls **relative** paths like `/auth/login`, which resolve against *whatever
  origin served the page*. Page and API are now the **same origin**.

What that buys you:

- **CORS disappears.** CORS is a *browser* safety check that only fires on
  **cross-origin** requests. Same-origin → no preflight, no `CORS_ALLOWED_ORIGINS`
  needed for the web app. (It had existed only to paper over the cross-origin design.)
- **Nothing baked into the build.** Relative URLs work on any host/IP — so when
  the box's public IP changed on a stop/start, the build kept working with **no
  rebuild**.
- **Smaller attack surface.** `:3000` is no longer exposed at all — one front
  door (Nginx), which is also where TLS, rate-limiting, and caching will live.

## Why this is *the* production pattern

- **One public port** — in real production, `443` with TLS; the API stays on
  `localhost` behind the proxy.
- **Build once, run anywhere** — the artifact has no environment baked in; the
  *environment* (the proxy) decides where the API is. (Server-side that's
  12-factor env vars; for a browser build, same-origin + a proxy is the equivalent.)
- **Defense in depth** — even if a firewall rule lapses, Rails on `127.0.0.1`
  still isn't internet-reachable.
- **"Works" ≠ "secure."** Login working only proved the *proxy path*; confirming
  `:3000` was *closed* was an independent check. Verify both.

## The loose thread: ephemeral IPs

A plain EC2 public IP **changes on every stop/start** (it did here:
`3.94.110.215` → `32.199.158.220`). For anything real you need a **stable
address** — an Elastic IP or a DNS name. It's also why **TLS is blocked until you
own a domain**: a certificate authority signs a *name*, not a moving IP. See the
TLS item in `personal_manager/deploy/shared/production-readiness.md`.

## Glossary

| Term | One-line meaning |
|---|---|
| **Origin** | `scheme + host + port`; the unit the browser's same-origin rules key on. |
| **CORS** | Browser mechanism that gates **cross-origin** requests; irrelevant when same-origin. |
| **Reverse proxy** | A server (Nginx) that fronts your app and forwards requests to it — the public face. |
| **Security group** | AWS's network firewall *in front of* the instance. |
| **Host firewall** | `ufw`/iptables *on* the instance — a second, independent layer. |
| **Drop vs refuse** | Dropped packet → timeout; refused (TCP `RST`) → instant "connection refused". |
| **Build-time config** | Values inlined when the bundle is compiled (Vite `VITE_*`); a change needs a rebuild. |
| **Ephemeral IP** | A public IP released on stop; replaced by an Elastic IP / DNS for stability. |
