# /flight:tighten

Analyze validation failures and strengthen the prompt.

## Usage

```
/flight:tighten
```

Uses context from most recent `/flight:validate` failure.

## Inputs Required

- Validation failure report (from `/flight:validate`)
- Original Flight prompt
- Generated output that failed
- Domain files (to potentially update)

## Process

### Step 1: Parse Failures

From validation report, extract:
- Which checks failed
- What was expected
- What was actually produced
- Location in code

### Step 2: Analyze Root Cause

For each failure, ask:

**Was the constraint too vague?**
```
Original: "Use guard clauses"
Problem: Model interpreted differently than intended
Fix: "Every error case must use: return res.status(X).json({...});"
```

**Was there a conflict?**
```
Original: "Create src/file.js" + "Don't create directories"
Problem: Contradictory instructions
Fix: Remove conflict, be explicit about one path
```

**Did training priors override?**
```
Original: "Return before res.json()"
Problem: Common Express patterns don't use return on terminal handlers
Fix: "Every response must be exactly: return res.status().json()"
       Add to self-check explicitly
```

**Was it missing from allowed list?**
```
Original: Didn't specify what validation was allowed
Problem: Model added "helpful" extra validation
Fix: "Allowed validation (only these): [explicit list]"
```

**Was the example missing or unclear?**
```
Original: No example of the pattern
Problem: Model had nothing to pattern-match
Fix: Add concrete example to prompt or .flight/examples/
```

### Step 3: Generate Fix

For each failure, determine the fix type:

**Type A: Strengthen language**
```
Before: "Try to keep responses consistent"
After: "Every response must use exactly this form: [code]"
```

**Type B: Add to allowed list**
```
Before: (no list)
After: "Allowed validation (only these):
        1. data && data.status === 'success'
        2. typeof data.metals.gold === 'number'
        3. typeof data.timestamp === 'string'
        No other validation permitted."
```

**Type C: Add to forbidden list**
```
Before: "Don't over-engineer"
After: "Forbidden:
        - Number.isFinite()
        - Date.parse()
        - Regex validation
        - Any validation not in allowed list"
```

**Type D: Add example**
```
Before: Description only
After: "Follow this pattern exactly:
        [literal code example]"
```

**Type E: Add to self-check**
```
Before: (not in self-check)
After: "Self-check:
        - [ ] Every response uses return res.status().json()
        - [ ] No headers besides X-API-KEY"
```

**Type F: Resolve conflict**
```
Before: Two contradictory statements
After: One clear statement, other removed
```

### Step 4: Decide Scope

For each fix, ask: **Is this reusable?**

**Project-specific:** Add to FLIGHT.md
```
This constraint only applies to this project.
→ Add to FLIGHT.md in project root
```

**Language/framework-wide:** Add to domain file
```
This constraint applies to all JS/Python/etc. work.
→ Update .flight/domains/[language].md
```

**Task-type specific:** Add to template
```
This constraint applies to all API endpoints/migrations/etc.
→ Update .flight/templates/[type].md
```

**One-off:** Keep in prompt only
```
This constraint is unique to this specific task.
→ Only update the compiled prompt
```

### Step 5: Update Files

Apply fixes to appropriate locations:

```bash
# If updating domain file
vim .flight/domains/javascript.md
# Add new invariant to appropriate section

# If updating template
vim .flight/templates/api-endpoint.md
# Add new constraint to template

# If updating project rules
vim FLIGHT.md
# Add project-specific override
```

### Step 6: Re-compile Prompt

Generate updated Flight prompt with fixes:
- Include new invariants
- Include new allowed/forbidden items
- Include new self-check items
- Include new examples (if added)

## Output

```markdown
# Tighten Report

## Failures Analyzed
[N] failures from validation

## Root Causes

### Failure 1: [Description]
**Root cause:** [vague constraint | conflict | training prior | missing allowed list | missing example]
**Fix type:** [A-F from above]
**Fix:** [Specific change]
**Scope:** [prompt only | domain file | template | project rules]

### Failure 2: [Description]
...

## Files Updated
- `.flight/domains/javascript.md` - Added [X] invariant
- `.flight/templates/api-endpoint.md` - Added [Y] to forbidden list
- (none if prompt-only fixes)

## Updated Prompt

[Complete re-compiled Flight prompt with all fixes applied]

## Next Steps
1. Execute the updated prompt
2. Run `/flight:validate` again
3. If still failing, run `/flight:tighten` again
4. Repeat until PASS
```

## The Learning Loop

```
Failure → Analyze → Fix → Update domain (if reusable) → Re-compile → Retry
                              ↓
                    Domain files get smarter
                    Future prompts benefit
```

## Notes

- Every tighten should make the system smarter
- Prefer updating domain files over one-off fixes
- Ask the LLM directly: "Why did you produce X?"
- The goal is convergence, not perfection on first try
- 3-4 tighten cycles is normal for a new task type
