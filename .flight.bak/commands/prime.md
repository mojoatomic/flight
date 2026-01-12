# /flight:prime

Prime the context for a task. Research, scan, and gather facts before compiling a prompt.

## Usage

```
/flight:prime <task description or issue URL>
```

## Arguments

- `$ARGUMENTS` - Task description, GitHub issue URL, or feature request

## Process

### 1. Load Project Rules

```
Read FLIGHT.md in project root (if exists)
Read .flight/domains/*.md to understand available constraints
```

### 2. Understand the Task

Parse the input to identify:
- What needs to be built
- What type of task (API endpoint, migration, component, etc.)
- Any specific requirements mentioned

### 3. Scan Codebase

Search for relevant patterns:

```bash
# Find similar files
find . -name "*.js" -o -name "*.ts" | head -20

# Look for existing patterns
grep -r "app.get\|app.post" --include="*.js" | head -10

# Check for config files
ls -la package.json tsconfig.json .eslintrc* 2>/dev/null
```

Identify:
- Similar existing implementations
- File/folder conventions
- Existing test patterns
- Database schema (if relevant)

### 4. Fetch External Docs (if needed)

If the task involves external APIs or libraries:
- Search for official documentation
- Get exact endpoint URLs, auth methods, response shapes
- Note rate limits, required headers

### 5. Identify Constraints

From codebase scan, determine:
- What patterns MUST be followed (existing conventions)
- What's FORBIDDEN (project-specific rules)
- What files/folders should be created/modified

## Output

Generate a Prime Document:

```markdown
# Prime: [Task Name]

## Task Summary
[One paragraph describing what needs to be built]

## Task Type
[API Endpoint | Migration | Component | Utility | etc.]

## Relevant Files

### Existing Patterns to Follow
- `path/to/similar-file.js` (lines X-Y) - [why it's relevant]
- `path/to/another.js` (lines X-Y) - [why it's relevant]

### Files to Create/Modify
- `path/to/new-file.js` - [what it will contain]

## External Dependencies

### APIs
- **Endpoint:** [URL]
- **Auth:** [method]
- **Response Shape:**
```json
[exact shape]
```

### Libraries
- [library@version] - [what for]

## Discovered Constraints

### From Codebase
- [constraint 1 - with file reference]
- [constraint 2 - with file reference]

### From FLIGHT.md
- [project-specific rule]

### From Domain Files
- Using domains: [javascript, api, etc.]

## Recommended Template
`.flight/templates/[template-name].md`

## Recommended Examples
- `.flight/examples/[example-file]`
```

## Notes

- Do NOT start implementing yet
- Do NOT generate code
- This is research and context gathering only
- Output will feed into `/flight:compile`
