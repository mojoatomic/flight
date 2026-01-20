# TypeScript Test Fixtures

Test fixtures for validating tree-sitter AST queries in the TypeScript domain.

## Purpose

These fixtures verify that the TypeScript domain's AST-based rules:
1. **Correctly identify violations** (positive test cases)
2. **Don't produce false positives** (negative test cases)

AST queries analyze the parsed syntax tree, so they should:
- Match actual code constructs (type annotations, as expressions, comments)
- NOT match patterns inside string literals
- NOT match patterns inside other comments (text content)

## Directory Structure

```
fixtures/typescript/
├── README.md              # This file
├── positive/              # Files that SHOULD trigger violations
│   ├── n1-any-type.ts     # Real any type usage
│   └── n2-ts-ignore.ts    # Bare @ts-ignore comments
├── negative/              # Files that should NOT trigger violations
│   ├── n1-any-in-comments.ts    # "any" in comments only
│   ├── n1-any-in-strings.ts     # "any" in string literals
│   ├── n2-ts-ignore-explained.ts # @ts-ignore with explanations
│   └── n2-ts-ignore-in-string.ts # "@ts-ignore" in strings
└── expected/
    └── results.json       # Expected violation counts
```

## Rules Tested

| Rule | Severity | Type | Description |
|------|----------|------|-------------|
| N1 | NEVER | AST | Unjustified any (type annotations and as expressions) |
| N2 | NEVER | AST | @ts-ignore Without Explanation (bare comments only) |

## AST Query Details

### N1: Unjustified any

Matches `any` in type positions:
```
((type_annotation (predefined_type) @violation) (#eq? @violation "any"))
((as_expression (predefined_type) @violation) (#eq? @violation "any"))
```

### N2: @ts-ignore Without Explanation

Matches bare @ts-ignore comments (no text after):
```
((comment) @violation (#match? @violation "^//\\s*@ts-ignore\\s*$"))
```

## Running Tests

### Using flight-lint

```bash
# From project root

# Test positive cases (should find violations)
./flight-lint/bin/flight-lint .flight/domains/typescript.rules.json fixtures/typescript/positive/

# Test negative cases (should find ZERO N1/N2 violations)
./flight-lint/bin/flight-lint .flight/domains/typescript.rules.json fixtures/typescript/negative/
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
- Includes edge cases (different syntax positions)
- Uses valid TypeScript syntax

### Negative Cases
- **n1-any-in-comments.ts**: "any" only in comments (single-line, multi-line, JSDoc)
- **n1-any-in-strings.ts**: "any" only in string literals (single, double, template, regex)
- **n2-ts-ignore-explained.ts**: @ts-ignore with explanations (not bare)
- **n2-ts-ignore-in-string.ts**: "@ts-ignore" in string literals

## Expected Results

See `expected/results.json` for detailed expected violation counts.

**Key expectations:**
- All positive files should have violations matching their rule
- All negative files should have ZERO N1/N2 violations

## Notes

- Fixtures use minimal valid TypeScript syntax
- Some fixtures may trigger other rules (e.g., code-hygiene) - that's expected
- Focus is on N1 and N2 AST query accuracy
