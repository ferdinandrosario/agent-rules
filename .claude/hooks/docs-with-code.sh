#!/bin/sh
# Stop — non-blocking reminder for AGENTS.md "every code change requires a
# doc update in the same response". Warns (never blocks) when the session's
# work — uncommitted changes plus commits not yet on the default branch —
# touches backend/web/mobile but nothing under docs/.
# Anchored to this repo via $0 so it works whatever the session cwd is.
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." 2>/dev/null && pwd) || exit 0
cd "$root" || exit 0

# Diff against the default-branch merge-base when one exists, so code
# already committed on a feature branch still counts; fall back to HEAD.
base=$(git merge-base origin/HEAD HEAD 2>/dev/null || echo HEAD)

changed=$( { git diff --name-only "$base" 2>/dev/null; \
             git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )
[ -n "$changed" ] || exit 0

code=$(printf '%s\n' "$changed" | grep -E '^(backend|web|mobile)/' || true)
docs=$(printf '%s\n' "$changed" | grep -E '^docs/' || true)

if [ -n "$code" ] && [ -z "$docs" ]; then
  printf '{"systemMessage":"⚠ Code changed under backend/web/mobile but docs/ is untouched this session — AGENTS.md requires a same-turn doc update (setup · architecture · running · troubleshooting)."}\n'
fi
exit 0
