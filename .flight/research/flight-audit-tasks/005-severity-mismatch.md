# Task 005: Severity Mismatch Detection

## Depends On
- 004-cross-reference

## Delivers
- `detect_severity_mismatches()` function
- Compares expected function (from spec severity) to actual function (from validator)
- NEVER/MUST rules should use `check()` → flag if using `warn()`
- SHOULD rules should use `warn()` → flag if using `check()`

## NOT In Scope
- Gap detection (Task 004)
- Orphan detection (Task 004)
- Output formatting (Task 006)
- CLI handling (Task 001)

## Acceptance Criteria
- [ ] Detects NEVER rule using `warn()` instead of `check()`
- [ ] Detects MUST rule using `warn()` instead of `check()`
- [ ] Detects SHOULD rule using `check()` instead of `warn()`
- [ ] Returns list of mismatches with details
- [ ] Skipped rules are not checked for severity
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

The severity mapping from FLIGHT.md:
- `NEVER` → `check()` in validator (fails validation)
- `MUST` → `check()` in validator (fails validation)
- `SHOULD` → `warn()` in validator (warns but passes)

If a rule's expected function doesn't match the actual function in the validator, it's a severity mismatch. This is a common drift issue:
- Rule starts as SHOULD with `warn()`
- Later promoted to NEVER but validator not updated
- Or vice versa: NEVER demoted to SHOULD but still using `check()`

From the research, we know api.validate.sh has at least one case:
```bash
warn "N3: Potential exposed IDs in pagination (use opaque cursors)" \
```
This is ID `N3` (NEVER rule #3) but using `warn()` instead of `check()`.

## Technical Notes

For each matched rule:
1. Get spec severity: NEVER/MUST/SHOULD
2. Derive expected function:
   - NEVER → check
   - MUST → check
   - SHOULD → warn
3. Get actual function from validator
4. If expected != actual → severity mismatch

Output format:
```
N3|NEVER|warn|check  # spec=NEVER, has=warn, expected=check
```

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
