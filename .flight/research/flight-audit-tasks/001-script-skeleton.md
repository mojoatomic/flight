# Task 001: Script Skeleton

## Depends On
- None (first task)

## Delivers
- `.flight/flight-audit.sh` script with basic structure
- Argument parsing (`--all`, `--dir`, single domain)
- Color output functions (red, green, yellow)
- Usage help (`--help`)
- Proper shebang and strict mode

## NOT In Scope
- Parsing `.md` files (Task 002)
- Parsing `.validate.sh` files (Task 003)
- Cross-referencing logic (Task 004)
- Issue detection (Task 005)
- Formatted output (Task 006)

## Acceptance Criteria
- [ ] `flight-audit --help` shows usage
- [ ] `flight-audit api` accepts domain argument
- [ ] `flight-audit --all` sets all-domains flag
- [ ] `flight-audit --dir .flight/domains/` accepts custom directory
- [ ] Script uses `set -euo pipefail`
- [ ] Color functions work (green, red, yellow)
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

This is the foundation script for flight-audit. It should follow the same patterns as existing Flight validators (see `api.validate.sh` for reference).

The script will be called in three modes:
1. Single domain: `flight-audit api` → audit `.flight/domains/api.md` + `api.validate.sh`
2. All domains: `flight-audit --all` → audit all `.md` files in default directory
3. Custom dir: `flight-audit --dir /path/` → audit all `.md` files in specified directory

## Technical Notes

Use the standard Flight validator template:
```bash
#!/bin/bash
set -euo pipefail

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

usage() { ... }
main() { ... }
main "$@"
```

Default domains directory: `.flight/domains/`

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
