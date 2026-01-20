# JavaScript Test Fixtures

Test fixtures for validating tree-sitter AST queries in the JavaScript domain.

## Purpose

These fixtures verify that the JavaScript domain's AST-based rules:
1. **Correctly identify violations** (positive test cases)
2. **Don't produce false positives** (negative test cases)

AST queries analyze the parsed syntax tree, so they should:
- Match actual code constructs
- NOT match patterns inside comments
- NOT match patterns inside string literals

## Directory Structure

```
fixtures/javascript/
├── README.md              # This file
├── positive/              # Files that SHOULD trigger violations
│   ├── n1-generic-vars.js
│   ├── n2-redundant-returns.js
│   ├── n3-ternary-booleans.js
│   ├── n4-boolean-comparisons.js
│   ├── n5-magic-numbers.js
│   ├── n6-generic-functions.js
│   ├── n7-single-letter-vars.js
│   ├── n8-console-log.js
│   ├── n9-var-declaration.js
│   ├── n10-loose-equality.js
│   └── s1-await-in-loops.js
├── negative/              # Files that should NOT trigger violations
│   ├── comments.js        # Violations in comments
│   ├── strings.js         # Violations in string literals
│   └── similar-patterns.js # Valid code similar to violations
└── expected/
    └── results.json       # Expected violation counts
```

## Rules Tested

| Rule | Severity | Description |
|------|----------|-------------|
| N1 | NEVER | Generic Variable Names (data, result, temp, etc.) |
| N2 | NEVER | Redundant Conditional Returns (if/else return true/false) |
| N3 | NEVER | Ternary Returning Boolean Literals (x ? true : false) |
| N4 | NEVER | Redundant Boolean Comparisons (=== true, !== false) |
| N5 | NEVER | Magic Number Calculations (60 * 60 * 1000) |
| N6 | NEVER | Generic Function Names (handleData, processItem) |
| N7 | NEVER | Single-Letter Variables (except i, j, k, m) |
| N8 | NEVER | console.log in Source Files |
| N9 | NEVER | var Declaration (use const/let) |
| N10 | NEVER | Loose Equality (== or !=) |
| S1 | SHOULD | Await in Loops |

## Running Tests

### Using flight-lint (if built)

```bash
# From project root
cd flight-lint
npm run build

# Test positive cases (should find violations)
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/positive/

# Test negative cases (should find ZERO violations)
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/negative/
```

### Validation

```bash
# Ensure overall project validation passes
.flight/validate-all.sh
```

## Test Case Guidelines

### Positive Cases
Each positive fixture file:
- Has a header comment with rule ID and title
- Contains 3+ violation examples
- Includes edge cases where applicable
- Also shows valid code for comparison

### Negative Cases
- **comments.js**: All violation patterns inside single-line and multi-line comments
- **strings.js**: All violation patterns inside string literals (single, double, template)
- **similar-patterns.js**: Valid code that looks similar but doesn't match rules

## Expected Results

See `expected/results.json` for detailed expected violation counts.

**Key expectations:**
- All positive files should have violations matching their rule
- All negative files should have ZERO violations

## Adding New Tests

1. Create test file in appropriate directory (`positive/` or `negative/`)
2. Follow existing naming convention (rule-id-description.js)
3. Update `expected/results.json` with expected violation count
4. Run validation to confirm expected behavior

## Notes

- Fixtures may intentionally violate other rules (e.g., console.log in test files)
- The fixtures directory is excluded from production code linting
- Expected counts may need adjustment as queries are refined
