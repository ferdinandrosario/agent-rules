#!/usr/bin/env ruby
# Two documentation-integrity checks over every tracked markdown file:
#
#   1. BROKEN links — a relative `](target.md)` whose file does not exist on
#      disk (a renamed/moved/typo'd target). Catches dead links.
#   2. ORPHAN docs  — a file under docs/ or deploy/ that NO tracked
#      markdown links to, so a reader navigating by links can never reach
#      it. A page can hide in plain sight this way: zero broken links, just
#      zero *inbound* ones — check #1 alone stays green while the file is
#      undiscoverable.
#
# docs/archive/ is skipped: its reports are immutable history and keep the
# layout of their write time.
#
# Orphan scope is docs/** and deploy/**. READMEs, .claude/skills/*,
# and .github/instructions/* are entry points reached by tooling or
# convention (the harness, Copilot, GitHub's auto-rendered README) rather
# than by a doc link, so they are roots by design and never count as
# orphaned. ORPHAN_ROOTS lists the human entry points that link outward to
# everything — extend it per app when a new top-level doc tree gets its own
# index (e.g. deploy/README.md).
#
# AUTHORED_PER_APP lists the per-codebase canonical files the template's
# pointer files link to but that each app authors by hand after stamping
# (see stamp.sh's checklist). A link to one of them is not broken, just
# not-yet-authored; once the app writes the file the link resolves and the
# allowlist is inert. Everything else missing is a real broken link.
#
# Run from the repo root (or anywhere — paths resolve via git):
#   ruby scripts/check-doc-links.rb
# Healthy output: "BROKEN: 0" and "ORPHANS: 0", exit status 0. Any broken
# link or orphan prints the offenders and exits non-zero, so CI can gate on
# it (.github/workflows/docs-links.yml).

# Roots reachable directly, not via an inbound doc link.
ORPHAN_ROOTS = %w[docs/README.md].freeze

# Per-app canonical files: linked by the template's pointers, authored
# after stamping.
AUTHORED_PER_APP = %w[backend/AGENTS.md web/AGENTS.md mobile/AGENTS.md
                      docs/AGENTS.md].freeze

# Repo root = the git toplevel of this script's own location, so the checker is
# portable across machines and CI (no hardcoded /Users/... path).
root  = `git -C "#{__dir__}" rev-parse --show-toplevel`.chomp
files = `git -C "#{root}" ls-files '*.md'`.split("\n").reject { |rel| rel.start_with?("docs/archive/") }

authored_later = AUTHORED_PER_APP.map { |rel| File.join(root, rel) }

broken = []
linked = {}   # absolute path => true, for every file some tracked markdown links to
files.each do |rel|
  path = File.join(root, rel)
  File.read(path, encoding: "UTF-8").scan(/\]\(([^)#\s]+\.md)/) do |(target)|
    next if target.start_with?("http")
    resolved = File.expand_path(target, File.dirname(path))
    linked[resolved] = true
    next if authored_later.include?(resolved)
    broken << "#{rel}: #{target}" unless File.exist?(resolved)
  end
end

orphans = files.select { |rel| rel.start_with?("docs/", "deploy/") }
               .reject { |rel| ORPHAN_ROOTS.include?(rel) }
               .reject { |rel| linked[File.join(root, rel)] }

broken.each  { |b| puts "BROKEN LINK: #{b}" }
puts "BROKEN: #{broken.size}"
puts
orphans.each { |o| puts "ORPHAN DOC:  #{o}" }
puts "ORPHANS: #{orphans.size}"

exit 1 unless broken.empty? && orphans.empty?
