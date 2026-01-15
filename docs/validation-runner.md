# Flight Validation Runner

The Flight validation runner (`validate-all.sh`) automatically detects which domain validators to run based on file types in your project.

---

## Quick Start

```bash
# Run validation on current directory
.flight/validate-all.sh

# Run on specific directories
.flight/validate-all.sh src lib

# Run on specific paths
.flight/validate-all.sh packages/app packages/core
```

---

## How It Works

### 1. Config-Driven Mode (Recommended)

When `.flight/flight.json` exists, the runner uses it to determine which domains to validate:

```json
{
  "enabled_domains": [
    "code-hygiene",
    "typescript",
    "react",
    "nextjs"
  ]
}
```

**To set up:**
```bash
/flight-scan
```

This command scans your project and generates `flight.json` with detected domains.

### 2. Legacy Mode (Fallback)

If no `flight.json` exists, the runner falls back to `code-hygiene` only and suggests running `/flight-scan`.

---

## File Discovery & Exclusions

### The Exclusions System

Flight uses a centralized exclusions system to avoid scanning build artifacts, dependencies, and generated files.

**Single Source of Truth:** `.flight/exclusions.sh`

```bash
FLIGHT_EXCLUDE_DIRS=(
    # Package managers
    "node_modules"
    "vendor"
    ".venv"
    "venv"

    # Build outputs
    "dist"
    "build"
    "target"
    "obj"
    "out"
    ".output"
    ".next"
    ".turbo"
    ".nuxt"
    ".svelte-kit"

    # VCS/IDE
    ".git"
    ".idea"
    ".vscode"

    # Test/Coverage
    "coverage"
    ".nyc_output"
    "__pycache__"
    ".pytest_cache"
    ".tox"
    ".nox"

    # Cache
    ".cache"
    ".parcel-cache"
    ".webpack"
    ".rollup.cache"

    # Infrastructure
    ".terraform"
    ".serverless"

    # Flight internal
    ".flight/examples"
)
```

### Covered Project Types

| Language/Framework | Excluded Directories |
|--------------------|---------------------|
| **JavaScript/TypeScript** | `node_modules`, `dist`, `build`, `.next`, `.turbo`, `.nuxt`, `.svelte-kit`, `.output` |
| **Bundlers** | `.parcel-cache`, `.webpack`, `.rollup.cache` |
| **Python** | `.venv`, `venv`, `__pycache__`, `.pytest_cache`, `.tox`, `.nox` |
| **Go** | `vendor` |
| **Rust** | `target` |
| **C/C++** | `obj`, `out` |
| **Test Coverage** | `coverage`, `.nyc_output` |
| **Infrastructure** | `.terraform`, `.serverless` |

### Adding Custom Exclusions

To add project-specific exclusions, extend the `FLIGHT_EXCLUDE_DIRS` array before sourcing:

```bash
# In your script before sourcing exclusions.sh
FLIGHT_EXCLUDE_DIRS+=("my-custom-dir" "another-dir")
source .flight/exclusions.sh
```

Or modify `.flight/exclusions.sh` directly for permanent changes.

---

## Helper Functions

The exclusions system provides several helper functions:

### `flight_get_files`

Get files matching patterns with exclusions applied:

```bash
source .flight/exclusions.sh

# Get all TypeScript files
FILES=$(flight_get_files "*.ts" "*.tsx")

# Get files from specific directory
FLIGHT_SEARCH_DIR="src" FILES=$(flight_get_files "*.js")
```

### `flight_is_excluded`

Check if a path should be excluded:

```bash
source .flight/exclusions.sh

if flight_is_excluded "node_modules/lodash/index.js"; then
    echo "Excluded"
fi
```

### `flight_filter_excluded`

Filter a list of files via stdin:

```bash
find . -name "*.ts" | flight_filter_excluded
```

### `flight_build_find_not_paths`

Generate find exclusion arguments dynamically:

```bash
source .flight/exclusions.sh

# Use in find command
exclude_args=$(flight_build_find_not_paths)
eval "find . -type f -name '*.ts' $exclude_args"
```

---

## Output Format

The validation runner outputs structured results:

```
═══════════════════════════════════════════
       Flight Validation Runner
═══════════════════════════════════════════
Mode: Config-driven (flight.json)

Scanning: .
Total files: 42

▶ Running code-hygiene validator...
✓ code-hygiene: PASS (Pass: 15, Fail: 0, Warn: 2)

▶ Running typescript validator...
✓ typescript: PASS (Pass: 8, Fail: 0, Warn: 0)

═══════════════════════════════════════════
       Validation Summary
═══════════════════════════════════════════
  Total Checks Passed: 23
  Total Checks Failed: 0
  Total Warnings:      2

✓ ALL VALIDATIONS PASSED
═══════════════════════════════════════════
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All validations passed |
| 1 | One or more validations failed |

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Flight Validation
  run: .flight/validate-all.sh
```

### Pre-commit Hook

```bash
#!/bin/bash
.flight/validate-all.sh || exit 1
```

### npm Scripts

```json
{
  "scripts": {
    "validate": ".flight/validate-all.sh",
    "preflight": "npm run validate && npm run lint"
  }
}
```

---

## Troubleshooting

### "No flight.json found"

Run `/flight-scan` to detect domains and generate the config file.

### "No code files found"

Check that:
1. You're running from the project root
2. Source files aren't in excluded directories
3. File extensions match expected patterns (`.ts`, `.js`, `.py`, etc.)

### Too Many Files Being Scanned

If validation is scanning build artifacts:
1. Check that the relevant exclusion exists in `FLIGHT_EXCLUDE_DIRS`
2. Add missing exclusions to `.flight/exclusions.sh`
3. Re-run validation

### Custom Directory Structure

For non-standard project layouts, specify paths explicitly:

```bash
.flight/validate-all.sh src packages/*/src
```

---

## Architecture

```
.flight/
├── flight.json           # Enabled domains config
├── validate-all.sh       # Main validation runner
├── exclusions.sh         # Centralized exclusions (single source of truth)
└── domains/
    ├── code-hygiene.validate.sh
    ├── typescript.validate.sh
    └── ...
```

**Data Flow:**

```
validate-all.sh
    │
    ├── Sources exclusions.sh
    │   └── Provides: FLIGHT_EXCLUDE_DIRS[], flight_get_files(), etc.
    │
    ├── Reads flight.json (if exists)
    │   └── Gets: enabled_domains[]
    │
    ├── Collects files using flight_get_files()
    │   └── Applies: FLIGHT_EXCLUDE_DIRS exclusions
    │
    └── Runs: domains/{domain}.validate.sh for each enabled domain
```

---

## Related Documentation

- [README.md](../README.md) - Main Flight documentation
- [.flight/FLIGHT.md](../.flight/FLIGHT.md) - Core methodology
- [Creating Custom Domains](../README.md#creating-custom-domains) - Domain YAML format
