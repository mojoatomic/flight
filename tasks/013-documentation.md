# Task 013: Documentation Update

## Depends On
- 012-workflow-integration

## Delivers
- Updated `.flight/FLIGHT.md` with AST validation docs
- Rule authoring guide
- Migration guide from grep to AST
- Query pattern reference

## NOT In Scope
- Video tutorials (future enhancement)
- External documentation site (future enhancement)
- API documentation generation (future enhancement)

## Acceptance Criteria
- [ ] `FLIGHT.md` documents the new AST validation system
- [ ] Query authoring guide with examples
- [ ] Migration guide for existing domains
- [ ] Troubleshooting section for common issues
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)

## Context

Documentation ensures the AST validation system is usable by the team. This includes:
- How to write tree-sitter queries
- How to migrate existing grep rules
- How to troubleshoot query issues

## Technical Notes

### FLIGHT.md Updates

Add these sections to `.flight/FLIGHT.md`:

```markdown
## AST-Based Validation (flight-lint)

Flight now supports AST-based validation using tree-sitter. This eliminates false positives from code in comments and strings.

### Quick Start

```bash
# Build flight-lint
cd flight-lint && npm install && npm run build && cd ..

# Run validation
./flight-lint/bin/flight-lint --auto .
```

### How It Works

1. `.flight` files define rules (grep or AST)
2. `flight-domain-compile` generates `.rules.json` files
3. `flight-lint` runs tree-sitter queries against source code
4. Results include file, line, column for each violation

### Rule Types

| Type | Syntax | False Positives | Use When |
|------|--------|-----------------|----------|
| `grep` | Regex pattern | Possible | Simple text patterns |
| `ast` | S-expression query | None | Code structure patterns |

### AST Check Format

```yaml
checks:
  NEVER:
    - id: N1
      title: No eval()
      type: ast
      query: |
        (call_expression
          function: (identifier) @violation
          (#eq? @violation "eval"))
      message: eval() executes arbitrary code
```

### Output Formats

- `--format pretty` - Colored terminal output (default)
- `--format json` - Machine-readable JSON
- `--format sarif` - GitHub/VS Code integration
```

### Query Authoring Guide

Create `.flight/docs/query-authoring.md`:

```markdown
# tree-sitter Query Authoring Guide

## Basics

tree-sitter queries use S-expression (Lisp-like) syntax to match AST nodes.

### Simple Node Match

```scheme
; Match any identifier
(identifier) @match
```

### Node with Value Predicate

```scheme
; Match identifier named "eval"
(identifier) @match (#eq? @match "eval")
```

### Parent-Child Relationships

```scheme
; Match call to eval()
(call_expression
  function: (identifier) @fn
  (#eq? @fn "eval"))
```

### Field Names

Use `:` to specify named fields:

```scheme
; Match left side of assignment
(assignment_expression
  left: (member_expression) @target)
```

### Multiple Alternatives

```scheme
; Match == or !=
(binary_expression
  operator: ["==" "!="] @op)
```

### Predicates

| Predicate | Purpose | Example |
|-----------|---------|---------|
| `#eq?` | Exact match | `(#eq? @name "eval")` |
| `#not-eq?` | Negation | `(#not-eq? @name "undefined")` |
| `#match?` | Regex match | `(#match? @str "password")` |
| `#not-match?` | Regex negation | `(#not-match? @fn "^_")` |

### Capture Names

Use `@violation` or `@match` as capture names - these are what flight-lint reports.

## Common Patterns

### Function Call

```scheme
; Direct call: foo()
(call_expression
  function: (identifier) @fn
  (#eq? @fn "functionName"))

; Method call: obj.method()
(call_expression
  function: (member_expression
    object: (identifier) @obj
    property: (property_identifier) @method)
  (#eq? @method "methodName"))
```

### Property Access

```scheme
; obj.property
(member_expression
  property: (property_identifier) @prop
  (#eq? @prop "propertyName"))
```

### Assignment

```scheme
; target = value
(assignment_expression
  left: (identifier) @target
  (#eq? @target "variableName"))
```

### Declaration

```scheme
; var x = ...
(variable_declaration
  kind: "var") @violation

; const x = ...
(lexical_declaration
  kind: "const")
```

### Binary Operation

```scheme
; a == b
(binary_expression
  operator: "==" @op)
```

## Debugging Queries

### tree-sitter Playground

Use the online playground to test queries:
https://tree-sitter.github.io/tree-sitter/playground

### Print AST

```bash
# View AST for a file
npx tree-sitter parse file.js
```

### Common Mistakes

1. **Wrong node type**: Check exact node names in tree-sitter grammar
2. **Missing capture**: Always include `@violation` or `@match`
3. **Case sensitivity**: Node types are case-sensitive
4. **Field vs child**: Use `:` for named fields
```

### Migration Guide

Create `.flight/docs/migration-guide.md`:

```markdown
# Migrating from Grep to AST Validation

## Overview

Converting grep-based rules to AST-based rules eliminates false positives from:
- Code in comments
- Code in strings
- Similar-but-different patterns

## Step-by-Step Migration

### 1. Identify Rule Purpose

What code pattern should this rule match?

**Grep rule:**
```yaml
- id: N1
  title: No eval()
  pattern: 'eval\s*\('
  message: Don't use eval
```

**Purpose:** Match `eval()` function calls

### 2. Find AST Structure

Use tree-sitter playground to see how the pattern appears in the AST:

```javascript
eval("code")
```

AST:
```
(program
  (expression_statement
    (call_expression
      function: (identifier)  <-- "eval"
      arguments: (arguments
        (string)))))
```

### 3. Write Query

```scheme
(call_expression
  function: (identifier) @violation
  (#eq? @violation "eval"))
```

### 4. Test with Fixtures

Create positive (should match) and negative (should not match) test cases:

**Positive:**
```javascript
eval("code");
```

**Negative:**
```javascript
// eval("in comment")
"eval() in string"
evaluation("different function")
```

### 5. Update .flight File

```yaml
- id: N1
  title: No eval()
  type: ast  # Changed from grep
  query: |   # Changed from pattern
    (call_expression
      function: (identifier) @violation
      (#eq? @violation "eval"))
  message: Don't use eval
```

### 6. Recompile and Validate

```bash
python3 .flight/bin/flight-domain-compile.py domain.flight
./flight-lint/bin/flight-lint domain.rules.json fixtures/
```

## Common Migrations

### Simple Function Call

**Grep:** `functionName\s*\(`
**AST:**
```scheme
(call_expression
  function: (identifier) @violation
  (#eq? @violation "functionName"))
```

### Property Assignment

**Grep:** `\.innerHTML\s*=`
**AST:**
```scheme
(assignment_expression
  left: (member_expression
    property: (property_identifier) @prop)
  (#eq? @prop "innerHTML"))
```

### Variable Declaration

**Grep:** `\bvar\s+`
**AST:**
```scheme
(variable_declaration
  kind: "var") @violation
```

## When to Keep Grep

Some rules work better as grep:

- Text-based patterns (comments, strings intentionally)
- Patterns not represented in AST (formatting, whitespace)
- Simple presence checks across file types
```

### Troubleshooting Guide

Add to FLIGHT.md or separate doc:

```markdown
## Troubleshooting

### Query Not Matching Expected Code

1. **Verify AST structure**: Use `tree-sitter parse file.js`
2. **Check node types**: Names are case-sensitive and grammar-specific
3. **Test in playground**: https://tree-sitter.github.io/tree-sitter/playground

### Too Many Matches

1. **Add predicates**: Use `#eq?` or `#match?` to filter
2. **Check capture name**: Only `@violation` and `@match` are reported
3. **Narrow the pattern**: Be more specific about context

### Performance Issues

1. **Avoid broad patterns**: `(identifier)` matches everything
2. **Use specific starting nodes**: Start from the most specific node
3. **Limit file scope**: Use file_patterns in .flight

### JSON Parse Errors

1. **Check YAML syntax**: Multi-line queries need `|`
2. **Escape special characters**: Use YAML escaping rules
3. **Validate JSON**: `cat rules.json | python3 -m json.tool`
```

## Validation
Run after implementing:
```bash
# Check documentation renders correctly
# (Manual check in markdown preview)

# Verify links work
grep -r "\.md" .flight/docs/ | head -20

# Run overall validation
.flight/validate-all.sh
```
