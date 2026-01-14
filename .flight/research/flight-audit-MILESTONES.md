# Milestones: flight-audit

## M1: Core Parser (Tasks 001-003)

Build the parsing foundation for both `.md` and `.validate.sh` files.

**Exit Criteria**: Can extract rules from any domain pair and print them.

**Validation**: Manual testing against api.md/api.validate.sh.

## M2: Cross-Reference Engine (Tasks 004-005)

Implement matching logic and issue detection.

**Exit Criteria**: Detects gaps, orphans, and severity mismatches.

**Validation**: Test against known issues (scaffold.md missing validator).

## M3: CLI & Output (Tasks 006-007)

Complete CLI interface, formatted output, and exit codes.

**Exit Criteria**: Usable in CI pipelines, human-readable output.

**Validation**: `flight-audit --all` runs successfully, exit codes work.
