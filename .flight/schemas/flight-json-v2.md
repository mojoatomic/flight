# flight.json Schema v2

## Overview

Schema v2 adds explicit source/test file categorization to enable different validation rules for different file types.

## Version Detection

- **v1**: No `version` field, or `version: "1"`
- **v2**: Has `version: "2"`

Validators MUST check for `version` field and handle both schemas.

## Schema v2

```json
{
  "version": "2",
  "generated": "2026-01-25T12:00:00Z",
  "scan_root": ".",

  "paths": {
    "source": ["src", "lib", "app", "packages/*/src"],
    "test": ["tests", "__tests__", "e2e", "**/*.test.ts", "**/*.spec.ts"],
    "exclude": ["scripts", "tooling", "docs", "*.config.*"]
  },

  "domains": {
    "source": ["code-hygiene", "typescript", "react"],
    "test": ["testing"]
  },

  "detection_log": {
    "code-hygiene": "always enabled",
    "typescript": "found *.ts files in src/",
    "react": "package.json: react",
    "testing": "found test files"
  }
}
```

## Field Definitions

### `version` (required for v2)
- Type: `string`
- Values: `"1"` | `"2"`
- Default: `"1"` if missing (backwards compatibility)

### `generated` (required)
- Type: `string` (ISO 8601 timestamp)
- Purpose: Track when config was generated

### `scan_root` (required)
- Type: `string`
- Purpose: Root directory that was scanned
- Default: `"."`

### `paths` (required for v2)
- Type: `object`
- Purpose: Categorize files for different validation rules

#### `paths.source`
- Type: `string[]`
- Purpose: Directories/patterns containing source code
- Default: `["src", "lib", "app"]`
- Behavior: Files here get validated with source domains

#### `paths.test`
- Type: `string[]`
- Purpose: Directories/patterns containing test files
- Default: Uses `FLIGHT_TEST_DIRS` + `FLIGHT_TEST_FILE_PATTERNS` from exclusions.sh
- Behavior: Files here get validated with test domains only
- Note: Supports both directory patterns (`tests/`) and file patterns (`**/*.test.ts`)

#### `paths.exclude`
- Type: `string[]`
- Purpose: Additional exclusions beyond .flightignore
- Default: `[]`
- Behavior: Files here are completely skipped

### `domains` (required for v2)
- Type: `object`
- Purpose: Map file categories to domains

#### `domains.source`
- Type: `string[]`
- Purpose: Domains to run on source files
- Default: `["code-hygiene"]` + detected domains

#### `domains.test`
- Type: `string[]`
- Purpose: Domains to run on test files
- Default: `["testing"]`

### `detection_log` (optional)
- Type: `object`
- Purpose: Record why each domain was enabled
- Keys: Domain names
- Values: Detection reason strings

## Migration from v1

### v1 Schema (for reference)
```json
{
  "generated": "2026-01-15T12:00:00Z",
  "scan_root": ".",
  "enabled_domains": ["code-hygiene", "typescript", "react"],
  "detection_log": { ... }
}
```

### Automatic v1 → v2 Interpretation

When validate-all.sh encounters v1:
1. All files are treated as source files
2. `enabled_domains` → `domains.source`
3. `domains.test` defaults to `["testing"]` if `testing` was in `enabled_domains`
4. Test files detected via `flight_is_test_file()` from exclusions.sh

### Manual Migration

Run `/flight-scan` to regenerate with v2 schema.

## Validator Behavior

### validate-all.sh Logic

```bash
if [[ "$VERSION" == "2" ]]; then
    # v2: Categorized validation
    for file in $(find_source_files); do
        for domain in "${DOMAINS_SOURCE[@]}"; do
            validate "$file" "$domain"
        done
    done

    for file in $(find_test_files); do
        for domain in "${DOMAINS_TEST[@]}"; do
            validate "$file" "$domain"
        done
    done
else
    # v1: All files get all domains
    for domain in "${ENABLED_DOMAINS[@]}"; do
        run_validator "$domain"
    done
fi
```

### flight-lint Integration

flight-lint receives the categorized file lists and applies appropriate rules:
- Source files: All severity levels enforced (MUST, SHOULD, NEVER)
- Test files: Only testing-specific rules

## Examples

### Minimal v2 Config
```json
{
  "version": "2",
  "generated": "2026-01-25T12:00:00Z",
  "scan_root": ".",
  "paths": {
    "source": ["src"],
    "test": [],
    "exclude": []
  },
  "domains": {
    "source": ["code-hygiene", "typescript"],
    "test": ["testing"]
  }
}
```

### Full v2 Config (Monorepo)
```json
{
  "version": "2",
  "generated": "2026-01-25T12:00:00Z",
  "scan_root": ".",
  "paths": {
    "source": [
      "packages/*/src",
      "apps/*/src",
      "libs/*"
    ],
    "test": [
      "packages/*/tests",
      "packages/*/__tests__",
      "**/*.test.ts",
      "**/*.spec.ts",
      "e2e"
    ],
    "exclude": [
      "scripts",
      "tooling",
      "docs",
      "*.config.*",
      "**/*.stories.tsx"
    ]
  },
  "domains": {
    "source": ["code-hygiene", "typescript", "react", "nextjs"],
    "test": ["testing"]
  },
  "detection_log": {
    "code-hygiene": "always enabled",
    "typescript": "found *.ts in packages/*/src",
    "react": "package.json: react",
    "nextjs": "package.json: next",
    "testing": "found test files"
  }
}
```

## Pattern Syntax

Paths support glob patterns:

| Pattern | Matches |
|---------|---------|
| `src` | `src/` directory |
| `src/**/*.ts` | All .ts files under src/ |
| `**/*.test.ts` | All .test.ts files anywhere |
| `packages/*/src` | src/ in any package |
| `*.config.*` | Any config file at root |

## Design Decisions

### Why `paths.test` includes file patterns?

Test files can be:
1. In dedicated directories (`tests/`, `__tests__/`)
2. Co-located with source (`src/utils.test.ts`)

Supporting both patterns ensures comprehensive detection.

### Why separate `domains.source` and `domains.test`?

Different rules apply:
- Source: Full `code-hygiene`, `typescript`, etc.
- Test: Only `testing` domain (allows console.log, any types, etc.)

### Why keep `paths.exclude` when .flightignore exists?

- `.flightignore`: Project-specific, human-edited
- `paths.exclude`: Auto-detected or scan-time overrides, machine-managed

Both work together. `.flightignore` is always respected. `paths.exclude` provides additional exclusions specific to the scanned config.
