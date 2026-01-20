# PRD: Flight AST Validation System

## Problem Statement

The current Flight validation system uses per-domain bash+grep validators. Each `.flight` domain file compiles to both documentation (`.md`) and a bash validator (`.validate.sh`). This architecture has fundamental limitations:

1. **False positives**: Grep matches text, not structure. Patterns match inside strings, comments, and template literals.
2. **Duplicated logic**: Every validator reinvents file discovery, output formatting, and counting.
3. **Hard to maintain**: Complex bash escaping for patterns. Debugging is painful.
4. **Pattern limitations**: Some checks are impossible with regex (e.g., "find `var` declarations but not inside strings").

**Example false positive:**
```javascript
// This grep pattern for var declarations:
grep -En '\bvar\s+\w+\s*='

// Incorrectly matches ALL of these:
const s = "var x = 1";      // string literal - FALSE POSITIVE
// var x = 1                 // comment - FALSE POSITIVE
`template var x = ${y}`      // template literal - FALSE POSITIVE
```

AST-based parsing understands code structure and only matches actual `var` declarations.

## Target Users

- **Primary**: Flight maintainers and domain authors
- **Secondary**: Developers using Flight for code quality validation
- **Tertiary**: CI/CD pipelines running Flight validation

## Core Value Proposition

Replace N per-domain validators with 1 universal AST-based linter that consumes declarative rule files. Separation of concerns: knowledge in `.flight`, enforcement in `flight-lint`.

## Success Metrics

- **Accuracy**: Zero false positives from strings/comments (currently ~5-10% false positive rate)
- **Maintainability**: 1 tool + N rule files vs N validator scripts
- **Migration**: Convert 3+ domains to AST-based validation
- **Performance**: Sub-second validation for typical projects

## Competitive Landscape

| Tool | Approach | Limitation |
|------|----------|------------|
| ESLint | AST-based, JavaScript rules | Language-specific, rules in JS code |
| Semgrep | Pattern matching, multi-language | Requires learning Semgrep syntax |
| grep-based validators | Text matching | False positives, no structure awareness |

**Flight AST differentiator**: Rules defined in declarative YAML (`.flight` files), compiled to JSON. No code in rule definitions. Same `.flight` file generates docs AND rules.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌────────────────────┐
│  api.flight     │     │  bash.flight    │     │  javascript.flight │
└────────┬────────┘     └────────┬────────┘     └────────┬───────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      flight-domain-compile                           │
│                                                                      │
│   Reads .flight YAML → Outputs .md (docs) + .rules.json (rules)      │
└──────────────────────────────────────────────────────────────────────┘
         │                       │                       │
         ├──► api.md             ├──► bash.md            ├──► javascript.md
         └──► api.rules.json     └──► bash.rules.json    └──► javascript.rules.json
                                          │
                                          ▼
                               ┌─────────────────────┐
                               │    flight-lint      │
                               │                     │
                               │  • Reads .rules.json│
                               │  • tree-sitter AST  │
                               │  • Any language     │
                               │  • Unified output   │
                               └─────────────────────┘
```

## Technical Constraints

- **Node.js**: `flight-lint` will be a Node.js CLI tool (tree-sitter has excellent Node bindings)
- **tree-sitter**: Using tree-sitter for AST parsing (production-ready, fast, multi-language)
- **Backward compatibility**: Existing `.validate.sh` scripts continue to work during migration
- **Incremental adoption**: Domains can migrate one at a time from grep to AST

## Out of Scope (V1)

- Auto-fix capabilities (`--fix` flag)
- VS Code extension
- GitHub Action packaging
- Watch mode
- Custom reporter plugins
- Performance profiling
- Web-based UI

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| tree-sitter | ^0.25.0 | Core parsing library |
| tree-sitter-javascript | ^0.23.x | JavaScript/JSX parser |
| tree-sitter-typescript | ^0.23.x | TypeScript/TSX parser |
| tree-sitter-bash | ^0.23.x | Bash parser |
| fast-glob | ^3.3.x | File discovery |
| chalk | ^5.x | Terminal colors |

## Research Sources

- [tree-sitter npm package](https://www.npmjs.com/package/tree-sitter) - v0.25.0, production ready
- [tree-sitter query syntax](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html) - S-expression patterns
- [ESLint custom rules](https://eslint.org/docs/latest/extend/custom-rules) - Architecture reference
