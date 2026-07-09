# Repo-level test entrypoints. Each codebase keeps its own runner — this
# Makefile is just a uniform front door so a contributor (or CI) can run
# the entire suite without remembering each codebase's invocation.
#
# Targets:
#   make test            — every suite, fail-fast
#   make test-backend    — bundle exec rspec
#   make test-web        — jest (web)
#   make test-mobile     — jest (mobile, both iOS and Android projects)
#   make test-coverage   — every suite with coverage reports

.PHONY: test test-backend test-web test-mobile test-coverage

test: test-backend test-web test-mobile

test-backend:
	cd backend && bundle exec rspec

test-web:
	cd web && npm test --silent -- --watchAll=false

test-mobile:
	cd mobile && npm test --silent

test-coverage:
	cd backend && bundle exec rspec
	cd web && npm test --silent -- --watchAll=false --coverage
	cd mobile && npm test --silent -- --coverage
