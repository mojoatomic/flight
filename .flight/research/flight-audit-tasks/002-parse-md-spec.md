# Task 002: Parse .md Spec Files

## Depends On
- 001-script-skeleton

## Delivers
- `parse_spec()` function that extracts rules from `.md` files
- Returns structured data: rule ID, title, severity
- Handles NEVER, MUST, SHOULD sections
- Detects "not mechanically validated" annotations

## NOT In Scope
- Parsing `.validate.sh` files (Task 003)
- Cross-referencing logic (Task 004)
- Orphan detection (Task 005)
- Output formatting (Task 006)

## Acceptance Criteria
- [ ] `parse_spec api.md` extracts all NEVER rules with IDs (N1, N2...)
- [ ] `parse_spec api.md` extracts all MUST rules with IDs (M1, M2...)
- [ ] `parse_spec api.md` extracts all SHOULD rules with IDs (S1, S2...)
- [ ] Rules with "not mechanically validated" are marked as skip
- [ ] Returns rule count per severity
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

The `.md` spec files follow this structure (from research):
```markdown
### NEVER (validator will reject)
1. **Rule Title** - Description

### MUST (validator will reject)
1. **Rule Title** - Description

### SHOULD (validator warns)
1. **Rule Title** - Description
```

Rules are numbered sequentially within each section. The ID convention:
- NEVER rule #3 → N3
- MUST rule #5 → M5
- SHOULD rule #2 → S2

Some rules have annotations like "(not mechanically validated)" which should be flagged to skip during cross-reference.

## Technical Notes

Parsing approach:
1. Track current section (NEVER/MUST/SHOULD) via state machine
2. Match rule lines: `^[0-9]+\. \*\*(.+)\*\*`
3. Extract rule number and title
4. Generate ID based on section + number (N1, M1, S1)
5. Check for "not mechanically validated" in description

Output format (one line per rule):
```
N1|NEVER|Verbs in URIs|check
N2|NEVER|200 OK with Error Body|check
M1|MUST|Use Correct HTTP Methods|check
S1|SHOULD|Use HTTPS Always|warn
S4|SHOULD|Some Rule|skip  # has "not mechanically validated"
```

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
