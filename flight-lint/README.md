# flight-lint

AST-based linting for Flight domain rules using tree-sitter.

## After Running update.sh

When `update.sh` copies flight-lint to your project, you must rebuild it:

```bash
cd flight-lint
npm install
npm run build
```

This installs the tree-sitter language packages (TypeScript, JavaScript, Python, Go, Rust, C) and compiles the TypeScript source.

## Manual Build

```bash
cd flight-lint
npm install
npm run build
```

## Usage

```bash
# Auto-discover rules from .flight/domains/*.rules.json
./bin/flight-lint --auto

# With severity filter
./bin/flight-lint --auto --severity SHOULD

# Specific rules file
./bin/flight-lint --rules path/to/rules.json src/
```

## How It Works

1. Reads `.rules.json` files from `.flight/domains/`
2. Finds rules with `"type": "ast"`
3. Parses source files with tree-sitter
4. Runs tree-sitter queries to detect violations
5. Reports errors/warnings based on severity

## Supported Languages

- TypeScript/JavaScript (`.ts`, `.tsx`, `.js`, `.jsx`)
- Python (`.py`)
- Go (`.go`)
- Rust (`.rs`)
- C (`.c`, `.h`)
