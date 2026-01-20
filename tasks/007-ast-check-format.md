# Task 007: AST Check Format in .flight YAML

## Depends On
- 006-compiler-rules-json

## Delivers
- New `type: ast` check format in `.flight` YAML
- `query:` field for tree-sitter S-expressions
- Compiler support for AST checks
- Documentation in `.flight/templates/`

## NOT In Scope
- Actual tree-sitter queries for domains (Task 009)
- Migration of existing checks (Tasks 009-011)
- Validation that queries are syntactically valid (future enhancement)

## Acceptance Criteria
- [ ] `.flight` files can include `type: ast` checks
- [ ] `query:` field accepts multi-line S-expressions
- [ ] Compiler emits `query` in `.rules.json` for AST checks
- [ ] `type: grep` remains default for backward compatibility
- [ ] Template file shows AST check example
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- python.md

## Context

Currently all checks use grep patterns. This task adds support for `type: ast` checks that use tree-sitter query syntax.

The compiler will pass the query through to `.rules.json` unchanged. `flight-lint` will execute it.

## Technical Notes

### New .flight YAML Format

```yaml
checks:
  NEVER:
    - id: N1
      title: No eval()
      type: grep  # Backward compatible default
      pattern: 'eval\s*\('
      message: eval() executes arbitrary code

    - id: N2
      title: No eval() (AST)
      type: ast
      query: |
        (call_expression
          function: (identifier) @match
          (#eq? @match "eval"))
      message: eval() executes arbitrary code - detected via AST

  MUST:
    - id: M1
      title: Use strict equality
      type: ast
      query: |
        (binary_expression
          operator: ["==" "!="] @violation)
      message: Use === or !== instead of == or !=
```

### Compiler Updates

Update the check parser to handle `type: ast`:

```python
def parse_check(check_data: dict) -> dict:
    """Parse a check definition from YAML."""

    check_type = check_data.get('type', 'grep')

    check = {
        'id': check_data['id'],
        'title': check_data['title'],
        'severity': None,  # Set by caller based on section
        'type': check_type,
        'message': check_data.get('message', check_data['title']),
    }

    if check_type == 'grep':
        if 'pattern' not in check_data:
            raise ValueError(f"Check {check['id']}: grep checks require 'pattern'")
        check['pattern'] = check_data['pattern']

    elif check_type == 'ast':
        if 'query' not in check_data:
            raise ValueError(f"Check {check['id']}: ast checks require 'query'")
        check['query'] = check_data['query']

    else:
        raise ValueError(f"Check {check['id']}: unknown type '{check_type}'")

    # Provenance (optional)
    if 'provenance' in check_data:
        check['provenance'] = check_data['provenance']

    return check
```

### Template File

Create `.flight/templates/ast-check-example.flight`:

```yaml
# AST Check Example Template
# This shows how to write tree-sitter query-based checks

domain: example-ast
version: "1.0.0"
language: javascript
file_patterns:
  - "**/*.js"
  - "**/*.mjs"

checks:
  NEVER:
    # AST-based check - no false positives from comments/strings
    - id: N1
      title: No eval()
      type: ast
      query: |
        (call_expression
          function: (identifier) @match
          (#eq? @match "eval"))
      message: |
        eval() executes arbitrary code and is a security risk.
        Use JSON.parse() for data, Function constructor for dynamic code.
      provenance:
        last_verified: "2025-01-15"
        confidence: high

  MUST:
    # Pattern matching with predicates
    - id: M1
      title: Use strict equality
      type: ast
      query: |
        (binary_expression
          operator: ["==" "!="] @violation)
      message: Use === or !== for comparisons to avoid type coercion

    # Multiple node types in one query
    - id: M2
      title: No console in production
      type: ast
      query: |
        (call_expression
          function: (member_expression
            object: (identifier) @obj
            property: (property_identifier) @prop)
          (#eq? @obj "console"))
      message: Remove console.* calls before production

  SHOULD:
    # Grep still works for simple patterns
    - id: S1
      title: Prefer const
      type: grep
      pattern: '\blet\s+\w+\s*='
      message: Consider using const for variables that aren't reassigned
```

### Query Syntax Reference

Document these patterns in the template:

```scheme
; Basic node matching
(identifier) @match

; Node with specific value
(identifier) @match (#eq? @match "eval")

; Child node relationships
(call_expression
  function: (identifier) @fn)

; Multiple alternatives
(binary_expression
  operator: ["==" "!=" "<" ">"] @op)

; Negation
(identifier) @id (#not-eq? @id "undefined")

; Regex matching
(string) @str (#match? @str "password")

; Named captures (use @match or @violation)
(call_expression
  function: (identifier) @violation
  (#eq? @violation "eval"))
```

## Validation
Run after implementing:
```bash
# Test with example template
python3 .flight/bin/flight-domain-compile.py .flight/templates/ast-check-example.flight

# Check generated JSON has queries
cat .flight/templates/ast-check-example.rules.json | grep -A5 '"type": "ast"'

# Verify backward compatibility
python3 .flight/bin/flight-domain-compile.py .flight/domains/code-hygiene.flight
.flight/validate-all.sh
```
