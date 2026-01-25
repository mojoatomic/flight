# Domain: Code-Hygiene Design

Universal code quality patterns that apply to ALL languages. These are AI-generated code smells that transcend syntax. The name should describe WHAT it holds, not THAT it holds something.


**Validation:** `code-hygiene.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Generic Variable Names** - Do not use generic names like data, result, temp, item, value, obj. The name should describe WHAT it holds, not THAT it holds something.

   ```
   // BAD
   const data = getUser();
   // BAD
   let result = calculate();
   // BAD
   const temp = items.filter(...);
   // BAD
   const item = response.body;
   // BAD
   let value = config.timeout;
   // BAD
   const obj = JSON.parse(str);

   // GOOD
   const user = getUser();
   // GOOD
   const total = calculate();
   // GOOD
   const activeUsers = items.filter(...);
   // GOOD
   const orderDetails = response.body;
   // GOOD
   let timeoutMs = config.timeout;
   // GOOD
   const settings = JSON.parse(str);
   ```

2. **Redundant Conditional Returns** - Do not use if/else to return boolean literals. Return the condition directly.

   ```
   // BAD
   if (condition) return true; else return false;
   // BAD
   if (condition) { return true; } return false;
   // BAD
   if (condition) return false; else return true;

   // GOOD
   return condition;
   // GOOD
   return !condition;
   ```

3. **Ternary Returning Boolean Literals** - Do not use ternary operator to return true/false. Use the condition directly.

   ```
   // BAD
   condition ? true : false
   // BAD
   condition ? false : true
   // BAD
   x === y ? true : false
   // BAD
   isValid ? true : false

   // GOOD
   condition
   // GOOD
   !condition
   // GOOD
   x === y
   // GOOD
   isValid
   ```

4. **Redundant Boolean Comparisons** - Do not compare booleans to true/false. Use the boolean directly.

   ```
   // BAD
   if (isValid === true)
   // BAD
   while (hasMore === false)
   // BAD
   if (x == true)
   // BAD
   if (x !== false)

   // GOOD
   if (isValid)
   // GOOD
   while (!hasMore)
   // GOOD
   if (x)
   // GOOD
   if (x)
   ```

5. **Magic Number Calculations** - Do not use raw arithmetic for time/size calculations. Define named constants.

   ```
   // BAD
   sleep(86400)
   // BAD
   timeout = 60 * 60 * 1000
   // BAD
   maxAge = 7 * 24 * 60 * 60
   // BAD
   buffer = 1024 * 1024

   // GOOD
   SECONDS_PER_DAY = 86400
   sleep(SECONDS_PER_DAY)
   
   // GOOD
   MILLISECONDS_PER_HOUR = 60 * 60 * 1000
   timeout = MILLISECONDS_PER_HOUR
   
   // GOOD
   ONE_WEEK_SECONDS = 7 * 24 * 60 * 60
   maxAge = ONE_WEEK_SECONDS
   
   // GOOD
   ONE_MEGABYTE = 1024 * 1024
   buffer = ONE_MEGABYTE
   
   ```

6. **Generic Function Names** - Function names should include the domain noun they operate on. Avoid handleData, processItem, doSomething, etc.

   ```
   // BAD
   function handleData() {}
   // BAD
   function processItem() {}
   // BAD
   function doSomething() {}
   // BAD
   def handle_data():
   // BAD
   def process_item():

   // GOOD
   function validateUserEmail() {}
   // GOOD
   function processOrderPayment() {}
   // GOOD
   function handleLoginSubmit() {}
   // GOOD
   def validate_user_email():
   // GOOD
   def process_order_payment():
   ```

7. **Single-Letter Variables Outside Loops** - Single-letter variables are only acceptable as loop counters (i, j, k) or in very short lambdas. Otherwise use descriptive names.

   ```
   // BAD
   const x = getUser();
   // BAD
   let n = items.length;
   // BAD
   const s = name.toLowerCase();
   // BAD
   const t = Date.now();

   // GOOD
   const user = getUser();
   // GOOD
   let itemCount = items.length;
   // GOOD
   const normalizedName = name.toLowerCase();
   // GOOD
   const timestamp = Date.now();
   // GOOD
   for (let i = 0; i < 10; i++)  // OK in loops
   // GOOD
   items.map((x, i) => x * 2)  // OK in simple lambdas
   ```

8. **Console/Print Debugging in Production Code** - Do not leave console.log, print, or similar debugging statements in production code. Use a proper logging framework.

   ```
   // BAD
   console.log('user:', user);
   // BAD
   console.log(data);
   // BAD
   print(f"debug: {value}")
   // BAD
   System.out.println(result);
   // BAD
   println!("debug: {:?}", value);
   // BAD
   fmt.Println(data)

   // GOOD
   logger.debug('User fetched', { userId: user.id });
   // GOOD
   logger.info('Processing order', { orderId });
   // GOOD
   logging.debug(f"Processing: {value}")
   // GOOD
   LOGGER.debug("Result: {}", result);
   // GOOD
   log::debug!("Processing: {:?}", value);
   // GOOD
   log.Debug("Processing", "data", data)
   ```

9. **Negated Boolean Names** - Avoid boolean names with negative prefixes (isNot, hasNo, cannot). They lead to confusing double negatives like !isNotValid.

   ```
   // BAD
   isNotValid
   // BAD
   isNotEmpty
   // BAD
   hasNoErrors
   // BAD
   cannotProceed
   // BAD
   if (!isNotValid)  // Double negative!

   // GOOD
   isValid
   // GOOD
   isEmpty
   // GOOD
   hasErrors
   // GOOD
   canProceed
   // GOOD
   if (isValid)
   // GOOD
   if (!isEmpty)
   ```

10. **snake_case Declaration in JavaScript/TypeScript** - JavaScript and TypeScript declarations should use camelCase, not snake_case. This checks variable declarations, function names, and method names. Property access and object literals (e.g., API responses) are NOT checked.

   ```
   // BAD
   const user_name = 'alice';
   // BAD
   function get_user_by_id(id) { ... }
   // BAD
   const fetch_data = async () => { ... };

   // GOOD
   const userName = 'alice';
   // GOOD
   function getUserById(id) { ... }
   // GOOD
   const fetchData = async () => { ... };
   // GOOD
   // Object literals with external data are OK:
   // GOOD
   const response = { user_id: 123, created_at: date };
   ```

11. **camelCase Declaration in Python** - Python declarations should use snake_case, not camelCase (PEP 8). This checks function definitions and variable assignments. Class names (PascalCase) are NOT flagged.

   ```
   // BAD
   def getUserById(user_id): ...
   // BAD
   userName = 'alice'

   // GOOD
   def get_user_by_id(user_id): ...
   // GOOD
   user_name = 'alice'
   // GOOD
   class UserManager:  # PascalCase for classes is correct
   ```

12. **No Imports in /tmp Scripts** - Scripts in /tmp cannot import project dependencies. Run from the project directory or use the project's existing tooling.


   > Scripts written to /tmp don't have access to node_modules or other
project dependencies. This is a common AI coding assistant mistake.

WRONG: cat > /tmp/debug.mjs << 'EOF'
       import Parser from 'tree-sitter'

RIGHT: cd project-dir && node -e "const Parser = require('tree-sitter')..."
RIGHT: Use existing test fixtures in the project
RIGHT: Write script to project directory where dependencies are available

   ```
   // BAD
   cat > /tmp/debug.mjs << 'EOF'
   import Parser from 'tree-sitter';
   // This will fail - tree-sitter not in /tmp/node_modules
   EOF
   

   // GOOD
   # Run from project directory
   cd flight-lint && node -e "
     const Parser = require('tree-sitter');
     console.log(Parser);
   "
   
   // GOOD
   # Or write to project directory
   cat > ./debug-script.mjs << 'EOF'
   import Parser from 'tree-sitter';
   EOF
   node debug-script.mjs
   rm debug-script.mjs
   
   ```

13. **Hardcoded API Keys** - Do not hardcode API keys, tokens, or secrets in source code. Use environment variables or secret management systems instead.

   ```
   // BAD
   const API_KEY = 'sk-proj-abc123def456';
   // BAD
   apiKey: 'live_key_1234567890abcdef'
   // BAD
   const secret_key = "ghp_xxxxxxxxxxxxxxxxxxxx";
   // BAD
   API_SECRET = 'abcdefghijklmnopqrstuvwxyz'

   // GOOD
   const API_KEY = process.env.API_KEY;
   // GOOD
   apiKey: process.env.STRIPE_API_KEY
   // GOOD
   const secretKey = os.environ.get('SECRET_KEY')
   // GOOD
   # API keys loaded from .env file via dotenv
   ```

14. **Hardcoded Passwords and Secrets** - Do not hardcode passwords, database credentials, or authentication tokens in source code. These must come from environment variables or secret stores.

   ```
   // BAD
   const password = 'mysecretpassword123';
   // BAD
   db_pass: 'production_db_password'
   // BAD
   PASSWORD = "admin123456"
   // BAD
   auth_token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'

   // GOOD
   const password = process.env.DB_PASSWORD;
   // GOOD
   db_pass: process.env.DATABASE_PASSWORD
   // GOOD
   PASSWORD = os.environ['PASSWORD']
   // GOOD
   auth_token = getSecretFromVault('auth_token')
   ```

### MUST (validator will reject)

1. **Boolean Variables Use Proper Prefixes** - Boolean variables and functions should use is/has/can/should/will/was/did/does prefixes to clearly indicate they return a boolean.

   ```
   // BAD
   const valid = checkInput();
   // BAD
   let active = true;
   // BAD
   const empty = list.length === 0;

   // GOOD
   const isValid = checkInput();
   // GOOD
   let isActive = true;
   // GOOD
   const isEmpty = list.length === 0;
   // GOOD
   const hasPermission = user.role === 'admin';
   // GOOD
   const canEdit = hasPermission && !isLocked;
   // GOOD
   const shouldRefresh = cacheExpired || forceRefresh;
   ```

2. **Collections Use Plural Names** - Arrays, lists, sets, and other collections should use plural names. Singular names should be used for single items.

   ```
   // BAD
   const user = getUsers();  // Returns array
   // BAD
   const item = [1, 2, 3];  // Is array
   // BAD
   for (const users of userList)  // Single item

   // GOOD
   const users = getUsers();
   // GOOD
   const items = [1, 2, 3];
   // GOOD
   for (const user of users)
   ```

3. **Constants Use UPPER_SNAKE_CASE** - Constants (values that never change) should use UPPER_SNAKE_CASE to distinguish them from mutable variables.

   ```
   // BAD
   const maxRetries = 3;  // Looks mutable
   // BAD
   const defaultTimeout = 30000;
   // BAD
   const apiBaseUrl = "https://...";

   // GOOD
   const MAX_RETRIES = 3;
   // GOOD
   const DEFAULT_TIMEOUT = 30000;
   // GOOD
   const API_BASE_URL = "https://...";
   // GOOD
   const SECONDS_PER_DAY = 86400;
   ```

4. **Error Messages Include Context** - Error messages should include enough context to understand what failed and why. Generic messages like "Invalid" or "Failed" are useless.

   ```
   // BAD
   throw new Error('Invalid');
   // BAD
   throw new Error('Failed');
   // BAD
   raise Exception('Error')
   // BAD
   throw new Error('Not found');

   // GOOD
   throw new Error(`Invalid email format: ${email}`);
   // GOOD
   throw new Error(`Order ${orderId} not found`);
   // GOOD
   raise ValueError(f"User {user_id} does not have permission to {action}")
   // GOOD
   throw new Error(`Failed to connect to ${host}:${port} after ${retries} attempts`);
   ```

5. **Function Names Are Verb Phrases** - Function names should start with a verb that describes the action. Noun-only names don't describe what the function does.

   ```
   // BAD
   function user() {}
   // BAD
   function validation() {}
   // BAD
   function email() {}
   // BAD
   function data() {}

   // GOOD
   function getUser() {}
   // GOOD
   function validateInput() {}
   // GOOD
   function sendEmail() {}
   // GOOD
   function fetchData() {}
   // GOOD
   function calculateTotal() {}
   // GOOD
   function transformResponse() {}
   ```

### SHOULD (validator warns)

1. **Async Functions Use Appropriate Verb Prefixes** - Async functions should use verbs that imply I/O or waiting: fetch, load, save, send. Or use the Async suffix.


   > Verbs like fetch, load, save clearly indicate the function performs
I/O. This helps readers understand the function's behavior.

   ```
   async function fetchUser() {}
   async function loadConfig() {}
   async function saveOrder() {}
   async function sendNotification() {}
   async function getUserAsync() {}
   ```

2. **Use Domain-Specific Nouns** - Variable and function names should use domain-specific nouns that describe the business concept, not generic programming terms.


   > Domain nouns make code self-documenting and align with how stakeholders
talk about the system.

   ```
   // BAD
   const entity = getRecord();
   // BAD
   const collection = fetchList();

   // GOOD
   const customer = getCustomer();
   // GOOD
   const orderHistory = fetchOrders();
   // GOOD
   const invoiceItems = getLineItems();
   ```

### GUIDANCE (not mechanically checked)

1. **Naming Decision Tree** - Use this decision tree for naming variables and functions.


   > Is it a boolean?
  → Use is/has/can/should/will/was/did prefix

Is it a collection?
  → Use plural noun (users, orders, items)

Is it a constant?
  → Use UPPER_SNAKE_CASE

Is it a function?
  → Start with verb (get, set, fetch, save, validate, etc.)

Is it async?
  → Use fetch/load/save/send verb OR Async suffix

Everything else?
  → Use domain-specific noun (user, order, invoice, NOT data, item, result)


2. **Common Verb Prefixes** - Reference for choosing the right verb prefix for functions.


   > Retrieval:  get, fetch, load, find, query, read, retrieve
Creation:   create, make, build, generate, produce, init
Mutation:   set, update, modify, change, edit, save, write
Deletion:   delete, remove, clear, reset, destroy, drop
Validation: validate, check, verify, ensure, assert, confirm
Conversion: to, from, parse, format, transform, convert, map
Boolean:    is, has, can, should, will, was, did, does
Lifecycle:  start, stop, begin, end, open, close, init, cleanup
Async/Time: delay, wait, sleep, pause, retry, poll, defer, schedule, queue, batch, throttle, debounce


3. **Domain Term Examples** - Examples of domain-specific terms for common application types.


   > E-commerce: order, product, cart, checkout, inventory, shipment, customer
Auth:       user, session, token, permission, role, credential, identity
Finance:    transaction, payment, invoice, balance, account, transfer
Content:    post, article, comment, author, category, tag, publication
Messaging:  message, thread, recipient, notification, channel, conversation


4. **Language-Specific Conventions** - Follow the naming conventions of your language.


   > JavaScript/TypeScript:
  - camelCase for variables/functions
  - PascalCase for classes/components/types
  - UPPER_SNAKE_CASE for constants

Python:
  - snake_case for variables/functions
  - PascalCase for classes
  - UPPER_SNAKE_CASE for constants
  - Prefix private with _

Go:
  - camelCase for unexported, PascalCase for exported
  - Short names OK for small scope (receiver s for short method)
  - Avoid stuttering: user.User → user.Info

Rust:
  - snake_case for variables/functions
  - PascalCase for types/traits
  - UPPER_SNAKE_CASE for constants
  - Prefix unused with _

Java:
  - camelCase for variables/methods
  - PascalCase for classes
  - UPPER_SNAKE_CASE for constants
  - Prefix interfaces with I (if team requires)


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| data, result, item |  | Use domain noun (user, order, invoice) |
| handleData() |  | processOrder(), validateUser() |
| x === true |  | x |
| cond ? true : false |  | cond |
| if (x) return true; else return false |  | return x |
| 60 * 60 * 1000 |  | MILLISECONDS_PER_HOUR |
| const x = ... |  | const user = ... |
| console.log() |  | logger.debug() |
| isNotValid |  | isValid + negate when needed |
| user (for array) |  | users |
| maxRetries |  | MAX_RETRIES |
| throw Error('Failed') |  | Include what failed and why |
| function user() |  | function getUser() |
| mixed camel_Case |  | Pick one style per file |
| cat > /tmp/*.mjs ... import |  | Run from project dir or use existing tooling |
| API_KEY = 'sk-...' |  | Use process.env.API_KEY or secret management |
| password = 'secret123' |  | Use process.env.PASSWORD or secret store |
