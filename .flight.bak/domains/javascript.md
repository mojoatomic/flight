# Flight Domain: JavaScript / Node.js

## Formatting

| Rule | Value |
|------|-------|
| Indentation | 2 spaces |
| Quotes | Single quotes |
| Semicolons | Required |
| Max line length | 100 characters |
| Blank lines | Between logical sections |
| Trailing whitespace | None |
| End of file | Single newline |

## Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Files | kebab-case | `gold-price.js` |
| Directories | kebab-case | `api-handlers/` |
| Variables | camelCase | `goldPrice` |
| Functions | camelCase | `fetchGoldPrice()` |
| Constants | UPPER_SNAKE_CASE | `API_BASE_URL` |
| Environment vars | UPPER_SNAKE_CASE | `METALS_DEV_API_KEY` |
| Routes | kebab-case | `/api/gold-price` |
| JSON keys | camelCase | `{ "firstName": "..." }` |

## File Structure (Exact Order)

```javascript
// 1. Imports
const express = require('express');

// 2. Constants
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.SOME_API_KEY;

// 3. Guards (required env vars, config validation)
if (!API_KEY) {
  console.error('Missing SOME_API_KEY environment variable.');
  process.exit(1);
}

// 4. App initialization (if applicable)
const app = express();

// 5. Helper functions (if needed)
function formatThing() { ... }

// 6. Route handlers / main logic
app.get('/api/endpoint', async (req, res) => {
  // handler
});

// 7. Server start / main execution
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Rules:**
- Keep section comments exactly as shown
- Guards come immediately after constants, before any functions
- All constants in section 2 (including PORT)
- No code between sections except blank lines

## Control Flow (Invariants)

### Guard Clause Placement
Environment variable guards and required config checks go immediately after constants, before any functions.

```javascript
// 1. Constants
const API_KEY = process.env.SOME_API_KEY;
const PORT = process.env.PORT || 3000;

// 2. Guards (immediately after constants)
if (!API_KEY) {
  console.error('Missing SOME_API_KEY environment variable.');
  process.exit(1);
}

// 3. Helper functions
function doThing() { ... }
```

Exit early, fail fast. Don't bury guards at the bottom of the file.

### Defensive Data Handling
When processing external data:

```javascript
// GOOD: Number.isFinite() for numeric validation
const price = Number.isFinite(data.price) ? data.price.toFixed(2) : '--';

// BAD: truthy check or || 0 fallback
const price = data.price || 0;  // hides missing data
const price = data.price ? data.price.toFixed(2) : '0';  // misleading
```

**Rules:**
- Use `Number.isFinite()` to validate numbers, not truthy checks
- Display `'--'` for missing/invalid data, not `0` or empty string
- `0` is valid data; don't conflate missing with zero

### Response Pattern
Every response must use exactly this form:
```javascript
return res.status(<code>).json(<object>);
```

**Rules:**
- Every `res.status()` or `res.json()` preceded by `return`
- No other `res.send()`, `res.end()`, `res.write()` calls
- No exceptions, including catch blocks and fallback handlers

### Guard Clauses
```javascript
// REQUIRED: early return
if (!data) {
  return res.status(400).json({ error: 'Missing data', code: 400 });
}
// continue with happy path

// FORBIDDEN: nested else
if (data) {
  if (data.valid) {
    // deep nesting
  }
}
```

**Rules:**
- No `else` after `return`
- Max nesting depth: 2 levels
- Validate early, fail fast

### Async
```javascript
// REQUIRED: async/await with try/catch at boundary
app.get('/api/thing', async (req, res) => {
  try {
    const result = await fetchThing();
    return res.status(200).json(result);
  } catch (err) {
    return res.status(502).json({ error: 'Upstream failure', code: 502 });
  }
});

// FORBIDDEN: .then() chains
fetch(url).then(r => r.json()).then(data => { ... });
```

**Rules:**
- async/await over .then() chains
- Native fetch (no axios, got, node-fetch)
- try/catch at route handler level only
- No nested try/catch

## Error Handling (Invariants)

### Response Shape
All error responses must match:
```javascript
{ error: string, code: number }
```

**Rules:**
- `error` is human-readable message
- `code` mirrors HTTP status
- No extra fields
- No stack traces in response

### Error Mapping
```
Missing required env var     → 502
Upstream HTTP 429            → 503
Upstream non-2xx             → 502
Network/fetch error          → 502
Malformed response           → 502
Invalid request              → 400
Method not allowed           → 405
```

## Dependencies (Allowed List)

### Allowed
- express (HTTP server)
- Native fetch (HTTP client, Node 18+)
- dotenv (env loading, if needed)

### Forbidden
- axios, got, node-fetch (native fetch exists)
- lodash (use native methods)
- moment (use native Date or date-fns)
- Any ORM (use raw SQL)
- Class-based frameworks (NestJS, etc.)
- Decorator patterns
- Dependency injection containers

## Validation (Constraints)

When validating data, use only:
- Truthy checks: `if (!data)`
- Type checks: `typeof x === 'string'`
- Property existence: `data.prop && ...`
- Equality: `data.status === 'success'`

**Forbidden validation:**
- `Number.isFinite()` (unless explicitly allowed)
- `Date.parse()` (unless explicitly allowed)
- Regex validation (unless explicitly allowed)
- Schema validation libraries
- Deep equality checks

## Headers (Constraints)

When making outbound requests:
- Only set headers explicitly required for auth
- Do not add: `Accept`, `User-Agent`, `Content-Type` (unless required)

```javascript
// ALLOWED
headers: { 'X-API-KEY': API_KEY }

// FORBIDDEN (unless spec requires)
headers: { 
  'X-API-KEY': API_KEY,
  'Accept': 'application/json',  // unnecessary
  'User-Agent': 'MyApp/1.0'      // unnecessary
}
```

## Console Output

Use template literals for consistency:
```javascript
console.log(`Server running on port ${PORT}`);
```

Do not use string concatenation:
```javascript
// FORBIDDEN
console.log('Server running on port ' + PORT);
```

## Comments

### When to Comment
- Non-obvious business logic
- Workarounds with linked issue/ticket
- Complex regex or algorithms (if allowed)

### When Not to Comment
- Explaining what code does (code should be clear)
- Commented-out code (delete it)
- TODO without ticket number
- Section markers beyond the standard 5

## Environment Variables

**Rules:**
- All secrets in environment variables
- Never hardcode API keys, URLs to external services, credentials
- Use sensible defaults for non-sensitive values
- Never log, return, or expose secrets

```javascript
// CORRECT
const API_KEY = process.env.METALS_DEV_API_KEY;

// FORBIDDEN
const API_KEY = 'sk_live_abc123';
console.log('Using key:', API_KEY);
```

## File Constraints

| Constraint | Value |
|------------|-------|
| Max lines of code | 150 (comments/blanks don't count) |
| Max function length | 30 lines |
| Max parameters | 3 (use options object for more) |
| Files per task | 1 (unless spec says otherwise) |

---

## Compilation Notes

When compiling a Flight prompt for JavaScript:

1. Include **Formatting** section (always)
2. Include **Naming** section (always)
3. Include **File Structure** if creating a new file
4. Include **Control Flow** invariants (always for API work)
5. Include **Error Handling** if API has error cases
6. Include **Dependencies** allowed list if installing packages
7. Include **Validation** constraints if processing data
8. Include **Headers** constraints if making outbound requests

Do not include sections irrelevant to the task.
