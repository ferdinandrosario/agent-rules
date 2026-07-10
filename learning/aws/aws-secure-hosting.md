# Hosting a website securely on AWS — a defense-in-depth learning guide

A **general, app-agnostic** guide to the way large, security-serious companies
(think Apple, Google, banks) host web applications on AWS. It teaches the
*architecture and the reasoning*, not commands for one specific app — so you can
apply it to any stack (Rails, Node, Python, Go, …).

The goal isn't "a server that works"; it's **a system that stays safe when
something goes wrong** — a stolen credential, an unpatched box, a leaked secret.
That property comes from a handful of principles, applied in independent layers.

---

## The five principles everything below serves

1. **Defense in depth** — many independent layers, so a breach of one is
   contained by the next. No single control is trusted to be perfect.
2. **Least privilege** — every user, service, and network path gets the
   *minimum* access it needs, and nothing more.
3. **Zero trust** — nothing is trusted just because it's "inside the network";
   every request is authenticated and authorized.
4. **Assume breach** — design as if an attacker is already inside: limit the
   blast radius, and detect + respond fast.
5. **Encrypt everything, automate everything** — data is encrypted in transit
   and at rest; the whole environment is defined in code, reviewable and
   reproducible (no risky click-ops).

---

## How to use this guide

- It's organized as **layers** (identity → network → edge → host → data → app →
  detection). Read top to bottom once to build the mental model.
- Each layer gives the **what + why + where (the AWS service)**, a **worked
  example** where it helps, and a **⚠️ Common mistakes** list of the errors
  people actually make.
- The [Hands-on security checklist](#hands-on-security-checklist-cis-aligned) near
  the end is a concrete, verifiable to-do you can audit against.
- It avoids copy-paste deploy commands — exact steps depend on your account,
  region, and app. For a hands-on single-host start see the
  [AWS deployment template](aws-deployment-template.md); for the canonical
  reference, the **AWS Well-Architected Framework — Security Pillar**.

---

## The mental model: defense in depth

```
        Internet
           │
   ┌───────▼────────┐   Edge      CloudFront + WAF + Shield  (filter, rate-limit, DDoS, TLS)
   │                │
   ┌───────▼────────┐   Network   VPC · public subnet: load balancer only
   │                │             private subnets: app + data (no public IP)
   ┌───────▼────────┐   Host      patched, non-root, immutable instances/containers
   │                │
   ┌───────▼────────┐   App       authn/authz, input validation, scanned deps
   │                │
   ┌───────▼────────┐   Data      encrypted (KMS), private DB, backups, secrets vault
   │                │
   └────────────────┘   Identity (wraps all)   least-privilege IAM, MFA, short-lived creds
                        Detection (watches all) CloudTrail · GuardDuty · Config · logs
```

Each layer is independent: getting past the edge still leaves the network; a
compromised app process still can't read the database's secrets, reach the
internet freely, or assume another service's role.

---

## Layer 1 — Identity & access (start here)

Most breaches are stolen identities, not hacked networks — so this layer matters
most. The aim: **no long-lived credentials, every grant scoped, every action attributable.**

- **Never use the root account for daily work.** Put hardware/virtual MFA on it,
  remove its access keys, and lock the credentials away. Why: root can do
  anything and cannot be scoped. **Where:** IAM.
- **Humans log in via SSO with MFA, assuming roles — not IAM users with passwords/keys.**
  Why: credentials become short-lived and centrally revocable. **Where:** IAM Identity Center (SSO).
- **Services use IAM roles, never static access keys.** Why: keys get committed to
  git and leaked; roles issue temporary credentials that can't be copied off the
  box. **Where:** IAM roles + instance profiles.
- **Scope every policy to specific actions on specific resources.** Use
  permission boundaries to cap what a team's roles can ever grant. **Where:** IAM.
- **Separate AWS accounts per environment** (prod / staging / dev / security /
  log-archive), under AWS Organizations with Service Control Policies (SCPs)
  setting guardrails. Why: this is how mature orgs isolate blast radius — a
  mistake (or breach) in dev cannot touch prod. **Where:** AWS Organizations + Control Tower.

**Worked example — a least-privilege policy** (an app role that may use *one*
bucket, with three actions — not `s3:*` on `*`):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
    "Resource": "arn:aws:s3:::my-app-uploads/*"
  }]
}
```

**⚠️ Common mistakes**

- Using the root account (or one shared admin user) for everyday work.
- Long-lived `AWS_ACCESS_KEY_ID`/`SECRET` baked into app config or CI instead of a role.
- `"Action": "*"` / `"Resource": "*"` "just to make it work" — then never tightening it.
- One AWS account for everything, so a dev mistake can delete production.
- MFA "coming later." It never comes; add it on day one.

---

## Layer 2 — Network isolation

Aim: **the only thing the internet can reach is the load balancer.** Everything
else is private.

- **One VPC with public and private subnets across ≥2 Availability Zones.** App
  and data live in private subnets (no route to the internet); only the load
  balancer is public. AZ spread survives a datacenter failure. **Where:** VPC.
- **Least-privilege security groups — each tier accepts traffic only from the
  tier directly in front of it:**

  | Security group | Inbound | Allowed from |
  |---|---|---|
  | Load balancer | 443 (and 80→443 redirect) | the internet (`0.0.0.0/0`) |
  | App servers | the app port | the load-balancer SG **only** |
  | Database | the engine's port (e.g. 5432) | the app SG **only** |
  | Admin access | — | **nobody** — use SSM Session Manager |

  Note the source is a *security-group reference*, not a CIDR — so it keeps
  working as instances scale in and out. **Where:** EC2 → Security Groups.
- **NACLs as a coarse second layer** at the subnet boundary (e.g. deny known-bad
  ranges). Security groups are stateful and primary; NACLs are stateless backup.
- **No public IPs on app or data instances** — a NAT gateway gives private
  instances *outbound* access (updates, image pulls) without being reachable
  *inbound*. **Where:** VPC subnet + instance settings.
- **No inbound SSH. Use AWS SSM Session Manager** for shell access. Why: nothing
  to brute-force; access is IAM-controlled and fully audited. **Where:** Systems Manager.
- **Reach AWS services over VPC endpoints** (S3, Secrets Manager, ECR, …) so that
  traffic to them never traverses the public internet. **Where:** VPC endpoints.

**⚠️ Common mistakes**

- The database in a public subnet, or its SG open to `0.0.0.0/0:5432`.
- A security group rule `0.0.0.0/0` on port 22 "for now" (the classic breach vector).
- Allowing app↔DB by CIDR instead of by SG reference (breaks on scale, over-broad).
- One flat subnet with everything public because it's "simpler."
- Leaving SSH open at all instead of moving to SSM.

---

## Layer 3 — Edge protection

- **Terminate TLS everywhere; redirect all HTTP to HTTPS; enable HSTS; use a
  modern TLS policy** (TLS 1.2+ only). Why: no credential or cookie ever crosses
  the wire in clear, and downgrade attacks are blocked. **Where:** ACM certs on
  CloudFront / the load balancer.
- **Put a CDN in front (CloudFront).** Why: absorbs load, caches static assets,
  hides origin IPs, and is the single TLS front door. **Where:** CloudFront.
- **AWS WAF with managed rule sets + rate-based rules.** Why: blocks common
  attack patterns (SQLi/XSS) and throttles credential-stuffing / scraping.
  **Where:** WAF (attach to CloudFront or the ALB).
- **AWS Shield for DDoS.** Standard is automatic; Shield Advanced for high-risk
  or regulated targets. **Where:** Shield.

**⚠️ Common mistakes**

- TLS only at the edge, plain HTTP from the edge to the app (encrypt that hop too,
  or keep it strictly inside the VPC).
- Exposing the origin's IP so attackers bypass CloudFront/WAF — lock the origin
  SG to CloudFront's prefix list.
- WAF in "count" mode forever, never switched to "block."
- No rate limit on `/login` / token endpoints.

---

## Layer 4 — Compute / host hardening

- **Run every process as a non-root, unprivileged user, sandboxed** (systemd
  `NoNewPrivileges`, `ProtectSystem`, containers as non-root). Why: a compromised
  process can't own the box.
- **Patch automatically, or go immutable.** Either enable unattended security
  updates, or (better) bake hardened images and **replace** instances instead of
  patching in place. Why: no long-lived drift for attackers to exploit. **Where:**
  EC2 Image Builder / your CI image pipeline.
- **Start from a hardened base** (CIS-benchmark AMI or your own) and install only
  what you run — fewer packages, smaller attack surface.
- **Keep no secret on disk** — secrets come from a vault at runtime (Layer 5).

**⚠️ Common mistakes**

- Running the app (or Docker containers) as root.
- "We'll patch later" — a months-stale box is a known-CVE buffet.
- Mutable, hand-tweaked servers nobody can reproduce (config drift).
- Leaving build tools, debug ports, or sample apps on production hosts.

---

## Layer 5 — Data protection

- **Encrypt at rest with KMS and in transit with TLS — everywhere**: database,
  object storage, backups, EBS volumes, queues. Prefer customer-managed KMS keys
  with rotation for sensitive data. **Where:** KMS + each service's encryption setting.
- **Database in private subnets, multi-AZ, with automated backups + point-in-time
  recovery — and *tested* restores.** Why: a backup you've never restored isn't a
  backup. **Where:** RDS / Aurora.
- **Object storage locked down** — Block Public Access on, bucket policies
  least-privilege, versioning + lifecycle for recovery. **Where:** S3.
- **Secrets live in a vault, never in code or env files, with automatic rotation.**
  **Where:** AWS Secrets Manager / SSM Parameter Store.
- **Least-privilege data access** — the app's role can touch only its own
  bucket/database (see the Layer 1 example), nothing else.

**⚠️ Common mistakes**

- A public S3 bucket (the all-time most common AWS leak).
- Secrets in `.env` committed to git, or printed into CI logs.
- Backups enabled but never restore-tested — they fail exactly when you need them.
- Unencrypted volumes/snapshots, or one shared KMS key for everything.

---

## Layer 6 — Application security

- **Scan in CI on every change** — dependency CVEs, static analysis (SAST), and
  secret-scanning — and **fail the build** on findings. **Where:** your CI pipeline.
- **Secure the software supply chain** — pin dependencies, build from trusted
  bases, sign and verify container images, and review third-party code.
- **Enforce authn + authz on every request, validate all input, and set security
  headers** (CSP, HSTS, `X-Content-Type-Options: nosniff`, `X-Frame-Options`).

**⚠️ Common mistakes**

- Scanners that run but don't block the merge (findings ignored).
- Trusting client-side validation; authorization checked only in the UI.
- Pulling `:latest` unpinned base images; no image signing.
- Verbose error pages / stack traces leaked to users.

---

## Layer 7 — Detection & response (assume breach)

You can't prevent everything — so you must *see* and *react*.

- **CloudTrail** — records every API call (the audit trail). **On in every
  account**, delivered to a locked, separate log-archive account.
- **VPC Flow Logs** — network connections, for forensics.
- **GuardDuty** — managed threat detection that flags anomalous behavior
  (e.g. credential use from a new country, crypto-mining).
- **Security Hub + AWS Config** — continuous posture + compliance checks against
  benchmarks (e.g. CIS), with auto-remediation rules where safe.
- **Centralized, tamper-resistant logging + alerting**, an on-call path, and
  **written incident-response runbooks you rehearse**.

**⚠️ Common mistakes**

- CloudTrail off, or writable from the same account it audits (an attacker just
  deletes the evidence).
- Alerts with no owner / no on-call — they fire into the void.
- Logs kept on the box that gets compromised; no central, immutable copy.
- Never running an incident drill, so the first real one is chaos.

---

## Cross-cutting: governance & automation

- **Infrastructure as Code (Terraform / AWS CDK) for the entire stack.** Why:
  reviewable, reproducible, drift-free — you can rebuild prod from code, and every
  change goes through review. Non-negotiable at scale.
- **Multi-account organization** (prod / staging / dev / security / log-archive),
  centrally governed with **SCP guardrails** (e.g. "deny disabling CloudTrail",
  "deny public S3"). Blast-radius isolation is the hallmark of mature setups.
- **Cost guardrails** — Budgets + alerts, so a misconfiguration (or an attacker
  spinning up crypto-miners) can't quietly run up a bill.
- **Compliance frameworks** — map controls to SOC 2 / ISO 27001 / the CIS AWS
  Benchmark when you need to *prove* security, not just have it.

---

## A reference architecture (the shape to aim for)

```
Internet
  │  HTTPS
  ▼
CloudFront (CDN, TLS)  →  AWS WAF + Shield
  │
  ▼
Application Load Balancer        ── public subnets (multi-AZ) ──
  │  (only public tier)
  ▼
App servers (auto-scaling group) ── private subnets (multi-AZ) ──
  │
  ▼
RDS / Aurora (encrypted, multi-AZ, automated backups) ── private subnets ──

Access:    SSM Session Manager (no inbound SSH)
Secrets:   Secrets Manager (rotated)         Encryption: KMS everywhere
Watching:  CloudTrail · GuardDuty · Config · centralized logs (separate account)
Defined:   Terraform/CDK, across separate prod/staging/security AWS accounts
```

---

## Hands-on security checklist (CIS-aligned)

Audit your environment against these. Each maps to a layer above; tick only what
you can *verify*.

**Identity**
- [ ] Root account has MFA and no access keys; not used for daily work.
- [ ] Humans use SSO + MFA into roles; no shared IAM users.
- [ ] Services use IAM roles — zero static access keys in app config or CI.
- [ ] IAM policies scoped to specific actions + resources; permission boundaries set.
- [ ] Separate AWS accounts per environment, with SCP guardrails.

**Network**
- [ ] App and database in private subnets across ≥2 AZs; no public IPs on them.
- [ ] Security groups reference each other (LB→app→DB); none open `0.0.0.0/0` except the LB on 443.
- [ ] No inbound SSH anywhere; access is via SSM Session Manager.
- [ ] VPC endpoints for S3/Secrets Manager/etc.; NAT for outbound only.

**Edge**
- [ ] TLS 1.2+ everywhere; HTTP→HTTPS redirect; HSTS on.
- [ ] CloudFront + WAF (managed rules in **block** mode) + rate limits on auth.
- [ ] Origin locked to CloudFront (origin IP not directly reachable).

**Host**
- [ ] App runs as a non-root, sandboxed user.
- [ ] Auto-patching on, or immutable image pipeline; hardened base image.
- [ ] No secrets on disk; minimal installed packages.

**Data**
- [ ] Encryption at rest (KMS) + in transit, everywhere.
- [ ] DB multi-AZ, automated backups + PITR, **restore drill run**.
- [ ] S3 Block Public Access on; buckets least-privilege + versioned.
- [ ] Secrets in a vault with rotation; none in git.

**App**
- [ ] CI **fails** on dependency CVEs / SAST / secret-scan findings.
- [ ] Dependencies pinned; container images signed.
- [ ] Authz enforced server-side; security headers present.

**Detection**
- [ ] CloudTrail on in all accounts → separate, locked log-archive account.
- [ ] GuardDuty + Security Hub + Config enabled; findings have an owner.
- [ ] Central immutable logs; alerts page on-call; an IR runbook exists and is rehearsed.

**Governance**
- [ ] Whole stack in Terraform/CDK; changes reviewed.
- [ ] Budgets + cost alerts set.

---

## How to learn this hands-on

- **Start small, then layer up.** Stand up one hardened box first (the
  [AWS deployment template](aws-deployment-template.md) is a good single-host
  start), then add the network, edge, data, and detection layers above it.
- **Practice in a sandbox account** with a Budgets alert on, so experiments can't
  surprise you with a bill.
- **Read the authoritative sources:**
  - AWS **Well-Architected Framework — Security Pillar** (the canonical model).
  - **CIS AWS Foundations Benchmark** (concrete, checkable hardening items).
  - AWS **Security Reference Architecture (SRA)** and the AWS security workshops.

Security is a practice, not a checkbox — revisit these layers as the app grows
and as AWS ships new controls.
