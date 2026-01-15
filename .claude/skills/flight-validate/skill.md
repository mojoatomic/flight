---
name: flight-validate
description: Run domain validation scripts against code - PASS or FAIL with no interpretation. Use after implementing code to verify it meets domain constraints.
---

# /flight-validate

Run domain validation scripts. Script says PASS or FAIL - no agent interpretation.

## Usage

```
/flight-validate [path]
```

## Arguments

- `$ARGUMENTS` - Optional path to validate (defaults to detecting files in src/)

---

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

---

## Output: Validation Report

```markdown
## Validation: [domain]

[exact script output]

## Result: PASS or FAIL
```

---

## Critical Rules

1. **RUN THE SCRIPT** - Do not inspect code manually
2. **REPORT OUTPUT** - Paste exactly what the script says
3. **NO INTERPRETATION** - Script decides pass/fail, not the agent
4. **IF NO SCRIPT EXISTS** - Say "No validation script for [domain]" and stop

---

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

---

## If Validation Fails

Show the failures. Do not fix automatically. User decides:
- Fix the code and re-run `/flight-validate`
- Or run `/flight-tighten` if the rule needs adjustment

---

## When to Use

| Situation | Use This? |
|-----------|-----------|
| Just implemented code | Yes |
| After `/flight-compile` execution | Yes |
| Before committing | Yes |
| Starting a new task | No → Use `/flight-prime` first |
| Have vague idea | No → Use `/flight-prd` first |

---

## Next Step

**If PASS** - Task complete, continue to next task:

```
/flight-prime tasks/[next-task].md
```

**If FAIL** - Fix issues or tighten rules:

```
[fix code] → /flight-validate
    OR
/flight-tighten  (if rule needs adjustment)
```

**Workflow**: `/flight-validate` → PASS → next task | FAIL → fix → retry

| Response | Action |
|----------|--------|
| `next` or `n` | Proceed to `/flight-prime` for next task |
| `fix` | Attempt to fix the validation failures |
| `tighten` | Run `/flight-tighten` to adjust rules |
| `commit` | Commit the changes (if PASS) |
