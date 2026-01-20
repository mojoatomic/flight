# Domain: Javascript Design

Code quality patterns that prevent common mistakes in JavaScript/Node.js projects. JavaScript-specific patterns while code-hygiene covers universal patterns.


**Validation:** `javascript.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Generic Variable Names** - Never use generic names like data, result, temp, info, item, value, obj, thing, stuff, foo, bar, baz, tmp, ret, val. Use domain-specific names instead.

   ```
   // BAD
   const data = fetchUser();
   // BAD
   const result = processOrder();
   // BAD
   const temp = calculateTotal();

   // GOOD
   const user = fetchUser();
   // GOOD
   const processedOrder = processOrder();
   // GOOD
   const invoiceTotal = calculateTotal();
   ```

2. **Redundant Conditional Returns** - Never write 'if (condition) return true; else return false' or equivalent. Return the condition directly.

   ```
   // BAD
   if (condition) return true; else return false;
   // BAD
   if (condition) { return true; } return false;

   // GOOD
   return condition;
   ```

3. **Ternary Returning Boolean Literals** - Never write 'condition ? true : false'. The condition is already boolean.

   ```
   // BAD
   return isValid ? true : false;
   // BAD
   const result = hasPermission ? true : false;

   // GOOD
   return isValid;
   // GOOD
   const result = hasPermission;
   // GOOD
   const status = isActive ? 'active' : 'inactive';  // OK: non-boolean
   ```

4. **Redundant Boolean Comparisons** - Never write '=== true', '=== false', '!== true', or '!== false'. Use the boolean directly.

   ```
   // BAD
   if (x === true) { ... }
   // BAD
   if (y === false) { ... }
   // BAD
   if (z !== true) { ... }

   // GOOD
   if (x) { ... }
   // GOOD
   if (!y) { ... }
   // GOOD
   if (!z) { ... }
   ```

5. **Magic Number Calculations** - Never compute at runtime what can be a constant. Pre-calculate time values and other derived constants.

   ```
   // BAD
   const timeout = 60 * 60 * 1000;
   // BAD
   const days = 24 * 60 * 60;
   // BAD
   const interval = 7 * 24 * 60 * 60 * 1000;

   // GOOD
   const MS_PER_HOUR = 3600000;
   // GOOD
   const SECONDS_PER_DAY = 86400;
   // GOOD
   const MS_PER_WEEK = 604800000;
   ```

6. **Generic Function Names** - Never use generic verbs like handle, process, do, run, execute, manage combined with generic nouns without specific context.

   ```
   // BAD
   function handleData(data) { ... }
   // BAD
   function processItem(item) { ... }
   // BAD
   function doValue(value) { ... }

   // GOOD
   function validateUserInput(input) { ... }
   // GOOD
   function transformOrderToInvoice(order) { ... }
   // GOOD
   function calculateShippingCost(order) { ... }
   ```

7. **Single-Letter Variables** - Never use single-letter variables except i, j, k as loop counters.

   ```
   // BAD
   const x = getUser();
   // BAD
   const n = calculateTotal();
   // BAD
   let a = [];

   // GOOD
   const user = getUser();
   // GOOD
   const total = calculateTotal();
   // GOOD
   let items = [];
   // GOOD
   for (let i = 0; i < items.length; i++) { ... }  // OK: loop counter
   ```

8. **console.log in Source Files** - Never leave console.log statements in production source files. Test files are excluded from this rule.

   ```
   // BAD
   // src/user.js
   // BAD
   console.log('user:', user);
   // BAD
   console.log('debug: processing order');

   // GOOD
   // Use proper logging
   // GOOD
   logger.debug('Processing order', { orderId });
   ```

9. **var Declaration** - Never use var. Use const for values that won't be reassigned, let for values that will. Block scoping and temporal dead zone prevent common bugs.

   ```
   // BAD
   var count = 0;
   // BAD
   var user = getUser();
   // BAD
   for (var i = 0; i < 10; i++) { ... }

   // GOOD
   const user = getUser();
   // GOOD
   let count = 0;
   // GOOD
   for (let i = 0; i < 10; i++) { ... }
   ```

10. **Loose Equality** - Never use == or !=. Use === and !== to avoid type coercion bugs. Type coercion rules are complex and lead to unexpected behavior.

   ```
   // BAD
   if (x == null) { ... }
   // BAD
   if (count != 0) { ... }
   // BAD
   if (status == 'active') { ... }

   // GOOD
   if (x === null || x === undefined) { ... }
   // GOOD
   if (count !== 0) { ... }
   // GOOD
   if (status === 'active') { ... }
   ```

### SHOULD (validator warns)

1. **Await in Loops** - Avoid await inside loops. Sequential awaits are slow when operations are independent. Use Promise.all() for parallel execution.

   ```
   // BAD
   for (const user of users) {
     await sendEmail(user);  // Sequential - slow!
   }
   

   // GOOD
   await Promise.all(users.map(user => sendEmail(user)));
   
   ```

### GUIDANCE (not mechanically checked)

1. **Domain-Specific Names** - Use vocabulary from the problem domain. Names should reflect business concepts, not implementation details.


2. **Boolean Prefixes** - Use is, has, can, should, will prefixes for boolean variables.


3. **Async Function Naming** - Consider Async suffix or verb prefixes for async functions to make async nature clear at call sites.


4. **Plural Collections** - Arrays and collections should use plural names.


5. **Constants Uppercase** - Use UPPER_SNAKE_CASE for true constants (values that never change).


6. **Descriptive Error Messages** - Error messages should state what went wrong and what was expected.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| const data = ... |  | Use domain term |
| function handleX() |  | Describe action |
| if (x) return true |  | return x |
| 60 * 60 * 1000 |  | Pre-computed constant |
| x === true |  | x |
| items.map(i => ...) |  | items.map(item => ...) |
| const temp = ... |  | Name by purpose |
| var x = ... |  | Use const or let |
| x == y |  | Use === or !== |
| for (...) { await ... } |  | Use Promise.all() |
