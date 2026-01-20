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

---

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

---

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

---

## Advanced Patterns

### Matching Nested Structures

```scheme
; Match console.log specifically
(call_expression
  function: (member_expression
    object: (identifier) @obj
    property: (property_identifier) @prop)
  (#eq? @obj "console")
  (#eq? @prop "log")) @violation
```

### Using Regex Predicates

```scheme
; Match any variable starting with underscore
(variable_declarator
  name: (identifier) @name
  (#match? @name "^_"))
```

### Combining Multiple Conditions

```scheme
; Match ternary with boolean literals
(ternary_expression
  consequence: [(true) (false)]
  alternative: [(true) (false)]) @violation
```

---

## Language-Specific Notes

### JavaScript/TypeScript

- `variable_declaration` is for `var`
- `lexical_declaration` is for `let` and `const`
- Function expressions and arrow functions have different node types

### Finding Node Types

1. Parse sample code in the playground
2. Examine the AST structure
3. Note the exact node type names
4. Use those names in your queries
