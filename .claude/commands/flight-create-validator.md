---
description: Generate validator script and test files from a domain.md
argument-hint: [domain.md file]
---

# /flight-create-validator

Generate a `.validate.sh` script and test files from a domain contract file.

## Usage

```
/flight-create-validator .flight/domains/my-domain.md
/flight-create-validator my-domain.md
```

## Arguments

- `$ARGUMENTS` - Path to domain `.md` file

---

## Purpose

The domain `.md` file is a **contract**. The `.validate.sh` file **enforces** it.

This command ensures every rule in NEVER/MUST has a corresponding check in the validator.

---

## Process

### 1. Read the Domain File

Parse the domain `.md` file and extract:

```markdown
### NEVER (validator will reject)
1. **Rule name** - Description
   ```code
   # BAD
   bad_example

   # GOOD
   good_example
   ```

### MUST (validator will reject)
...

### SHOULD (validator warns)
...
```

### 2. Map Rules to Checks

For each NEVER rule → create a `check()` call that **fails if pattern found**
For each MUST rule → create a `check()` call that **fails if pattern missing**
For each SHOULD rule → create a `warn()` call

### 3. Generate Validator Script

Create `.flight/domains/[domain].validate.sh`:

```bash
#!/bin/bash
# [domain].validate.sh - [Domain description]
set -uo pipefail

FILES="${@:-src/**/*.[ext] **/*.[ext]}"
PASS=0
FAIL=0
WARN=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        printf '%s\n' "$result" | head -10 | sed 's/^/   /'
        ((FAIL++))
    fi
}

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        yellow "⚠️  $name"
        printf '%s\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++))
    fi
}

# Expand globs
EXPANDED_FILES=$(ls $FILES 2>/dev/null || true)
if [[ -z "$EXPANDED_FILES" ]]; then
    red "No files found matching: $FILES"
    exit 1
fi
FILES="$EXPANDED_FILES"

printf '%s\n' "═══════════════════════════════════════════"
printf '%s\n' "  [Domain Name] Validation"
printf '%s\n' "═══════════════════════════════════════════"
printf '\n'

printf 'Files: %s\n\n' "$(echo "$FILES" | wc -w | tr -d ' ')"

printf '%s\n' "## NEVER Rules"

# N1: [Rule from domain]
check "N1: [Description]" \
    grep -En '[pattern]' $FILES

# ... more NEVER checks

printf '\n%s\n' "## MUST Rules"

# M1: [Rule from domain]
check "M1: [Description]" \
    bash -c "[check logic]"

# ... more MUST checks

printf '\n%s\n' "## SHOULD Rules"

# S1: [Rule from domain]
warn "S1: [Description]" \
    grep -En '[pattern]' $FILES

# ... more SHOULD checks

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
[[ $FAIL -eq 0 ]] && green "  RESULT: PASS" || red "  RESULT: FAIL"
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
```

### 4. Generate Test Files

Create test files to verify the validator works:

#### `.flight/domains/tests/[domain].bad.[ext]`

A file that **must fail** validation. Include one violation of each NEVER rule:

```
// This file should FAIL validation
// Contains intentional violations for testing

[violation of N1]
[violation of N2]
...
```

#### `.flight/domains/tests/[domain].good.[ext]`

A file that **must pass** validation. Follows all rules:

```
// This file should PASS validation
// Demonstrates correct patterns

[correct pattern for N1]
[correct pattern for N2]
...
```

### 5. Verify the Validator

Run the validator against test files:

```bash
# Should FAIL
.flight/domains/[domain].validate.sh .flight/domains/tests/[domain].bad.[ext]
# Expected: RESULT: FAIL

# Should PASS
.flight/domains/[domain].validate.sh .flight/domains/tests/[domain].good.[ext]
# Expected: RESULT: PASS
```

---

## Output

After running, you'll have:

```
.flight/domains/
├── [domain].md              # (input - unchanged)
├── [domain].validate.sh     # Generated validator
└── tests/
    ├── [domain].bad.[ext]   # Must fail validation
    └── [domain].good.[ext]  # Must pass validation
```

---

## Validator Patterns

### Finding Bad Patterns (NEVER rules)

```bash
# Simple grep - find forbidden pattern
check "N1: No console.log" \
    grep -En 'console\.log' $FILES

# Exclude comments
check "N2: No var keyword" \
    grep -En '\bvar\s' $FILES | grep -v '//'

# Multiple patterns
check "N3: No == or !=" \
    grep -En '[^!=]==[^=]|[^!]!=[^=]' $FILES
```

### Finding Missing Patterns (MUST rules)

```bash
# File must contain pattern
check "M1: Must have shebang" \
    bash -c "for f in $FILES; do head -1 \"\$f\" | grep -qE '^#!' || echo \"\$f: missing shebang\"; done"

# Each function must have something
check "M2: Functions must use local" \
    bash -c "for f in $FILES; do awk '/^[a-z_]+\(\).*\{/,/^\}/ { if (/^[[:space:]]+[a-z]+=/ && !/local/) print FILENAME\":\"NR }' \"\$f\"; done"
```

### Warnings (SHOULD rules)

```bash
# Same as check() but uses warn()
warn "S1: Prefer const over let" \
    grep -En '\blet\s' $FILES
```

---

## Critical Rules

1. **Every NEVER rule needs a check** - No rules without enforcement
2. **Every MUST rule needs a check** - No aspirational requirements
3. **SHOULD rules use warn()** - They don't fail validation
4. **Test files verify both directions** - Bad fails, good passes
5. **Patterns must avoid false positives** - Refine grep patterns
6. **Make validator executable** - `chmod +x`

---

## Common File Extensions

| Domain | Test File Extension |
|--------|---------------------|
| javascript | `.js` |
| typescript | `.ts` |
| react | `.tsx` |
| python | `.py` |
| bash | `.sh` |
| sql | `.sql` |
| c | `.c` / `.h` |

---

## Next Steps

After creating the validator:

1. **Run against test files** - Verify it works
2. **Run against real code** - Check for false positives
3. **Refine patterns** - Fix any issues
4. **Update update.sh** - Add domain to update script if it's a core domain

```bash
# Test the validator
.flight/domains/[domain].validate.sh .flight/domains/tests/[domain].bad.[ext]
.flight/domains/[domain].validate.sh .flight/domains/tests/[domain].good.[ext]

# Run on real code
.flight/domains/[domain].validate.sh src/**/*.[ext]
```
