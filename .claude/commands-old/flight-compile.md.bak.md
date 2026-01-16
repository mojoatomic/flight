---
description: Compile atomic prompt from primed context with domain invariants
---

# /flight-compile

Compile an atomic Flight prompt from primed context. Output goes to PROMPT.md.

## Usage

```
/flight-compile
```

Uses the most recent Prime Document from context.

## Process

### 1. Gather Inputs

From the Prime Document, collect:
- Task summary
- Domains used
- Key constraints
- Files to create/modify
- External dependencies

### 2. Load Domain Invariants

For each domain listed in "Domains Used":

```bash
cat .flight/domains/[domain].md
```

Extract:
- All MUST rules
- All NEVER rules
- Relevant patterns
- Error handling requirements

### 3. Load Template (if specified)

```bash
cat .flight/templates/[template].md
```

### 4. Build Atomic Prompt

Structure the prompt with these sections:

```markdown
# Task: [Name]

## Objective
[Clear, single-sentence goal]

## Context
[Relevant background from Prime Document]

## Invariants

### MUST
- [From domain files - required behaviors]

### NEVER
- [From domain files - forbidden patterns]

## Implementation Requirements

### Files to Create
- `path/to/file.js`: [purpose]

### Files to Modify
- `path/to/existing.js`: [changes needed]

## Patterns to Follow

[Code examples from domains or existing codebase]

## Acceptance Criteria

- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] All invariants satisfied
- [ ] Tests pass

## Error Handling

[From domain files - specific error codes and handling]

## Completion

When ALL acceptance criteria are met and tests pass, output:
COMPLETE

If blocked after significant effort, output:
BLOCKED: [reason]
```

### 5. Output to PROMPT.md

Write the compiled prompt to `PROMPT.md` in the project root.

**This file contains the compiled prompt for execution.**

```bash
# The compiled prompt becomes PROMPT.md
cat > PROMPT.md << 'EOF'
[compiled prompt content]
EOF
```

### 6. Update @fix_plan.md

If `@fix_plan.md` exists, ensure the current task is listed:

```markdown
## Current Priority

- [ ] [Task from this compile]

## Backlog

[existing items]
```

## Output Format

After writing PROMPT.md, report:

```markdown
## Compiled Successfully

**PROMPT.md** updated with:
- Task: [name]
- Domains: [list]
- Invariants: [count] MUST, [count] NEVER
- Files to create: [count]
- Files to modify: [count]

**Ready for execution in Claude Code.**
```

## Quality Checks

Before finalizing, verify:

1. **Atomic** - Single clear objective
2. **Invariants included** - All relevant MUST/NEVER rules
3. **Testable** - Clear acceptance criteria
4. **Self-contained** - All context needed is in the prompt
5. **Completion signal** - Includes COMPLETE/BLOCKED output instructions

## Notes

- The compiled prompt should be executable by Claude without additional context
- Include enough detail that invariants can be validated
- Keep focused - one task per compile
- The prompt can be executed iteratively until COMPLETE is output
