#!/bin/sh
# PostToolUse(Edit|Write) — enforce AGENTS.md "no TODO comments".
# Blocks the turn (exit 2, reason on stderr) when a just-edited *code* file
# contains a TODO/FIXME comment. Markdown/docs are skipped on purpose: the
# rules files themselves spell out the banned comment forms verbatim.
# (This file stays clean of the literal form too — it scans itself.)
# Dependency-free: reads stdin JSON with sed, greps the file on disk.
set -eu

input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -n "$file" ] && [ -f "$file" ] || exit 0

# Code files only — Ruby / JS / TS / shell / templates / YAML. Prose docs
# are exempt.
case "$file" in
  *.rb|*.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.rake|*.erb|*.sh|*.yml|*.yaml) ;;
  *) exit 0 ;;
esac

hit=$(grep -nE '(#|//|/\*)[[:space:]]*(TODO|FIXME)' "$file" 2>/dev/null | head -n3 || true)
[ -n "$hit" ] || exit 0

{
  echo "Blocked: $file contains a TODO/FIXME comment — AGENTS.md forbids them."
  echo "File an issue or do it now. Offending lines:"
  echo "$hit"
} >&2
exit 2
