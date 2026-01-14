# Task 003: Parse .validate.sh Files

## Depends On
- 001-script-skeleton

## Delivers
- `parse_validator()` function that extracts checks from `.validate.sh` files
- Returns structured data: check ID, title, function (check/warn)
- Handles `check` and `warn` function calls
- Handles sub-IDs like `M4a`

## NOT In Scope
- Parsing `.md` files (Task 002)
- Cross-referencing logic (Task 004)
- Gap detection (Task 005)
- Output formatting (Task 006)

## Acceptance Criteria
- [ ] `parse_validator api.validate.sh` extracts all `check` calls
- [ ] `parse_validator api.validate.sh` extracts all `warn` calls
- [ ] Extracts ID from check name (N1, M1, S1, M4a)
- [ ] Returns check count per function type
- [ ] Handles missing validator file gracefully
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

The `.validate.sh` files follow this pattern (from research):
```bash
check "N1: No verbs in URI paths" \
    bash -c '...'

warn "M1: Use plural nouns for collections" \
    bash -c '...'
```

The ID is always at the start of the quoted string, followed by colon.

Some validators have sub-IDs like `M4a` for related checks.

If the `.validate.sh` file doesn't exist, the function should return empty results (not error), as this will be flagged as "NO VALIDATOR" in the cross-reference step.

## Technical Notes

Parsing approach:
1. Match lines starting with `check ` or `warn `
2. Extract quoted string: `"([^"]+)"`
3. Parse ID from start of string: `^([A-Z][0-9]+[a-z]?):`
4. Extract title (everything after colon, before end quote)

Output format (one line per check):
```
N1|check|No verbs in URI paths
N2|check|No 200 status with error responses
M1|warn|Use plural nouns for collections
M4a|warn|Pagination metadata
```

Edge cases:
- Multi-line check definitions (string continues with `\`)
- Nested quotes in check command (ignore, we only need the first quoted string)
- Missing validator file → return empty, set flag

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
