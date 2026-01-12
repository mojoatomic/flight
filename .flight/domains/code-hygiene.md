# Domain: Code Hygiene

Universal code quality patterns that apply to ALL languages. These are AI-generated code smells that transcend syntax.

---

## Invariants

### NEVER

1. **Generic Variable Names**
   ```
   BAD:  data, result, temp, tmp, info, item, items, value, val, obj, thing, stuff, foo, bar, baz, ret, res, resp, response, request, req, output, input, payload
   
   GOOD: user, order, invoice, productList, authToken, configPath, httpResponse, userInput, orderPayload
   ```
   The name should describe WHAT it holds, not THAT it holds something.

2. **Redundant Conditional Returns**
   ```
   BAD:
   if (condition) return true; else return false;
   if (condition) { return true; } return false;
   if (condition) return false; else return true;
   
   GOOD:
   return condition;
   return !condition;
   ```

3. **Ternary Returning Boolean Literals**
   ```
   BAD:
   condition ? true : false
   condition ? false : true
   x === y ? true : false
   
   GOOD:
   condition
   !condition
   x === y
   ```

4. **Redundant Boolean Comparisons**
   ```
   BAD:
   x === true
   x === false
   x !== true
   x !== false
   x == true
   x == false
   if (isValid === true)
   while (hasMore === false)
   
   GOOD:
   x
   !x
   !x
   x
   x
   !x
   if (isValid)
   while (!hasMore)
   ```

5. **Magic Number Calculations**
   ```
   BAD:
   sleep(86400)
   timeout = 60 * 60 * 1000
   maxAge = 7 * 24 * 60 * 60
   buffer = 1024 * 1024
   
   GOOD:
   SECONDS_PER_DAY = 86400
   sleep(SECONDS_PER_DAY)
   
   MILLISECONDS_PER_HOUR = 60 * 60 * 1000
   timeout = MILLISECONDS_PER_HOUR
   
   ONE_WEEK_SECONDS = 7 * 24 * 60 * 60
   maxAge = ONE_WEEK_SECONDS
   
   ONE_MEGABYTE = 1024 * 1024
   buffer = ONE_MEGABYTE
   ```

6. **Generic Function/Method Names**
   ```
   BAD:
   handleData(), processItem(), doSomething(), handleClick(),
   getData(), setData(), updateValue(), processInput(),
   handleEvent(), processResult(), transformData()
   
   GOOD:
   validateUserEmail(), processOrderPayment(), handleLoginSubmit(),
   fetchUserProfile(), setAuthToken(), updateOrderStatus(),
   handleFormSubmit(), calculateOrderTotal(), transformToInvoice()
   ```
   Function names should include the domain noun they operate on.

7. **Single-Letter Variables (outside loops)**
   ```
   BAD:
   const x = getUser();
   let n = items.length;
   const s = name.toLowerCase();
   const t = Date.now();
   
   GOOD:
   const user = getUser();
   let itemCount = items.length;
   const normalizedName = name.toLowerCase();
   const timestamp = Date.now();
   
   OK in loops:
   for (let i = 0; i < 10; i++)
   for (let j = 0; j < cols; j++)
   items.map((x, i) => ...)  // OK if simple transform
   ```

8. **console.log in Production Code**
   ```
   BAD:
   console.log('user:', user);
   console.log(data);
   print(f"debug: {value}")
   System.out.println(result);
   
   GOOD:
   logger.debug('User fetched', { userId: user.id });
   logger.info('Processing order', { orderId });
   logging.debug(f"Processing: {value}")
   LOGGER.debug("Result: {}", result);
   ```

9. **Inconsistent Naming Style**
   ```
   BAD (mixed in same file):
   const user_name = ...
   const userEmail = ...
   const UserAge = ...
   
   function get_user() {}
   function saveUser() {}
   function ProcessOrder() {}
   
   GOOD (consistent):
   const userName = ...
   const userEmail = ...
   const userAge = ...
   
   function getUser() {}
   function saveUser() {}
   function processOrder() {}
   ```

10. **Negated Boolean Names**
    ```
    BAD:
    isNotValid, isNotEmpty, hasNoErrors, cannotProceed, isInactive
    if (!isNotValid)  // Double negative
    
    GOOD:
    isValid, isEmpty, hasErrors, canProceed, isActive
    if (isValid)
    if (!isEmpty)
    ```

### MUST

1. **Boolean Variables/Functions Use Prefixes**
   ```
   Prefixes: is, has, can, should, will, was, did, does
   
   GOOD:
   isActive, isValid, isLoading, isEmpty, isAuthenticated
   hasPermission, hasErrors, hasChildren, hasMore
   canEdit, canDelete, canProceed, canSubmit
   shouldRefresh, shouldRetry, shouldCache
   willExpire, willRedirect
   wasModified, wasSaved
   didComplete, didFail
   doesExist, doesMatch
   ```

2. **Async Functions Have Verb Prefixes or Async Suffix**
   ```
   GOOD:
   fetchUser(), fetchOrders(), fetchConfig()
   loadProfile(), loadSettings()
   saveOrder(), saveDocument()
   sendEmail(), sendNotification()
   
   OR with suffix:
   getUserAsync(), processOrderAsync()
   ```

3. **Collections Use Plural Names**
   ```
   BAD:
   const user = getUsers();       // Returns array
   const item = [1, 2, 3];        // Is array
   for (const users of userList)  // Single item
   
   GOOD:
   const users = getUsers();      // Returns array
   const items = [1, 2, 3];       // Is array
   for (const user of users)      // Single item from collection
   ```

4. **Constants Use UPPER_SNAKE_CASE**
   ```
   GOOD:
   MAX_RETRIES = 3
   DEFAULT_TIMEOUT = 30000
   API_BASE_URL = "https://..."
   SECONDS_PER_DAY = 86400
   
   BAD:
   maxRetries = 3           // Looks mutable
   defaultTimeout = 30000   // Looks mutable
   ```

5. **Descriptive Error Messages**
   ```
   BAD:
   throw new Error('Invalid');
   throw new Error('Failed');
   raise Exception('Error')
   
   GOOD:
   throw new Error(`Invalid email format: ${email}`);
   throw new Error(`Order ${orderId} not found`);
   raise ValueError(f"User {user_id} does not have permission to {action}")
   ```

6. **Function Names Are Verb Phrases**
   ```
   BAD:
   user()           // Noun
   validation()     // Noun
   email()          // Noun
   
   GOOD:
   getUser()        // Verb + Noun
   validateInput()  // Verb + Noun
   sendEmail()      // Verb + Noun
   ```

---

## Patterns

### Naming Decision Tree
```
Is it a boolean?
  → Use is/has/can/should/will/was/did prefix

Is it a collection?
  → Use plural noun (users, orders, items)

Is it a constant?
  → Use UPPER_SNAKE_CASE

Is it a function?
  → Start with verb (get, set, fetch, save, process, validate, etc.)

Is it async?
  → Use fetch/load/save/send verb OR Async suffix

Everything else?
  → Use domain-specific noun (user, order, invoice, NOT data, item, result)
   ```

### Common Verb Prefixes
```
Retrieval:  get, fetch, load, find, query, read, retrieve
Creation:   create, make, build, generate, produce, init
Mutation:   set, update, modify, change, edit, save, write
Deletion:   delete, remove, clear, reset, destroy, drop
Validation: validate, check, verify, ensure, assert, confirm
Conversion: to, from, parse, format, transform, convert, map
Boolean:    is, has, can, should, will, was, did, does
Lifecycle:  start, stop, begin, end, open, close, init, cleanup
```

### Domain Term Examples
```
E-commerce: order, product, cart, checkout, inventory, shipment
Auth:       user, session, token, permission, role, credential
Finance:    transaction, payment, invoice, balance, account, transfer
Content:    post, article, comment, author, category, tag
Messaging:  message, thread, recipient, notification, channel
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `data`, `result`, `item` | No meaning | Domain noun |
| `handleData()` | Generic verb+noun | `processOrder()` |
| `x === true` | Redundant | `x` |
| `cond ? true : false` | Redundant | `cond` |
| `if (x) return true; else return false` | Redundant | `return x` |
| `60 * 60 * 1000` | Magic calculation | `MILLISECONDS_PER_HOUR` |
| `const x = ...` | Single letter | Descriptive name |
| `console.log()` | Debug in prod | Logger |
| `isNotValid` | Negative boolean | `isValid` + negate |
| `user` for array | Singular for plural | `users` |
| `maxRetries` | Looks mutable | `MAX_RETRIES` |
| `throw Error('Failed')` | Unhelpful | Include context |

---

## Language-Specific Notes

### JavaScript/TypeScript
- camelCase for variables/functions
- PascalCase for classes/components/types
- UPPER_SNAKE_CASE for constants
- Prefix interfaces with `I` only if your team requires it

### Python
- snake_case for variables/functions
- PascalCase for classes
- UPPER_SNAKE_CASE for constants
- Prefix private with `_`

### Go
- camelCase for unexported, PascalCase for exported
- Short names OK for small scope (receiver `s` for short method)
- Avoid stuttering: `user.User` → `user.Info`

### Rust
- snake_case for variables/functions
- PascalCase for types/traits
- UPPER_SNAKE_CASE for constants
- Prefix unused with `_`
