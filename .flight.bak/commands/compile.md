# /flight:compile

Compile an atomic Flight prompt from primed context.

## Usage

```
/flight:compile [prime-document-path]
```

If no path provided, uses the most recent Prime Document from context.

## Arguments

- `$ARGUMENTS` - Path to prime document (optional)

## Inputs Required

- Prime Document (from `/flight:prime`)
- Domain files in `.flight/domains/`
- Examples in `.flight/examples/`
- Templates in `.flight/templates/` (optional)

## Process

### 1. Parse Prime Document

Extract:
- Task summary
- Task type
- Relevant files and patterns
- External dependencies
- Discovered constraints
- Recommended domains/templates/examples

### 2. Select Domain Sections

For each relevant domain file:
- Include Formatting section (always)
- Include Naming section (always)
- Include relevant Pattern sections
- Include Allowed/Forbidden sections
- Skip sections not applicable to this task

**Do NOT include entire domain files. Extract only relevant sections.**

### 3. Load Examples

Find matching examples from `.flight/examples/`:
- Match by task type
- Match by language/framework
- Include as literal code pattern

### 4. Define Pass/Fail Criteria

Based on task requirements, define:

**MUST (Pass Conditions):**
- Exact response/output shapes
- Required patterns
- Required files

**MUST NOT (Fail Conditions):**
- Forbidden patterns
- Extra fields/files
- Violated constraints

### 5. Build Self-Check

Create verification checklist:
- Can be checked mechanically
- Maps to pass/fail criteria
- Model runs before outputting

### 6. Assemble Prompt

Compile everything into atomic prompt structure:

```markdown
# Flight: [Task Name]

## Task
[One sentence from Prime Document]

## Output Rules (Hard)
- [What files to create]
- [What NOT to create]
- [Dependencies allowed]

## Context
[External APIs - exact details, inlined]
[Existing patterns - relevant code snippets]

## Contract (Strict)
[Exact input/output shapes]
[No extra fields]

## Invariants

### Allowed (Only these)
- [item 1]
- [item 2]
- [item 3]

### Forbidden (None of these)
- [item 1]
- [item 2]

## Code Style
[From domain file - formatting, naming, patterns]
[Only sections relevant to this task]

## File Structure
[Exact skeleton if applicable]
[Section order, comments]

## Pattern
[Example code from .flight/examples/]
[Or inline pattern from similar existing file]

## Self-Check (Do before output)
- [ ] [Check 1]
- [ ] [Check 2]
- [ ] [Check 3]

## File Output
[Exact path(s) to create]
```

## Output

A complete, atomic Flight prompt.

**Critical requirements:**
- NO links or references to external files
- EVERYTHING needed is inlined
- Pass/fail criteria are binary
- Invariants use "exactly" / "only" / "must" language
- Self-check maps to invariants

## Validation

Before outputting, verify:
- [ ] No `see [file]` or `follow [link]` references
- [ ] All code style rules are explicit values (not "clean" or "good")
- [ ] Allowed lists are closed ("only these", "nothing else")
- [ ] Contract shows exact shapes
- [ ] Self-check is mechanically verifiable

## Notes

- The compiled prompt should work on ANY capable LLM
- If you can't inline something, the prime was incomplete
- Err on the side of too specific, not too vague
- When in doubt, add to forbidden list
