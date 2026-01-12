# Domain: JavaScript Hygiene

Code quality patterns that prevent common mistakes in JavaScript/Node.js projects.

---

## Invariants

### NEVER

1. **Generic Names** - Never use: `data`, `result`, `temp`, `info`, `item`, `value`, `obj`, `thing`, `stuff`, `foo`, `bar`, `baz`, `tmp`, `ret`, `val`

2. **Redundant Conditionals** - Never write:
   ```javascript
   // BAD
   if (condition) return true; else return false;
   if (condition) { return true; } return false;
   return condition ? true : false;
   
   // GOOD
   return condition;
   ```

3. **Equivalent Branches** - Never duplicate logic in if/else:
   ```javascript
   // BAD
   if (x) {
     doThing();
     return result;
   } else {
     doThing();
     return result;
   }
   
   // GOOD
   doThing();
   return result;
   ```

4. **Redundant Boolean Logic** - Never write:
   ```javascript
   // BAD
   x === true
   x === false
   x !== true
   x !== false
   !!x === true
   
   // GOOD
   x
   !x
   ```

5. **Magic Number Calculations** - Never compute at runtime what can be a constant:
   ```javascript
   // BAD
   const timeout = 60 * 60 * 1000;
   const days = 24 * 60 * 60;
   
   // GOOD
   const MS_PER_HOUR = 3600000;
   const SECONDS_PER_DAY = 86400;
   ```

6. **Unnecessary Abstraction** - Never wrap single-use trivial operations:
   ```javascript
   // BAD
   function getValue(obj) { return obj.value; }
   const v = getValue(thing);
   
   // GOOD
   const v = thing.value;
   ```

7. **Inconsistent Naming Style** - Never mix conventions in the same file:
   ```javascript
   // BAD
   const user_name = 'alice';
   const userAge = 25;
   const UserStatus = 'active';
   
   // GOOD (pick one, stick with it)
   const userName = 'alice';
   const userAge = 25;
   const userStatus = 'active';
   ```

8. **Generic Function Names** - Never use: `handle`, `process`, `do`, `run`, `execute`, `manage` without context:
   ```javascript
   // BAD
   function handleData(data) { ... }
   function processItem(item) { ... }
   
   // GOOD
   function validateUserInput(input) { ... }
   function transformOrderToInvoice(order) { ... }
   ```

### MUST

1. **Domain-Specific Names** - Use vocabulary from the problem domain
2. **Boolean Prefixes** - Use `is`, `has`, `can`, `should`, `will` for booleans
3. **Async Suffixes** - Consider `Async` suffix or verb prefixes for async functions
4. **Plural Collections** - Arrays and collections use plural names: `users`, `items`, `orders`
5. **Constants Uppercase** - `MAX_RETRIES`, `DEFAULT_TIMEOUT`, `API_BASE_URL`
6. **Descriptive Errors** - Error messages state what went wrong and what was expected

---

## Patterns

### Good Naming
```javascript
// Domain-specific
const customerOrder = fetchOrder(orderId);
const invoiceTotal = calculateInvoiceTotal(lineItems);
const isPaymentComplete = payment.status === 'complete';

// Boolean prefixes
const hasPermission = user.roles.includes('admin');
const canEdit = hasPermission && !document.isLocked;
const shouldRetry = attempts < MAX_RETRIES;

// Collections are plural
const users = await fetchUsers();
const validOrders = orders.filter(isValidOrder);
```

### Constants
```javascript
// Time constants (pre-calculated)
const MS_PER_SECOND = 1000;
const MS_PER_MINUTE = 60000;
const MS_PER_HOUR = 3600000;
const MS_PER_DAY = 86400000;

// Configuration
const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 5000;
const API_BASE_URL = 'https://api.example.com';
```

### Simple Conditionals
```javascript
// Direct returns
return isValid;
return !hasError;
return items.length > 0;

// Ternary for values, not booleans
const status = isActive ? 'active' : 'inactive';
const message = count === 1 ? 'item' : 'items';
```

---

## Anti-Patterns to Avoid

| Pattern | Problem | Fix |
|---------|---------|-----|
| `const data = ...` | Generic | Use domain term |
| `function handleX()` | Vague verb | Describe action |
| `if (x) return true` | Redundant | `return x` |
| `60 * 60 * 1000` | Magic calc | Pre-computed constant |
| `x === true` | Redundant | `x` |
| `items.map(i => ...)` | Generic `i` | `items.map(item => ...)` |
| `const temp = ...` | Temporary smell | Name by purpose |
