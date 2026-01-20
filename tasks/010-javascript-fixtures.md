# Task 010: JavaScript Test Fixtures

## Depends On
- 009-javascript-queries

## Delivers
- Test fixtures in `fixtures/javascript/`
- Positive cases (should trigger violations)
- Negative cases (should NOT trigger - comments, strings)
- Edge cases for each rule

## NOT In Scope
- TypeScript fixtures (future enhancement)
- Integration with CI (Task 012)
- Automated fixture generation (future enhancement)

## Acceptance Criteria
- [ ] Each rule has positive test cases
- [ ] Each rule has negative test cases (false positive tests)
- [ ] Fixtures are documented with expected violations
- [ ] Running `flight-lint` on fixtures produces expected results
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- javascript.md

## Context

Test fixtures verify that tree-sitter queries work correctly. They include:
- **Positive cases**: Code that SHOULD trigger violations
- **Negative cases**: Code that should NOT trigger (comments, strings, similar-but-different patterns)

## Technical Notes

### Directory Structure

```
fixtures/
└── javascript/
    ├── README.md
    ├── positive/
    │   ├── eval.js
    │   ├── function-constructor.js
    │   ├── document-write.js
    │   ├── innerhtml.js
    │   ├── with-statement.js
    │   ├── equality.js
    │   ├── var-declaration.js
    │   └── string-concat.js
    ├── negative/
    │   ├── comments.js
    │   ├── strings.js
    │   └── similar-patterns.js
    └── expected/
        └── results.json
```

### Positive Test Cases

**`fixtures/javascript/positive/eval.js`**
```javascript
// N1: No eval() - These should all be flagged

// Direct eval call
const result1 = eval("1 + 1");

// Eval with variable
const code = "console.log('hello')";
eval(code);

// Eval in expression
const value = eval("Math.PI") * 2;

// Indirect eval (still flagged)
const evalFn = eval;
evalFn("code");
```

**`fixtures/javascript/positive/function-constructor.js`**
```javascript
// N2: No Function constructor - These should all be flagged

// Basic Function constructor
const fn1 = new Function("return 1");

// With arguments
const fn2 = new Function("a", "b", "return a + b");

// Assigned to variable
const MyFunc = Function;
const fn3 = new MyFunc("return 2");
```

**`fixtures/javascript/positive/document-write.js`**
```javascript
// N3: No document.write - These should all be flagged

// Basic document.write
document.write("<p>Hello</p>");

// document.writeln
document.writeln("<p>World</p>");

// With template literal
document.write(`<div>${content}</div>`);
```

**`fixtures/javascript/positive/innerhtml.js`**
```javascript
// N4: No innerHTML assignment - These should all be flagged

// Direct assignment
element.innerHTML = "<p>Content</p>";

// With user input (dangerous!)
div.innerHTML = userInput;

// Chained property access
document.getElementById("app").innerHTML = html;

// Using template literal
container.innerHTML = `<span>${data}</span>`;
```

**`fixtures/javascript/positive/equality.js`**
```javascript
// M1: Use strict equality - These should all be flagged

// Loose equality
if (a == b) {}
if (x == null) {}
if (y == undefined) {}

// Loose inequality
if (a != b) {}
if (x != 0) {}
```

**`fixtures/javascript/positive/var-declaration.js`**
```javascript
// M4: Use const/let over var - These should all be flagged

// Basic var
var x = 1;

// Multiple declarations
var a, b, c;

// In for loop
for (var i = 0; i < 10; i++) {}

// Function scope issues
function example() {
  var localVar = "value";
}
```

### Negative Test Cases (False Positive Prevention)

**`fixtures/javascript/negative/comments.js`**
```javascript
// These should NOT trigger violations - they're in comments

// eval("this is a comment")
// document.write("also a comment")
// innerHTML = "comment"
// var comment = "nope"
// if (a == b) comment

/*
 * Multi-line comment with violations:
 * eval("code")
 * document.write()
 * element.innerHTML = data
 */

/**
 * JSDoc with examples:
 * @example
 * // Don't do this:
 * eval(userInput)
 */
```

**`fixtures/javascript/negative/strings.js`**
```javascript
// These should NOT trigger violations - they're in strings

const str1 = "eval() is dangerous";
const str2 = 'document.write is deprecated';
const str3 = `innerHTML should not be used`;
const str4 = "var is old-school";
const str5 = "if (a == b) is loose equality";

// Even multi-line strings
const multiline = `
  This talks about eval() but doesn't call it.
  Same with document.write() and innerHTML.
`;

// Regex patterns (not actual code)
const pattern = /eval\(/;
const regex = new RegExp("document\\.write");
```

**`fixtures/javascript/negative/similar-patterns.js`**
```javascript
// These should NOT trigger violations - similar but different patterns

// Not eval() - different function name
evaluation("code");
evaluateExpression(input);

// Not document.write - different object
myDocument.write("text");
doc.write("output");

// Not innerHTML - different property
element.innerText = "safe";
element.textContent = "also safe";

// Not == - strict equality
if (a === b) {}
if (x !== y) {}

// Not var - const/let
const constVar = 1;
let letVar = 2;

// Not Function constructor - function declaration
function normalFunction() {}
const arrowFn = () => {};
```

### Expected Results

**`fixtures/javascript/expected/results.json`**
```json
{
  "positive": {
    "eval.js": {
      "expectedViolations": ["N1", "N1", "N1", "N1"],
      "lines": [4, 8, 11, 14]
    },
    "function-constructor.js": {
      "expectedViolations": ["N2", "N2", "N2"],
      "lines": [4, 7, 11]
    },
    "document-write.js": {
      "expectedViolations": ["N3", "N3", "N3"],
      "lines": [4, 7, 10]
    },
    "innerhtml.js": {
      "expectedViolations": ["N4", "N4", "N4", "N4"],
      "lines": [4, 7, 10, 13]
    },
    "equality.js": {
      "expectedViolations": ["M1", "M1", "M1", "M1", "M1"],
      "lines": [4, 5, 6, 9, 10]
    },
    "var-declaration.js": {
      "expectedViolations": ["M4", "M4", "M4", "M4"],
      "lines": [4, 7, 10, 14]
    }
  },
  "negative": {
    "comments.js": {
      "expectedViolations": [],
      "description": "All violations are in comments - should have zero matches"
    },
    "strings.js": {
      "expectedViolations": [],
      "description": "All violations are in string literals - should have zero matches"
    },
    "similar-patterns.js": {
      "expectedViolations": [],
      "description": "Similar but different patterns - should have zero matches"
    }
  }
}
```

### README.md

**`fixtures/javascript/README.md`**
```markdown
# JavaScript Test Fixtures

Test fixtures for validating tree-sitter queries in the JavaScript domain.

## Structure

- `positive/` - Files that SHOULD trigger violations
- `negative/` - Files that should NOT trigger violations (false positive tests)
- `expected/` - Expected results for validation

## Running Tests

```bash
# From project root
cd flight-lint
npm run build
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/positive/
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/negative/
```

## Adding New Tests

1. Add test file to appropriate directory
2. Update `expected/results.json`
3. Run validation to confirm expected behavior
```

## Validation
Run after implementing:
```bash
# Create fixtures directory
mkdir -p fixtures/javascript/{positive,negative,expected}

# Populate fixture files as shown above

# Test positive cases (should find violations)
cd flight-lint
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/positive/

# Test negative cases (should find ZERO violations)
./bin/flight-lint ../.flight/domains/javascript.rules.json ../fixtures/javascript/negative/

# Overall validation
.flight/validate-all.sh
```
