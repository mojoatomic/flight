---
description: Prime context for a task - research, scan codebase, gather domain constraints
argument-hint: [task description]
---

# /flight-prime

Prime the context for a task. Research, scan, and gather facts before compiling a prompt.

## Usage

```
/flight-prime <task description>
```

## Arguments

- `$ARGUMENTS` - Task description, feature request, or issue to implement

## Process

### 1. READ ALL DOMAIN FILES FIRST (Critical)

**Before doing anything else**, read every domain file:

```bash
ls -la .flight/domains/
cat .flight/domains/*.md
```

After reading, list what you found:

```markdown
## Available Domains
- javascript.md: [what it covers]
- react.md: [what it covers]
- [etc.]
```

**Then identify which domains are RELEVANT to the task.**

### 2. Load Project Context

```bash
# Check for existing patterns
find . -name "*.js" -o -name "*.ts" | head -20
grep -r "similar_pattern" --include="*.js" | head -10

# Check configs
ls -la package.json tsconfig.json .eslintrc* 2>/dev/null
```

### 3. Identify Constraints

From domain files and codebase, determine:
- What patterns MUST be followed
- What's FORBIDDEN
- What files need to be created/modified

### 4. Fetch External Docs (if needed)

If the task involves external APIs:
- Search for official documentation
- Get exact endpoints, auth methods, response shapes

## Output: Prime Document

Generate this structure:

```markdown
# Prime: [Task Name]

## Task Summary
[One paragraph describing what needs to be built]

## Task Type
[API Endpoint | Migration | Component | Service | etc.]

## Domains Used
- `[domain].md` - [why relevant]

## Key Constraints from Domains

### From [domain].md
- [constraint 1]
- [constraint 2]

### From Codebase
- [existing pattern to follow]

## Relevant Files

### Existing Patterns to Follow
- `path/to/file.js` - [why relevant]

### Files to Create/Modify
- `path/to/new-file.js` - [what it will contain]

## External Dependencies

### APIs (if any)
- **Endpoint:** [URL]
- **Auth:** [method]

### Libraries (if any)
- [library@version] - [purpose]

## Recommended Template
`.flight/templates/[template-name].md`

## Recommended Examples
- `.flight/examples/[example]`
```

## Critical Rules

1. **READ DOMAIN FILES FIRST** - Before scanning codebase
2. **USE DOMAIN FILES** - If a domain covers the topic, use it as primary source
3. **DO NOT SEARCH WEB** for topics covered by domain files
4. **LIST DOMAINS USED** so compile step knows what to include
5. **PULL ACTUAL CONSTRAINTS** from domain files into the Prime Document

## Notes

- Do NOT start implementing yet
- Do NOT generate code
- This is research and context gathering only
- Output feeds into `/flight-compile`
