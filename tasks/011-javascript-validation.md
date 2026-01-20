# Task 011: JavaScript Domain Validation

## Depends On
- 009-javascript-queries
- 010-javascript-fixtures

## Delivers
- End-to-end validation of JavaScript domain
- Comparison of grep vs AST results
- Documentation of false positive elimination
- Benchmark results

## NOT In Scope
- TypeScript domain migration (future task)
- Bash domain migration (future task)
- Performance optimization (future enhancement)

## Acceptance Criteria
- [ ] `flight-lint` correctly flags all positive fixtures
- [ ] `flight-lint` produces zero violations on negative fixtures
- [ ] Document false positives eliminated vs grep approach
- [ ] `javascript.rules.json` is ready for production use
- [ ] `.flight/validate-all.sh` passes with new rules

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- javascript.md

## Context

This task validates the complete JavaScript domain migration from grep to AST. We compare results between the old grep-based approach and the new AST-based approach to verify accuracy improvements.

## Technical Notes

### Validation Script

Create `scripts/validate-javascript-domain.sh`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_FILE="$PROJECT_ROOT/.flight/domains/javascript.rules.json"
FIXTURES_DIR="$PROJECT_ROOT/fixtures/javascript"

echo "================================"
echo "JavaScript Domain Validation"
echo "================================"
echo ""

cd "$PROJECT_ROOT/flight-lint"

# Build flight-lint
echo "Building flight-lint..."
npm run build

# Test positive fixtures
echo ""
echo "Testing POSITIVE fixtures (should find violations):"
echo "---------------------------------------------------"

POSITIVE_COUNT=0
for file in "$FIXTURES_DIR/positive/"*.js; do
    echo ""
    echo "File: $(basename "$file")"
    RESULT=$(./bin/flight-lint "$RULES_FILE" "$file" --format json 2>/dev/null || true)
    VIOLATIONS=$(echo "$RESULT" | jq '.summary.failures // 0')
    echo "  Violations found: $VIOLATIONS"
    POSITIVE_COUNT=$((POSITIVE_COUNT + VIOLATIONS))
done

echo ""
echo "Total violations in positive fixtures: $POSITIVE_COUNT"

# Test negative fixtures
echo ""
echo "Testing NEGATIVE fixtures (should find ZERO violations):"
echo "--------------------------------------------------------"

NEGATIVE_COUNT=0
for file in "$FIXTURES_DIR/negative/"*.js; do
    echo ""
    echo "File: $(basename "$file")"
    RESULT=$(./bin/flight-lint "$RULES_FILE" "$file" --format json 2>/dev/null || true)
    VIOLATIONS=$(echo "$RESULT" | jq '.summary.failures // 0')
    echo "  Violations found: $VIOLATIONS"
    NEGATIVE_COUNT=$((NEGATIVE_COUNT + VIOLATIONS))

    if [ "$VIOLATIONS" -gt 0 ]; then
        echo "  WARNING: False positives detected!"
        echo "$RESULT" | jq '.results[]'
    fi
done

echo ""
echo "================================"
echo "RESULTS"
echo "================================"
echo "Positive fixtures: $POSITIVE_COUNT violations (expected: >0)"
echo "Negative fixtures: $NEGATIVE_COUNT violations (expected: 0)"
echo ""

if [ "$NEGATIVE_COUNT" -eq 0 ]; then
    echo "✅ SUCCESS: Zero false positives!"
    exit 0
else
    echo "❌ FAILURE: $NEGATIVE_COUNT false positives found"
    exit 1
fi
```

### Comparison Report

Create a comparison document:

```markdown
# JavaScript Domain: Grep vs AST Comparison

## Test Results

### Positive Fixtures (Code with violations)

| File | Grep Results | AST Results | Match? |
|------|-------------|-------------|--------|
| eval.js | 4 violations | 4 violations | ✅ |
| function-constructor.js | 3 violations | 3 violations | ✅ |
| document-write.js | 3 violations | 3 violations | ✅ |
| innerhtml.js | 4 violations | 4 violations | ✅ |
| equality.js | 5 violations | 5 violations | ✅ |
| var-declaration.js | 4 violations | 4 violations | ✅ |

### Negative Fixtures (False positive tests)

| File | Grep Results | AST Results | Improvement |
|------|-------------|-------------|-------------|
| comments.js | 8 false positives | 0 | ✅ -8 |
| strings.js | 6 false positives | 0 | ✅ -6 |
| similar-patterns.js | 3 false positives | 0 | ✅ -3 |

### Summary

- **Grep approach**: 23 violations, 17 false positives
- **AST approach**: 23 violations, 0 false positives
- **False positive elimination**: 100%

## Benefits of AST-Based Validation

1. **Zero false positives from comments**
   - Grep: `// eval("code")` triggers N1
   - AST: Comments are not part of the syntax tree

2. **Zero false positives from strings**
   - Grep: `"eval() is bad"` triggers N1
   - AST: String literals are distinct from call expressions

3. **Accurate pattern matching**
   - Grep: `evaluation()` matches `eval` pattern
   - AST: Only exact `eval` identifier in call expression matches

4. **Contextual awareness**
   - AST queries can match based on syntax context
   - e.g., "innerHTML" only when it's the target of assignment
```

### Integration with Existing Validation

Update `.flight/validate-all.sh` to include AST validation option:

```bash
# Add to validate-all.sh

# Optional: Run AST-based validation if flight-lint exists
if [ -d "flight-lint" ] && [ -f ".flight/domains/javascript.rules.json" ]; then
    echo ""
    echo "Running AST-based validation..."
    cd flight-lint
    npm run build 2>/dev/null
    ./bin/flight-lint ../.flight/domains/javascript.rules.json ../src/ --format pretty || true
    cd ..
fi
```

### Final Checklist

Before marking this task complete:

- [ ] All positive fixtures produce expected violations
- [ ] All negative fixtures produce zero violations
- [ ] Comparison report documents improvement over grep
- [ ] `javascript.rules.json` passes schema validation
- [ ] Integration with existing validation works
- [ ] Documentation updated

## Validation
Run after implementing:
```bash
# Run the validation script
chmod +x scripts/validate-javascript-domain.sh
./scripts/validate-javascript-domain.sh

# Run overall validation
.flight/validate-all.sh

# Generate comparison report
# Document results in comparison.md
```
