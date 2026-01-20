# Task 009: JavaScript Domain tree-sitter Queries

## Depends On
- 005-query-execution
- 007-ast-check-format

## Delivers
- tree-sitter queries for all JavaScript domain rules
- Updated `javascript.flight` with `type: ast` checks
- Query patterns documented for reuse

## NOT In Scope
- TypeScript-specific queries (future enhancement)
- Bash queries (separate domain)
- Auto-fix suggestions (future enhancement)
- Performance optimization (future enhancement)

## Acceptance Criteria
- [ ] All NEVER rules have AST queries
- [ ] All MUST rules have AST queries
- [ ] SHOULD rules have queries where beneficial
- [ ] Queries tested against fixture files (Task 010)
- [ ] Zero false positives from comments/strings
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- javascript.md (reference for rules)

## Context

This task converts the JavaScript domain from grep patterns to tree-sitter AST queries. The goal is zero false positives - code in comments and strings should not trigger violations.

## Technical Notes

### Query Patterns by Rule

#### NEVER Rules

**N1: No eval()**
```scheme
; Matches: eval("code"), eval(variable)
; Ignores: comments, strings containing "eval"
(call_expression
  function: (identifier) @violation
  (#eq? @violation "eval"))
```

**N2: No Function constructor**
```scheme
; Matches: new Function("code")
; Ignores: function declarations, arrow functions
(new_expression
  constructor: (identifier) @violation
  (#eq? @violation "Function"))
```

**N3: No document.write**
```scheme
; Matches: document.write(), document.writeln()
(call_expression
  function: (member_expression
    object: (identifier) @obj
    property: (property_identifier) @prop)
  (#eq? @obj "document")
  (#match? @prop "^write(ln)?$"))
```

**N4: No innerHTML assignment**
```scheme
; Matches: element.innerHTML = "..."
(assignment_expression
  left: (member_expression
    property: (property_identifier) @prop)
  (#eq? @prop "innerHTML"))
```

**N5: No with statement**
```scheme
; Matches: with (obj) { ... }
(with_statement) @violation
```

**N6: No __proto__ access**
```scheme
; Matches: obj.__proto__, obj["__proto__"]
[
  (member_expression
    property: (property_identifier) @violation
    (#eq? @violation "__proto__"))
  (subscript_expression
    index: (string) @violation
    (#match? @violation "__proto__"))
]
```

#### MUST Rules

**M1: Use strict equality**
```scheme
; Matches: a == b, a != b
; Ignores: ===, !==
(binary_expression
  operator: ["==" "!="] @violation)
```

**M2: Declare variables**
```scheme
; This is tricky - matches assignment to undeclared variables
; May need runtime analysis, keep as grep for now
; type: grep
; pattern: ^[a-zA-Z_]\w*\s*=\s*[^=]
```

**M3: Handle promise rejections**
```scheme
; Matches: promise.then() without .catch()
; Complex pattern - may need multi-step analysis
(call_expression
  function: (member_expression
    property: (property_identifier) @method)
  (#eq? @method "then")
  ; Check if no sibling .catch() - requires custom logic
) @violation
```

**M4: Use const/let over var**
```scheme
; Matches: var declarations
(variable_declaration
  kind: "var") @violation
```

#### SHOULD Rules

**S1: Prefer template literals**
```scheme
; Matches: string + variable concatenation
(binary_expression
  operator: "+"
  left: (string)
  right: [(identifier) (member_expression)]) @violation
```

**S2: Use arrow functions for callbacks**
```scheme
; Matches: function() {} in callback position
(call_expression
  arguments: (arguments
    (function_expression) @violation))
```

### Updated javascript.flight

```yaml
domain: javascript
version: "2.0.0"
language: javascript
file_patterns:
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.cjs"
exclude_patterns:
  - "**/node_modules/**"
  - "**/dist/**"
  - "**/build/**"

provenance:
  last_full_audit: "2025-01-15"
  audited_by: "flight-research"
  next_audit_due: "2025-07-15"

checks:
  NEVER:
    - id: N1
      title: No eval()
      type: ast
      query: |
        (call_expression
          function: (identifier) @violation
          (#eq? @violation "eval"))
      message: |
        eval() executes arbitrary code and is a security vulnerability.
        Use JSON.parse() for JSON data.
        Use Function constructor only if absolutely necessary.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

    - id: N2
      title: No Function constructor
      type: ast
      query: |
        (new_expression
          constructor: (identifier) @violation
          (#eq? @violation "Function"))
      message: |
        new Function() is equivalent to eval() for security purposes.
        Define functions statically or use safer alternatives.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

    - id: N3
      title: No document.write
      type: ast
      query: |
        (call_expression
          function: (member_expression
            object: (identifier) @obj
            property: (property_identifier) @prop)
          (#eq? @obj "document")
          (#match? @prop "^write(ln)?$"))
      message: |
        document.write() can overwrite the entire page and blocks rendering.
        Use DOM manipulation methods instead.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

    - id: N4
      title: No innerHTML assignment
      type: ast
      query: |
        (assignment_expression
          left: (member_expression
            property: (property_identifier) @prop)
          (#eq? @prop "innerHTML"))
      message: |
        innerHTML with user input enables XSS attacks.
        Use textContent for text, or sanitize HTML input.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

    - id: N5
      title: No with statement
      type: ast
      query: |
        (with_statement) @violation
      message: |
        'with' creates ambiguous scope and is forbidden in strict mode.
        Use explicit object property access instead.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

  MUST:
    - id: M1
      title: Use strict equality
      type: ast
      query: |
        (binary_expression
          operator: ["==" "!="] @violation)
      message: |
        Use === and !== to avoid type coercion bugs.
        Exception: == null checks both null and undefined.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

    - id: M4
      title: Use const/let over var
      type: ast
      query: |
        (variable_declaration
          kind: "var") @violation
      message: |
        var has function scope and hoisting issues.
        Use const for values that don't change, let otherwise.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

  SHOULD:
    - id: S1
      title: Prefer template literals
      type: ast
      query: |
        (binary_expression
          operator: "+"
          left: (string)
          right: [(identifier) (member_expression)]) @violation
      message: |
        Template literals are more readable for string interpolation.
        Use `Hello, ${name}` instead of "Hello, " + name
      provenance:
        last_verified: "2025-01-15"
        confidence: medium
```

## Query Development Tips

1. **Use tree-sitter playground** to test queries interactively
2. **Start specific, then generalize** - match exact patterns first
3. **Test with edge cases** - strings, comments, nested expressions
4. **Use @violation or @match** as capture names for consistency
5. **Document complex patterns** with examples in comments

## Validation
Run after implementing:
```bash
# Compile updated domain
python3 .flight/bin/flight-domain-compile.py .flight/domains/javascript.flight

# Run flight-lint on test fixtures (Task 010)
cd flight-lint
npm run build
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/

# Check for false positives
.flight/validate-all.sh
```
