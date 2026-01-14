# Task 006: Output Formatting

## Depends On
- 004-cross-reference
- 005-severity-mismatch

## Delivers
- `print_report()` function that formats audit results
- Matches the output format from PRD
- Uses color coding (green ✅, yellow ⚠️, red ❌)
- Summary section with counts
- Detailed sections for each issue type

## NOT In Scope
- Exit code logic (Task 007)
- Parsing logic (Tasks 002-003)
- Detection logic (Tasks 004-005)
- Multi-domain aggregation (Task 007)

## Acceptance Criteria
- [ ] Output matches PRD format exactly
- [ ] Displays spec rule counts (NEVER, MUST, SHOULD)
- [ ] Displays validator check counts (check, warn)
- [ ] Shows matched count with green ✅
- [ ] Shows severity mismatches with yellow ⚠️
- [ ] Shows gaps with red ❌
- [ ] Shows orphans with blue 📝
- [ ] Shows "NO VALIDATOR" for missing .validate.sh
- [ ] Final RESULT line shows PASS or DRIFT DETECTED
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

The output format from the PRD:
```
═══════════════════════════════════════════
  Flight Audit: api
═══════════════════════════════════════════

Spec: 8 NEVER, 9 MUST, 13 SHOULD (30 total)
Validator: 6 check, 12 warn (18 total)

✅ Matched: 17
⚠️  Severity mismatch: 1
   N3: spec=NEVER, validator=warn

❌ Gaps (in spec, no validator): 2
   M1: Correct HTTP Methods
   M2: Correct Status Codes

📝 Orphans (in validator, no spec): 1
   M4a: Pagination metadata

═══════════════════════════════════════════
  RESULT: DRIFT DETECTED (4 issues)
═══════════════════════════════════════════
```

For missing validator:
```
═══════════════════════════════════════════
  Flight Audit: scaffold
═══════════════════════════════════════════

Spec: 5 NEVER, 3 MUST, 2 SHOULD (10 total)
Validator: NO VALIDATOR

❌ Gaps: ALL (no validator to check against)

═══════════════════════════════════════════
  RESULT: NO VALIDATOR
═══════════════════════════════════════════
```

## Technical Notes

Use the existing Flight color functions:
```bash
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
```

Section ordering:
1. Header with domain name
2. Summary counts (spec vs validator)
3. Matched (only if > 0)
4. Severity mismatches (only if > 0)
5. Gaps (only if > 0)
6. Orphans (only if > 0)
7. Result line

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
