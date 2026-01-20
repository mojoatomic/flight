# Task 012: Workflow Integration

## Depends On
- 005-query-execution
- 011-javascript-validation

## Delivers
- `flight-lint --auto` for automatic rule discovery
- Integration with `npm run preflight`
- CI/CD integration guide
- VS Code integration via SARIF

## NOT In Scope
- Watch mode (future enhancement)
- IDE plugins (future enhancement)
- Custom rule authoring guide (Task 013)

## Acceptance Criteria
- [ ] `flight-lint --auto .` discovers and runs all `.rules.json` files
- [ ] `npm run preflight` includes `flight-lint`
- [ ] CI workflow example documented
- [ ] SARIF output integrates with GitHub code scanning
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)

## Context

This task integrates `flight-lint` into the Flight workflow. The goal is seamless developer experience:
1. Run `npm run preflight` → validates everything
2. CI runs the same checks → consistent enforcement
3. GitHub shows inline annotations → visible feedback

## Technical Notes

### Auto-Discovery Mode

Add `--auto` flag to `flight-lint`:

```typescript
// In src/cli.ts

program
  .option('--auto', 'Auto-discover .rules.json files in .flight/domains/')

async function main() {
  const options = program.opts();

  let rulesFiles: string[];

  if (options.auto) {
    rulesFiles = await discoverRulesFiles(options.basePath || '.');
  } else {
    rulesFiles = program.args.filter(arg => arg.endsWith('.rules.json'));
  }

  // ... rest of implementation
}

async function discoverRulesFiles(basePath: string): Promise<string[]> {
  const patterns = [
    '.flight/domains/*.rules.json',
    '.flight/*.rules.json',
  ];

  const files: string[] = [];
  for (const pattern of patterns) {
    const matches = await fg(pattern, {
      cwd: basePath,
      absolute: true,
    });
    files.push(...matches);
  }

  return files;
}
```

### npm run preflight Integration

Update project's `package.json`:

```json
{
  "scripts": {
    "preflight": "npm run validate && npm run lint && npm run flight-lint",
    "flight-lint": "flight-lint --auto .",
    "validate": ".flight/validate-all.sh"
  }
}
```

Or for projects without flight-lint installed globally:

```json
{
  "scripts": {
    "preflight": "npm run validate && npm run lint && npx flight-lint --auto .",
    "validate": ".flight/validate-all.sh"
  }
}
```

### CI/CD Integration

**GitHub Actions Workflow** (`.github/workflows/flight-lint.yml`):

```yaml
name: Flight Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build flight-lint
        working-directory: flight-lint
        run: |
          npm ci
          npm run build

      - name: Run Flight Lint
        run: |
          ./flight-lint/bin/flight-lint --auto . --format sarif > flight-lint-results.sarif

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: flight-lint-results.sarif
        if: always()
```

### VS Code Integration

SARIF output enables VS Code integration via the SARIF Viewer extension:

1. Install "SARIF Viewer" extension
2. Run `flight-lint --format sarif > results.sarif`
3. Open `results.sarif` in VS Code
4. Navigate to issues with inline annotations

### Quick Start Script

Create `scripts/setup-flight-lint.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up flight-lint integration..."

# Check if flight-lint is built
if [ ! -f "flight-lint/bin/flight-lint" ]; then
    echo "Building flight-lint..."
    cd flight-lint
    npm install
    npm run build
    cd ..
fi

# Check if .rules.json files exist
RULES_COUNT=$(find .flight/domains -name "*.rules.json" 2>/dev/null | wc -l)
if [ "$RULES_COUNT" -eq 0 ]; then
    echo "No .rules.json files found. Compiling domains..."
    for flight_file in .flight/domains/*.flight; do
        if [ -f "$flight_file" ]; then
            python3 .flight/bin/flight-domain-compile.py "$flight_file"
        fi
    done
fi

# Add preflight script if not present
if ! grep -q '"preflight"' package.json 2>/dev/null; then
    echo "Adding preflight script to package.json..."
    # Use jq if available, otherwise provide manual instructions
    if command -v jq &> /dev/null; then
        jq '.scripts.preflight = "npm run lint && ./flight-lint/bin/flight-lint --auto ."' package.json > tmp.json && mv tmp.json package.json
    else
        echo "Please add to package.json scripts:"
        echo '  "preflight": "npm run lint && ./flight-lint/bin/flight-lint --auto ."'
    fi
fi

echo ""
echo "Setup complete! Run: npm run preflight"
```

### Exit Code Behavior

Ensure proper exit codes for CI:

```typescript
// In src/cli.ts

const exitCode = getExitCode(allResults);
process.exit(exitCode);

// Exit codes:
// 0 - No violations (or only warnings with --severity MUST)
// 1 - Violations found
// 2 - Configuration error (missing rules, invalid JSON)
```

### Error Handling

Handle missing rules files gracefully:

```typescript
if (rulesFiles.length === 0) {
  if (options.auto) {
    console.log('No .rules.json files found in .flight/domains/');
    console.log('Run: python3 .flight/bin/flight-domain-compile.py <domain>.flight');
    process.exit(0); // Not an error if --auto finds nothing
  } else {
    console.error('Error: No rules files specified');
    process.exit(2);
  }
}
```

## Validation
Run after implementing:
```bash
# Test auto-discovery
./flight-lint/bin/flight-lint --auto .

# Test SARIF output
./flight-lint/bin/flight-lint --auto . --format sarif > results.sarif
cat results.sarif | python3 -m json.tool | head -50

# Test preflight integration
npm run preflight

# Run validation
.flight/validate-all.sh
```
