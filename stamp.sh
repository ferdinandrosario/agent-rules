#!/bin/sh
# stamp.sh — bootstrap a new repo's AI-agent rules from this template,
# WITHOUT Claude. Does the mechanical, deterministic part only:
#   1. copy the template core into the target dir
#   2. prune the codebases the new app does not have (codebase skill dir +
#      its language how-to skills + Copilot instruction file + the docs/code
#      hook's watch list)
# The authoring that follows (fill STACK, write per-codebase AGENTS.md,
# write docs pages) is not mechanizable and is printed as a checklist.
#
# Usage:
#   ./stamp.sh <target-dir> [codebase ...]
#   codebases: backend + docs are mandatory (always kept); web + mobile are
#   the selectable clients. Default (no args) = backend web mobile docs (the
#   full standard structure). Omit a client by listing only the ones you want.
#   examples:
#     ./stamp.sh ~/Downloads/full-app                       # backend web mobile docs
#     ./stamp.sh "/Users/ferdy/Downloads/Fleet Mgmt" mobile # backend mobile docs (no web)
#     ./stamp.sh ~/Downloads/web-only-app web               # backend web docs (no mobile)
#
# Safe to run only into a fresh dir: refuses if <target>/AGENTS.md exists,
# so a stamped repo can never be clobbered by mistake.
set -eu

TEMPLATE=$(CDPATH= cd "$(dirname "$0")" && pwd)

APP="${1:-}"
[ -n "$APP" ] || { echo "✖ usage: ./stamp.sh <target-dir> [codebase ...]"; exit 1; }
shift || true
KEEP="${*:-backend web mobile docs}"
case " $KEEP " in *" backend "*) : ;; *) KEEP="$KEEP backend" ;; esac  # backend always kept
case " $KEEP " in *" docs "*) : ;; *) KEEP="$KEEP docs" ;; esac        # docs always kept

ALL_CODE="backend web mobile"   # code codebases the template ships skills for

# --- guard ------------------------------------------------------------------
if [ -e "$APP/AGENTS.md" ]; then
  echo "✖ $APP/AGENTS.md already exists — refusing to clobber. Stamp into a fresh dir."
  exit 1
fi
mkdir -p "$APP"

# --- copy -------------------------------------------------------------------
cp -R "$TEMPLATE/." "$APP/"
rm -f "$APP/README.md" "$APP/stamp.sh"                 # template-only files
find "$APP" -name .DS_Store -delete 2>/dev/null || true
echo "✔ copied template core into $APP"

# --- prune codebases the app does not have ----------------------------------
# Pruning a codebase drops everything that points at its AGENTS.md so nothing
# dangles: the language how-to skills (rails/ruby→backend, react→web,
# react-native→mobile) and the Copilot path-scoped instruction file + its
# bullet in copilot-instructions.md. (backend + docs are force-kept above, so
# only web/mobile ever reach the prune body.)
kept_code=""
for c in $ALL_CODE; do
  case " $KEEP " in
    *" $c "*) kept_code="$kept_code $c"; continue ;;   # keep
  esac
  case "$c" in                                         # codebase skill + its language skills
    backend) drop="backend rails ruby" ;;
    web)     drop="web react" ;;
    mobile)  drop="mobile react-native" ;;
    *)       drop="$c" ;;
  esac
  for s in $drop; do
    rm -rf "$APP/.claude/skills/$s"; echo "✔ pruned skill: $s"
  done
  rm -f "$APP/.github/instructions/$c.instructions.md"
  sed -i.bak "/^- $c →/d" "$APP/.github/copilot-instructions.md" && rm -f "$APP/.github/copilot-instructions.md.bak"
  echo "✔ pruned Copilot instructions: $c"
done
kept_code=$(echo "$kept_code" | sed 's/^ *//')         # trim leading space

# rebuild the docs/code hook's watch list from the kept code codebases.
# template ships the literal "(backend|web|mobile)" and "backend/web/mobile".
alt=$(echo "$kept_code" | sed 's/ /|/g')               # backend|mobile
slash=$(echo "$kept_code" | sed 's/ /\//g')            # backend/mobile
hook="$APP/.claude/hooks/docs-with-code.sh"
sed -i.bak "s/(backend|web|mobile)/($alt)/; s#backend/web/mobile#$slash#g" "$hook"
rm -f "$hook.bak"
echo "✔ docs-with-code.sh now watches: $alt"

# --- manual checklist (not mechanizable) ------------------------------------
cat <<EOF

────────────────────────────────────────────────────────────────────
Mechanical stamp done. Author the rest by hand (these need judgment):

  ☐ AGENTS.md   — fill the '## STACK' block with this app's pinned
                  versions; delete any pruned codebase from the prose
                  (STACK, "Per-codebase rules", TEST COVERAGE, VERSION).
  ☐ CLAUDE.md   — drop any pruned codebase from the skill list.
  ☐ <dir>/AGENTS.md for each kept code codebase ($kept_code) — port the
                  convention skeleton. Quickest start: copy the matching
                  file from an existing app and adjust, e.g.
                  cp ~/Downloads/Fleet\\ Management/backend/AGENTS.md "$APP/backend/"
  ☐ docs/AGENTS.md is included; numbered docs/00-09 pages are written
                  same-turn as the code they document (rule 5), not upfront.

Verify when done:
  grep -q '^@AGENTS.md' "$APP/CLAUDE.md" && echo "  ✔ CLAUDE imports AGENTS"
  ls "$APP"/AGENTS.md "$APP"/*/AGENTS.md
────────────────────────────────────────────────────────────────────
EOF
