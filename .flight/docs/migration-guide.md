# Migrating from Grep to AST Validation

## Overview

Converting grep-based rules to AST-based rules eliminates false positives from:
- Code in comments
- Code in strings
- Similar-but-different patterns

---

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

---

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

### Method Call

**Grep:** `console\.log\s*\(`

**AST:**
```scheme
(call_expression
  function: (member_expression
    object: (identifier) @obj
    property: (property_identifier) @prop)
  (#eq? @obj "console")
  (#eq? @prop "log")) @violation
```

### Loose Equality

**Grep:** `[^=!]==[^=]`

**AST:**
```scheme
(binary_expression
  operator: ["==" "!="]) @violation
```

---

## When to Keep Grep

Some rules work better as grep:

- **Text-based patterns**: Comments, strings intentionally matched
- **Patterns not in AST**: Formatting, whitespace, indentation
- **Simple presence checks**: File-level patterns across many file types
- **Non-code files**: Configuration, documentation, data files

### Examples of Grep-Only Rules

```yaml
# Check for TODO comments (intentionally in comments)
- id: S1
  title: Resolve TODOs
  type: grep
  pattern: 'TODO|FIXME|HACK'
  message: Resolve before merging

# Check for hardcoded URLs
- id: N5
  title: No hardcoded production URLs
  type: grep
  pattern: 'https://prod\.'
  message: Use environment variables
```

---

## Migration Checklist

- [ ] Identify the code structure being matched
- [ ] Use tree-sitter playground to find AST node types
- [ ] Write query with appropriate capture (`@violation`)
- [ ] Test with positive cases (should match)
- [ ] Test with negative cases (should not match)
- [ ] Verify comments/strings no longer cause false positives
- [ ] Update .flight file with `type: ast` and `query:`
- [ ] Recompile with flight-domain-compile
- [ ] Run flight-lint to verify
