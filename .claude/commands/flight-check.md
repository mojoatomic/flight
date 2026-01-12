---
description: Check code against domain invariants - reads MUST/NEVER rules and validates
argument-hint: [path]
allowed-tools: Bash, Read, Glob
---

# /flight-check

Check code against domain invariants. Reads the domain files, extracts MUST/NEVER rules, and validates code.

## Usage

```
/flight-check [path]
```

## Process

### 1. Find Files to Check

```bash
# If path given, use it
# Otherwise find source files
find . -name "*.c" -o -name "*.h" | grep -v test | head -20
```

### 2. Read ALL Domain Files

```bash
cat .flight/domains/*.md
```

**Extract every MUST and NEVER rule into a checklist.**

### 3. For Each Source File, Check Each Rule

#### MUST Rules (must be present)
For each MUST rule in the domain, verify the code satisfies it.

Example P10 checks:
- **Function length ≤60 lines**: Count lines per function
- **≥2 assertions per function**: Count `assert(` or `ASSERT(` calls
- **All returns checked**: Look for unchecked function calls
- **Static allocation only**: Grep for `malloc|calloc|realloc|free`
- **Bounded loops**: Check all `for`/`while` have visible bounds
- **No goto**: Grep for `goto`
- **No recursion**: Check if any function calls itself

#### NEVER Rules (must be absent)
For each NEVER rule, verify it doesn't appear.

### 4. Run Tool Checks Based on Language

**For C files:**
```bash
# Compile with strict warnings
gcc -Wall -Wextra -Werror -pedantic -std=c11 -fsyntax-only *.c 2>&1

# Static analysis
cppcheck --enable=all --error-exitcode=1 . 2>&1
```

**For JS/TS files:**
```bash
npm run lint 2>&1
npm run typecheck 2>&1
```

### 5. Output Checklist

```markdown
# Flight Check: [filename]

## Domain: embedded-c-p10.md

### MUST Rules

| # | Rule | Status | Evidence |
|---|------|--------|----------|
| 1 | Function length ≤60 lines | ✅ PASS | Longest: 42 lines |
| 2 | ≥2 assertions per function | ❌ FAIL | ring_buffer_init has 1 |
| 3 | All returns checked | ✅ PASS | - |
| 4 | No dynamic allocation | ✅ PASS | No malloc/free found |
| 5 | Bounded loops | ✅ PASS | All loops have #define bounds |

### NEVER Rules

| # | Rule | Status | Evidence |
|---|------|--------|----------|
| 1 | No goto | ✅ PASS | Not found |
| 2 | No recursion | ✅ PASS | No self-calls |
| 3 | No malloc/free | ✅ PASS | Not found |

### Tool Checks

| Tool | Status | Output |
|------|--------|--------|
| gcc -Wall -Wextra -Werror | ✅ PASS | 0 warnings |
| cppcheck | ✅ PASS | 0 issues |

## Summary

- MUST rules: 5/5 passing
- NEVER rules: 3/3 passing  
- Tool checks: 2/2 passing
- **STATUS: PASS** ✅

(or)

- MUST rules: 4/5 passing
- NEVER rules: 3/3 passing
- Tool checks: 2/2 passing
- **STATUS: FAIL** ❌

### Failures to Fix

1. `ring_buffer_init()` needs 1 more assertion (currently has 1, need ≥2)
```

## Key Principle

**Read the domain file. Check each rule. Binary pass/fail.**

Don't guess what to check - the domain file tells you exactly what to verify.
