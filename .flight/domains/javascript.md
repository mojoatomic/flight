# Domain: JavaScript / Node.js

## Invariants

### MUST
- Use `const` for variables that won't be reassigned, `let` for those that will
- Handle all Promise rejections with try/catch or .catch()
- Use async/await over raw Promises for readability
- Export functions individually: `export function name()` or `module.exports = { name }`
- Include JSDoc comments for public functions
- Validate function parameters at entry point
- Return early for error conditions

### NEVER
- Use `var` - always `const` or `let`
- Leave Promises unhandled (no floating promises)
- Use `==` - always `===` for comparison
- Mutate function parameters directly
- Use `eval()` or `Function()` constructor
- Catch errors without handling or re-throwing
- Use synchronous file operations in async contexts

## Patterns

### Async Function with Error Handling

```javascript
async function fetchUserData(userId) {
  if (!userId) {
    throw new Error('userId is required');
  }
  
  try {
    const response = await fetch(`/api/users/${userId}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error(`Failed to fetch user ${userId}:`, error.message);
    throw error; // Re-throw for caller to handle
  }
}
```

### Module Exports

```javascript
// Named exports (preferred)
export function createUser(data) { }
export function updateUser(id, data) { }
export function deleteUser(id) { }

// Or CommonJS
module.exports = {
  createUser,
  updateUser,
  deleteUser
};
```

### Parameter Validation

```javascript
function processOrder(order) {
  // Validate at entry
  if (!order) throw new Error('order is required');
  if (!order.items?.length) throw new Error('order.items cannot be empty');
  if (typeof order.total !== 'number') throw new Error('order.total must be a number');
  
  // Now safe to proceed
  return {
    ...order,
    processedAt: new Date().toISOString()
  };
}
```

## Error Handling

### Error Types

```javascript
// Custom error for domain-specific issues
class ValidationError extends Error {
  constructor(message, field) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
  }
}

class NotFoundError extends Error {
  constructor(resource, id) {
    super(`${resource} not found: ${id}`);
    this.name = 'NotFoundError';
    this.resource = resource;
    this.id = id;
  }
}
```

### Error Response Pattern

```javascript
// Standardized error responses
function formatError(error) {
  return {
    error: {
      type: error.name || 'Error',
      message: error.message,
      ...(error.field && { field: error.field }),
      ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
    }
  };
}
```

## Edge Cases

### Empty Arrays
MUST return `[]` for empty results, NEVER `null` or `undefined`:

```javascript
// Correct
async function getUsers(filter) {
  const users = await db.query(filter);
  return users || []; // Ensure array
}

// Incorrect
async function getUsers(filter) {
  const users = await db.query(filter);
  return users; // Could be null
}
```

### Optional Chaining
MUST use optional chaining for nested property access:

```javascript
// Correct
const city = user?.address?.city;

// Incorrect
const city = user && user.address && user.address.city;
```
