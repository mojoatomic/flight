---
description: Run domain validation scripts against code - PASS or FAIL, no opinion
argument-hint: [path]
allowed-tools: Bash
---

# /flight-validate

Run domain validation scripts. Script says PASS or FAIL - no Claude interpretation.

## Usage

```
/flight-validate [path]
```

## Process

### 1. Detect Which Domains Apply

```bash
# Check what file types exist
ls src/*.c src/*.h 2>/dev/null && echo "DOMAIN: embedded-c-p10"
ls src/*.js 2>/dev/null && echo "DOMAIN: javascript"  
ls src/*.jsx src/*.tsx 2>/dev/null && echo "DOMAIN: react"
```

### 2. Run the Domain Validation Script

Each domain has a `.validate.sh` script. **Run it. Report output. That's it.**

```bash
# For C code:
.flight/domains/embedded-c-p10.validate.sh src/*.c src/*.h

# For JavaScript:
.flight/domains/javascript.validate.sh src/*.js

# For React:
.flight/domains/react.validate.sh src/*.jsx src/*.tsx
```

### 3. Report Results

**Do not interpret. Do not add opinion. Just show:**

```
## Validation: [domain]

[paste exact script output]

## Result: PASS or FAIL
```

If script exits 0 → PASS
If script exits non-zero → FAIL

## Rules

1. **RUN THE SCRIPT** - Do not inspect code manually
2. **REPORT OUTPUT** - Paste exactly what the script says
3. **NO INTERPRETATION** - Script decides pass/fail, not Claude
4. **IF NO SCRIPT EXISTS** - Say "No validation script for [domain]" and stop

## Example

```bash
$ .flight/domains/embedded-c-p10.validate.sh src/*.c

═══════════════════════════════════════════
  P10 Validation: src/ring_buffer.c
═══════════════════════════════════════════

## NEVER Rules
✅ N1: No goto
✅ N2: No setjmp/longjmp
✅ N3: No malloc/free
...

## MUST Rules  
✅ M1: Compile -Wall -Wextra -Werror
✅ M2: Functions ≤60 lines
✅ M3: ≥2 asserts/function
...

═══════════════════════════════════════════
  PASS: 11  FAIL: 0
  RESULT: PASS
═══════════════════════════════════════════
```

**Report:** PASS

## If Validation Fails

Show the failures. Do not fix automatically. User decides:
- Fix the code and re-run `/flight-validate`
- Or run `/flight-tighten` if the rule needs adjustment
