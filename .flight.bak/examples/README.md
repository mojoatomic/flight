# Flight Examples

Concrete code patterns for LLMs to match.

## Why Examples Matter

LLMs pattern-match. Descriptions are interpreted. Examples are copied.

A 50-line example beats 500 words of explanation.

## How to Use

When compiling a Flight prompt, reference relevant examples:

```markdown
## Pattern
Follow this pattern exactly:

[contents of .flight/examples/api-endpoint.js]
```

## Index

| File | Task Type | Description |
|------|-----------|-------------|
| `api-endpoint.js` | API Endpoint | Express GET endpoint with upstream API call |
| `api-endpoint.test.js` | Tests | Jest tests for API endpoint (TODO) |
| `migration.sql` | Database | SQL migration pattern (TODO) |
| `component.tsx` | Frontend | React component pattern (TODO) |

## Adding Examples

When you create code that represents your project's patterns well:

1. Copy it to `.flight/examples/`
2. Add comments explaining the pattern
3. Update this README
4. Reference in relevant templates

## Guidelines

- Examples should be **real, working code**
- Keep them **minimal but complete**
- Add **comments on the pattern**, not the logic
- One example per task type
- Update when patterns change
