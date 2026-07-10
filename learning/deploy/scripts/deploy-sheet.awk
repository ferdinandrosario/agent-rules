#!/usr/bin/awk -f
# deploy-sheet.awk — condensed paste sheet from a deploy-ladder guide.
# (An awk program, not a shell script — run via its shebang or `awk -f`.)
#
# Usage (this copy lives in the learning repo; personal_manager keeps its
# own at scripts/deploy-sheet.awk for the production deploy/ guides):
#   deploy/scripts/deploy-sheet.awk deploy/deploy-level-1-plain-rails.md | less   # laptop, repo root
#   ~/learning/deploy/scripts/deploy-sheet.awk ~/my-deploy.md   # on the box, after the clone step
#
# Output: per step heading, each paste unit on ONE line — blank-line-separated
# command groups inside a ```sh block are joined with " && ", explanation
# comments are stripped. Kept as-is because they are single paste units
# already: heredoc bodies (cat/tee <<EOF … EOF) and multi-line quoted
# strings. Kept comments: "# expect…" success signals and action URLs.
# Everything stripped here still lives in the full guide — this is the
# run-time view, not a replacement.
#
# Only blocks fenced exactly ```sh are extracted. The guides tag
# non-paste usage examples (like this script's own invocation) ```shell —
# GitHub renders both identically, but this script skips them.

function headed() {
  if (!printed) {
    print ""
    if (h != lasth) { print "━━ " h; lasth = h }
    printed = 1
  }
}
function flush()  { if (buf != "") { headed(); print buf; buf = "" } }

/^#/ && !inblk { h = $0 }

/^```sh[[:space:]]*$/ && !inblk { inblk = 1; buf = ""; printed = 0; verb = 0; tag = ""; next }

inblk && tag == "" && !verb && /^```$/ { flush(); inblk = 0; next }

!inblk { next }

{
  l = $0

  # Inside a heredoc: file content, print verbatim until the terminator.
  if (tag != "") {
    headed(); print l
    if (l == tag) tag = ""
    next
  }

  # Inside a multi-line quoted string: verbatim until the quote closes.
  if (verb) {
    headed(); print l
    t = l
    if (gsub(/'/, "", t) % 2) verb = 0
    next
  }

  # Blank line = paste-unit boundary.
  if (l ~ /^[[:space:]]*$/) { flush(); next }

  # Comment-only line: keep success signals + action URLs, drop the rest.
  if (l ~ /^[[:space:]]*#/) {
    if (l ~ /expect/ || l ~ /https?:\/\//) { flush(); headed(); print l }
    next
  }

  # Strip a trailing inline comment (doc style: 2+ spaces before the #).
  sub(/[[:space:]][[:space:]]+#.*$/, "", l)

  # Heredoc opener: flush pending commands, then pass through verbatim.
  if (match(l, /<<-?'?[A-Za-z_]+'?/)) {
    tag = substr(l, RSTART + 2, RLENGTH - 2)
    gsub(/[-']/, "", tag)
    flush(); headed(); print l
    next
  }

  # A line opening an unterminated single-quoted string (e.g. sudo bash -c '
  # …multi-line…'): pass through verbatim until it closes.
  t = l
  if (gsub(/'/, "", t) % 2) { flush(); headed(); print l; verb = 1; next }

  # Backslash continuations: merge into one logical line.
  while (l ~ /\\$/) {
    sub(/[[:space:]]*\\$/, " ", l)
    if ((getline nl) <= 0) break
    sub(/^[[:space:]]+/, "", nl)
    sub(/[[:space:]][[:space:]]+#.*$/, "", nl)
    l = l nl
  }

  # Append to the current paste unit.
  buf = (buf == "" ? l : buf " && " l)
}

END { flush() }
