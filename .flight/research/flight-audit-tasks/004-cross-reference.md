# Task 004: Cross-Reference Engine

## Depends On
- 002-parse-md-spec
- 003-parse-validator

## Delivers
- `cross_reference()` function that compares spec rules to validator checks
- Detects matched rules (spec rule has corresponding validator check)
- Detects gaps (spec rule with no validator check)
- Detects orphans (validator check with no spec rule)
- Returns counts for each category

## NOT In Scope
- Severity mismatch detection (Task 005)
- Output formatting (Task 006)
- CLI argument handling (done in Task 001)
- Exit code logic (Task 007)

## Acceptance Criteria
- [ ] Cross-reference finds all matched rule/check pairs
- [ ] Cross-reference detects rules without checks (gaps)
- [ ] Cross-reference detects checks without rules (orphans)
- [ ] Rules marked "skip" are not flagged as gaps
- [ ] Missing validator → all rules flagged as gaps
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

Given output from `parse_spec` and `parse_validator`, this function matches by ID:

**Spec output:**
```
N1|NEVER|Verbs in URIs|check
N2|NEVER|200 OK with Error Body|check
M1|MUST|Use Correct HTTP Methods|check
S4|SHOULD|Some Rule|skip
```

**Validator output:**
```
N1|check|No verbs in URI paths
M1|warn|Use plural nouns for collections
X1|check|Unknown check
```

**Cross-reference result:**
```
matched:N1,M1
gaps:N2,S4  (S4 is skip, so exclude from gap count)
orphans:X1
```

The function should handle:
1. Perfect match (ID exists in both)
2. Gap (ID in spec, not in validator)
3. Orphan (ID in validator, not in spec)
4. Skip (spec marks as not mechanically validated)

## Technical Notes

Algorithm:
1. Build associative arrays from both parse outputs (ID → details)
2. Iterate spec rules:
   - If ID exists in validator → matched
   - If ID not in validator AND not skip → gap
3. Iterate validator checks:
   - If ID not in spec → orphan

Data structures (bash associative arrays):
```bash
declare -A SPEC_RULES   # ID → "severity|title|expected_func"
declare -A VALIDATOR_CHECKS  # ID → "func|title"
declare -a MATCHED GAPS ORPHANS
```

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
