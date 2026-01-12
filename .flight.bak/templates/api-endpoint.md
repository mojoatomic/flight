# Flight Template: API Endpoint

Use this template when creating a new API endpoint.

---

## Prompt Structure

```markdown
# Flight: [Endpoint Name]

## Task
[One sentence: Create an API endpoint that does X]

---

## Output Rules (Hard)
- Output only the contents of `[filename]`
- Single file only. Do not create or reference any other files.
- No external dependencies beyond express
- Do not add tests, config, package files, or scaffolding

---

## Upstream API (if applicable)
- **Endpoint:** `[METHOD] [URL]`
- **Auth:** [How to authenticate]
- Read credentials from env var: `[VAR_NAME]`
- Never return, log, or expose credentials to clients

**Upstream response shape:**
```json
[exact shape]
```

---

## Endpoint Contract (Strict)

**Route:** `[METHOD] [path]`

### Allowed Methods
- Only [METHOD] is allowed
- All other methods (HEAD, POST, PUT, DELETE, PATCH, OPTIONS) must return 405

### Success Response ([code])
Exact shape. No extra fields.
```json
[exact shape]
```

### Error Responses
Exact shape. No extra fields.

| Status | Body |
|--------|------|
| [code] | `{ "error": "[message]", "code": [code] }` |

### Error Mapping (Hard)
- [condition] → [code]

---

## "No Extras" Constraints (Hard)

These are forbidden:
- Any response fields beyond the contract
- Returning raw upstream response to client
- Adding caching of any kind
- Adding request headers beyond auth
- Adding validation beyond Allowed Validation
- Adding helper functions, classes, abstractions, middleware
- Adding additional routes

---

## Allowed Validation (Only these checks)

After parsing response, only perform these checks:
1. [check 1]
2. [check 2]
3. [check 3]

**Rules:**
- Do not use [forbidden methods]
- If any check fails, return [code]

---

## Response Sending Rule (Hard)

Every response must use exactly:
```javascript
return res.status(<code>).json(<object>);
```

**Rules:**
- Every response preceded by `return`
- No other res.status(), res.json(), res.send() anywhere
- Applies to ALL handlers including catch blocks

---

## Code Style (Enforced)

- 2-space indentation
- Single quotes for strings
- Semicolons required
- Max line length: 100 characters
- Blank line between logical sections
- Newline at end of file

---

## File Structure (Mandatory)

```javascript
// 1. Imports
const express = require('express');

// 2. Constants
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.[VAR_NAME];
const API_BASE_URL = '[url]';

// 3. App initialization
const app = express();

// 4. Route handlers
app.get('[route]', async (req, res) => {
  // implementation
});

app.all('[route]', (req, res) => {
  // 405 handler
});

// 5. Server start
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Rules:**
- Keep section comments exactly as shown
- [METHOD] handler before ALL handler
- console.log uses template literal exactly as shown

---

## Control Flow

- Guard clauses (early return for errors)
- No else after return
- No nesting deeper than 2 levels
- Validate required env vars before upstream request
- try/catch at route handler level

---

## Self-Check (Do before output)

- [ ] Exactly [N] response bodies exist ([codes])
- [ ] Each matches exact shape specified
- [ ] Every response uses `return res.status().json()`
- [ ] Only allowed headers sent to upstream
- [ ] Only allowed validation checks exist
- [ ] All non-[METHOD] methods return 405
- [ ] Section comments present and correct
- [ ] console.log uses template literal

---

## File Output

Create: `[path/filename]`
```

---

## Compilation Checklist

When using this template:

1. [ ] Replace all `[placeholders]` with actual values
2. [ ] Fill in upstream API details (or remove section if not applicable)
3. [ ] Define exact response shapes
4. [ ] List all error mappings
5. [ ] Define allowed validation (be specific)
6. [ ] Update self-check to match contract
7. [ ] Remove any sections not applicable to this task
8. [ ] Verify no conflicting instructions remain
