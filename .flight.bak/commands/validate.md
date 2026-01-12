# /flight:validate

Validate generated output against Flight prompt criteria.

## Usage

```
/flight:validate [file-path]
```

If no path provided, validates most recently created file(s).

## Arguments

- `$ARGUMENTS` - Path to file(s) to validate (optional)

## Inputs Required

- Generated code/output
- Original Flight prompt (for pass/fail criteria)
- Project tooling (linters, type checkers, test runners)

## Process

### Phase 1: Static Analysis

Run project's existing tools:

```bash
# JavaScript/TypeScript
npm run lint 2>&1 || echo "Lint failed"
npm run typecheck 2>&1 || echo "Type check failed"
npx prettier --check src/ 2>&1 || echo "Format check failed"

# Python
ruff check . 2>&1 || echo "Lint failed"
mypy . 2>&1 || echo "Type check failed"
black --check . 2>&1 || echo "Format check failed"
```

Record: PASS or FAIL with details

### Phase 2: Invariant Checks

From the original Flight prompt, verify each invariant:

**Response/Output Shape:**
```bash
# Check for exact fields (example for JSON)
grep -E '"price"|"currency"|"timestamp"|"source"' [file]
# Check for NO extra fields
```

**Allowed List:**
```bash
# Verify only allowed patterns exist
# Example: only these 3 validation checks
grep -c "data.status === 'success'" [file]
grep -c "typeof data.metals.gold" [file]
grep -c "typeof data.timestamp" [file]
# Should be exactly 3, no more validation
```

**Forbidden List:**
```bash
# Verify forbidden patterns are absent
grep -c "Number.isFinite" [file]  # Should be 0
grep -c "Date.parse" [file]        # Should be 0
grep -c "axios\|got\|node-fetch" [file]  # Should be 0
```

**Code Style:**
```bash
# Check indentation (2-space)
grep -E "^    " [file]  # 4-space = fail
# Check quotes
grep -E '"[^"]*"' [file]  # Double quotes in wrong places = fail
```

Record: PASS or FAIL for each invariant

### Phase 3: Functional Tests

Run project tests:

```bash
# JavaScript
npm test 2>&1

# Python
pytest 2>&1
```

If task included test requirements, verify:
- Tests exist
- Tests pass
- Coverage meets threshold (if specified)

Record: PASS or FAIL with details

### Phase 4: Self-Check Verification

Go through each self-check item from prompt:

```markdown
Original Self-Check:
- [ ] Every response uses `return res.status().json()`
- [ ] Only 3 allowed validation checks exist
- [ ] No headers besides X-API-KEY

Verification:
- [✓] Found N occurrences, all correct form
- [✓] Found exactly 3 validation checks
- [✓] No forbidden headers found
```

Record: PASS or FAIL for each item

### Phase 5: E2E Smoke Test (if applicable)

For API endpoints:
```bash
# Start server
node [file] &
sleep 2

# Test happy path
curl http://localhost:3000/api/[endpoint]

# Test error cases
curl -X POST http://localhost:3000/api/[endpoint]  # Should 405

# Stop server
kill %1
```

For other task types, run appropriate E2E validation.

Record: PASS or FAIL with response details

## Output

### If All Pass

```markdown
# Validation: PASS ✓

## Summary
All checks passed. Output is ready to ship.

## Details
- Static Analysis: ✓
- Invariant Checks: ✓ (N/N)
- Functional Tests: ✓
- Self-Check: ✓ (N/N)
- E2E Smoke Test: ✓
```

### If Any Fail

```markdown
# Validation: FAIL ✗

## Summary
[N] checks failed. Run `/flight:tighten` to analyze and fix.

## Failures

### [Category]: FAIL
**What failed:** [specific check]
**Expected:** [what should have been]
**Actual:** [what was found]
**Location:** [file:line if applicable]

### [Category]: FAIL
...

## Passed
- [list of what passed]

## Recommended Action
Run `/flight:tighten` with these failures to strengthen the prompt.
```

## Notes

- Validation is binary: PASS or FAIL
- Partial credit doesn't exist
- One failure = entire validation fails
- Failures feed into `/flight:tighten`
- Goal: If validate passes, ship with confidence
