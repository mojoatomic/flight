---
name: flight-scan
description: Scan project and generate flight.json config for domain detection. Use when setting up Flight in a new project or after adding new technologies.
---

## ⚠️ EXECUTION RULES (MANDATORY)

1. **EXECUTE EACH STEP** - Do not skip steps based on "prior context"
2. **USE TOOLS** - You MUST call Read/Bash tools, not recall from memory
3. **SHOW WORK** - Each step must produce visible tool output
4. **NO SHORTCUTS** - "I already read this" is NOT acceptable

### Anti-Patterns (DO NOT DO THESE)
- ❌ "I already read the domain files earlier"
- ❌ "From earlier analysis..."
- ❌ Summarizing steps without executing them
- ❌ Claiming knowledge from "this conversation"

---

# /flight-scan

Scan a project to detect which Flight domains apply and generate `.flight/flight.json` v2 config with source/test categorization.

## Usage

```
/flight-scan [--v1]
```

## Arguments

| Argument | Description |
|----------|-------------|
| (none) | Generate v2 config with source/test categorization |
| `--v1` | Generate legacy v1 config (no categorization) |

---

## Process

### 1. Detect Source Directories

Check for common source directory patterns:

```bash
# Check for standard source directories
for dir in src lib app packages apps; do
    [[ -d "$dir" ]] && echo "Found source dir: $dir"
done

# Check for monorepo patterns
ls -d packages/*/src apps/*/src 2>/dev/null
```

**Source directory priority:**
1. `src/` (most common)
2. `lib/` (libraries)
3. `app/` (Next.js app router)
4. `packages/*/src` (monorepo)
5. `apps/*/src` (monorepo)

If no standard dirs found, use `.` (project root) as source.

### 2. Detect Test Directories and Patterns

Check for test directories and co-located test files:

```bash
# Test directories
for dir in tests test __tests__ e2e spec; do
    [[ -d "$dir" ]] && echo "Found test dir: $dir"
done

# Co-located test files (check if any exist)
find . -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" \
    -not -path "*/node_modules/*" | head -1
```

**Test patterns detected:**
- Directories: `tests/`, `test/`, `__tests__/`, `e2e/`, `spec/`
- Files: `**/*.test.ts`, `**/*.test.tsx`, `**/*.spec.ts`, `**/*.spec.tsx`

### 3. List Available Domains

```bash
ls .flight/domains/*.flight
```

### 4. For Each Domain, Check File Patterns

Read each `.flight` file and extract the `file_patterns` section:

```yaml
# Example from typescript.flight
file_patterns:
  - "**/*.ts"
  - "**/*.tsx"
```

For each pattern, check if matching files exist (excluding standard directories):

```bash
find . -name "*.ts" -not -path "*/node_modules/*" -not -path "*/dist/*" \
    -not -path "*/build/*" -not -path "*/.next/*" -not -path "*/.git/*" | head -1
```

If files found → domain is enabled for source.

### 5. Check package.json for Dependencies

Read `package.json` and check for these dependency mappings:

| package.json dependency | Domain | Category |
|------------------------|--------|----------|
| `twilio` | sms-twilio | source |
| `@prisma/client`, `prisma` | prisma | source |
| `@clerk/nextjs`, `@clerk/clerk-react` | clerk | source |
| `@supabase/supabase-js`, `@supabase/ssr` | supabase | source |
| `next` | nextjs | source |
| `react`, `react-dom` | react | source |
| `typescript` | typescript | source |
| `vitest`, `jest`, `mocha`, `@testing-library/*` | testing | test |

### 6. Categorize Domains

- **Source domains**: `code-hygiene` (always) + detected domains
- **Test domains**: `testing` (if test framework detected)

### 7. Write flight.json v2

Write the results to `.flight/flight.json`:

```json
{
  "version": "2",
  "generated": "2026-01-25T12:00:00Z",
  "scan_root": ".",
  "paths": {
    "source": ["src"],
    "test": ["tests", "__tests__", "**/*.test.ts", "**/*.spec.ts"],
    "exclude": []
  },
  "domains": {
    "source": ["code-hygiene", "typescript", "react"],
    "test": ["testing"]
  },
  "detection_log": {
    "code-hygiene": "always enabled",
    "typescript": "found *.ts files",
    "react": "package.json: react",
    "testing": "package.json: vitest"
  }
}
```

### 8. Output Summary

Print a summary of detected configuration:

```
Flight Scan Complete (v2)
=========================

Source paths:
  - src/

Test paths:
  - tests/
  - **/*.test.ts
  - **/*.spec.ts

Source domains: code-hygiene, typescript, react
Test domains: testing

Detection log:
  code-hygiene: always enabled
  typescript: found *.ts files in src/
  react: package.json: react
  testing: package.json: vitest

Written to: .flight/flight.json
```

---

## Output: flight.json v2 Schema

```json
{
  "version": "2",
  "generated": "[ISO timestamp]",
  "scan_root": ".",
  "paths": {
    "source": ["src", "lib", "..."],
    "test": ["tests", "**/*.test.ts", "..."],
    "exclude": ["scripts", "docs", "..."]
  },
  "domains": {
    "source": ["code-hygiene", "typescript", "..."],
    "test": ["testing"]
  },
  "detection_log": {
    "[domain]": "[detection reason]"
  }
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version (`"2"`) |
| `generated` | string | ISO 8601 timestamp |
| `scan_root` | string | Directory scanned |
| `paths.source` | string[] | Source code directories |
| `paths.test` | string[] | Test directories and patterns |
| `paths.exclude` | string[] | Additional exclusions |
| `domains.source` | string[] | Domains for source files |
| `domains.test` | string[] | Domains for test files |
| `detection_log` | object | Why each domain was enabled |

---

## Legacy v1 Output (--v1 flag)

When `--v1` is specified, output the legacy format:

```json
{
  "generated": "[ISO timestamp]",
  "scan_root": ".",
  "enabled_domains": ["code-hygiene", "typescript", "react", "testing"],
  "detection_log": {
    "[domain]": "[detection reason]"
  }
}
```

---

## Pattern Conversion

Convert glob patterns to find commands:

| Glob Pattern | Find Command |
|--------------|--------------|
| `**/*.ts` | `find . -name "*.ts"` |
| `**/*.tsx` | `find . -name "*.tsx"` |
| `**/sms*.js` | `find . -name "sms*.js"` |
| `**/*.test.ts` | `find . -name "*.test.ts"` |

---

## Critical Rules

1. **ALWAYS INCLUDE code-hygiene** - It applies to all source code
2. **CHECK BOTH FILE PATTERNS AND DEPENDENCIES** - Some domains detected by files, others by deps
3. **EXCLUDE STANDARD DIRECTORIES** - node_modules, dist, build, .next, .git
4. **CATEGORIZE DOMAINS CORRECTLY** - testing goes in `domains.test`, others in `domains.source`
5. **DETECT TEST PATTERNS** - Include both test directories AND file patterns (co-located tests)
6. **WRITE VALID JSON** - Use proper escaping and formatting

---

## Source vs Test Determination

### What goes in `paths.source`:
- Directories containing application code
- If no standard dirs found, empty array (validator will scan all non-test files)

### What goes in `paths.test`:
- Dedicated test directories (`tests/`, `__tests__/`, etc.)
- Test file patterns for co-located tests (`**/*.test.ts`, `**/*.spec.ts`)

### What goes in `paths.exclude`:
- Auto-detected: none (rely on .flightignore)
- Can be manually added by user later

---

## Example Run

```
$ /flight-scan

Scanning project structure...

Source directories found:
  ✓ src/

Test directories found:
  ✓ tests/
  ✓ __tests__/

Co-located test files found:
  ✓ **/*.test.ts (12 files)
  ✓ **/*.spec.ts (3 files)

Scanning .flight/domains/*.flight...

Checking typescript.flight:
  Pattern: **/*.ts → found 45 files
  ✓ typescript enabled (source)

Checking react.flight:
  Pattern: **/*.tsx → found 23 files
  ✓ react enabled (source)

Checking package.json dependencies:
  ✓ react → react domain (source)
  ✓ typescript → typescript domain (source)
  ✓ vitest → testing domain (test)

Flight Scan Complete (v2)
=========================

Source paths:
  - src/

Test paths:
  - tests/
  - __tests__/
  - **/*.test.ts
  - **/*.spec.ts

Source domains: code-hygiene, typescript, react
Test domains: testing

Written to: .flight/flight.json
```

---

## When to Use

| Situation | Use This? |
|-----------|-----------|
| Setting up Flight in new project | Yes |
| Added new technology/framework | Yes |
| Domains not being detected | Yes |
| Want source/test separation | Yes (default v2) |
| Need legacy compatibility | Yes with `--v1` |
| Starting a task | No → Use `/flight-prime` |
| Validating code | No → Use `/flight-validate` |

---

## Backwards Compatibility

- **v1 configs still work**: validate-all.sh handles both v1 and v2
- **Use `--v1` flag**: To generate legacy format if needed
- **No migration required**: v2 is opt-in via running `/flight-scan`

---

## Next Step

After scanning:

```
/flight-prime <task>
```
