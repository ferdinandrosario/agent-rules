# docs/ — the app's source of truth

Every app stamped from this template keeps its documentation here,
organized by **topic folder** — one authoritative page per topic, found
within two or three levels. Reading order is navigation, not filename
prefixes: this README is the index.

## What the template ships vs what you author

The template ships only the **project-agnostic** pages (this folder).
Everything else is authored **as the app grows** — a page lands in the
same turn as the code it documents (AGENTS.md rule 5), never upfront.

| Shipped here | Role |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The feature-doc checklist every PR runs. |
| [`todo.md`](todo.md) | Deferred ideas & suggestions — the sanctioned "later" list. |
| [`development/ai-agents.md`](development/ai-agents.md) | How the AI-agent rule layout works (canonical `AGENTS.md` + thin pointers) and the pointer-integrity check. |
| [`development/naming-conventions.md`](development/naming-conventions.md) | Full naming reference for scripts & docs — verb-first `kebab-case`, lifecycle prefixes, the rename ritual. |
| [`development/github-actions.md`](development/github-actions.md) | Practical CI guide for the shipped workflows — minimum parameters, gotchas, common failures. |

## Standard layout (author as the app grows)

```
docs/
  README.md            # this index — keep its links current
  AGENTS.md            # docs/-only ruleset (author by hand; see stamp.sh checklist)
  CONTRIBUTING.md      # shipped — feature-doc checklist
  FEATURES.md          # one bullet per surface, the feature inventory
  todo.md              # shipped — deferred ideas
  getting-started/     # prerequisites, running locally
  architecture/        # system overview, request flow
  backend/ web/ mobile/  # per-codebase setup + file maps
  development/         # shipped — conventions, CI, AI agents, naming
  feature/             # docs/feature/<feature>.md — per-feature canonical references
  deployment/          # deploy recipes + production env vars
  operations/          # runbooks, playbooks/, tuning
  security/            # threat model, secrets handling
  troubleshooting/     # symptom → fix, exact error messages
  archive/             # dated point-in-time reports, frozen at write time
```

Two integrity rules keep this tree honest, enforced by
`scripts/check-doc-links.rb` (run by the `docs-links.yml` workflow on
every markdown change):

1. **No broken links** — every relative `.md` link resolves to a file.
2. **No orphans** — every page under `docs/` is reachable from a link;
   a page nothing links to might as well not exist. Link every new page
   from this index (or a page this index reaches).
