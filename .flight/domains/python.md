# Domain: Python Design

Production Python patterns for clean, maintainable, type-safe code. Prevents common mistakes like mutable defaults, bare exceptions, and silent failures.


**Validation:** `python.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // # noqa
```

---

## Invariants

### NEVER (validator will reject)

1. **Bare except:** - Never use bare 'except:' which catches everything including KeyboardInterrupt and SystemExit.

   ```
   // BAD
   try:
       do_something()
   except:
       pass
   

   // GOOD
   try:
       do_something()
   except ValueError as e:
       handle_error(e)
   
   ```

2. **except Exception: pass** - Never silently swallow exceptions with 'except Exception: pass'. Silent failures hide bugs and make debugging impossible.

   ```
   // BAD
   try:
       risky_operation()
   except Exception:
       pass
   

   // GOOD
   try:
       risky_operation()
   except SpecificError as e:
       logger.warning(f"Operation failed: {e}")
       return default_value
   
   ```

3. **Mutable Default Arguments** - Never use mutable default arguments (=[], ={}, =set()). Default arguments are evaluated once at function definition, causing shared state across calls.

   ```
   // BAD
   def add_item(item, items=[]):
   // BAD
   def merge_data(data, result={}):

   // GOOD
   def add_item(item, items=None):
       if items is None:
           items = []
       items.append(item)
       return items
   
   ```

4. **from x import *** - Never use wildcard imports. They pollute the namespace and hide where names come from.

   ```
   // BAD
   from os import *
   // BAD
   from utils import *

   // GOOD
   from os import path, getcwd
   // GOOD
   from utils import validate_input, format_output
   ```

5. **type(x) == for Type Checking** - Never use type() for type checking. It breaks inheritance and doesn't work with abstract base classes.

   ```
   // BAD
   if type(obj) == list:
   // BAD
   if type(x) == str:

   // GOOD
   if isinstance(obj, list):
   // GOOD
   if isinstance(x, (str, bytes)):
   ```

6. **Generic Variable Names at Module Level** - Never use generic variable names (data, temp, result, info, obj) at module level. Use domain-specific names.

   ```
   // BAD
   data = load_users()
   // BAD
   result = process()

   // GOOD
   users = load_users()
   // GOOD
   processed_orders = process()
   ```

7. **print() Outside __main__** - Never use print() for logging outside of __main__ blocks. Use the logging module for proper log levels and context.

   ```
   // BAD
   print(f"Processing user {user_id}")
   // BAD
   print(f"Error: {e}")

   // GOOD
   import logging
   logger = logging.getLogger(__name__)
   logger.info(f"Processing user {user_id}")
   
   ```

8. **Hardcoded Absolute Paths** - Never hardcode absolute paths. They break across environments and operating systems.

   ```
   // BAD
   config_path = "/home/user/app/config.json"
   // BAD
   output_dir = "C:\\Users\\app\\output"

   // GOOD
   from pathlib import Path
   CONFIG_PATH = Path(__file__).parent / "config.json"
   
   ```

9. **Deeply Nested Conditionals** - Never nest conditionals more than 3 levels deep. Use early returns to flatten the structure.

   ```
   // BAD
   if user:
       if user.is_active:
           if user.has_permission:
               if not user.is_banned:
                   do_action()
   

   // GOOD
   if not user:
       return
   if not user.is_active:
       return
   if not user.has_permission:
       return
   if user.is_banned:
       return
   do_action()
   
   ```

### SHOULD (validator warns)

1. **String += Patterns** - Avoid string concatenation with += in loops. It creates O(n²) complexity due to string immutability.

   ```
   // BAD
   result = ""
   for item in items:
       result += str(item) + ", "
   

   // GOOD
   result = ", ".join(str(item) for item in items)
   ```

2. **Magic Numbers in Logic** - Avoid magic numbers in conditionals and function calls. Use named constants for clarity.

   ```
   // BAD
   if retry_count > 3:
   // BAD
   time.sleep(86400)

   // GOOD
   MAX_RETRIES = 3
   SECONDS_PER_DAY = 86400
   if retry_count > MAX_RETRIES:
       raise TooManyRetries()
   
   ```

3. **Type Hints on Public Functions** - Public functions should have type hints for parameters and return values to enable static analysis and documentation.

   ```
   // BAD
   def calculate_total(items, tax_rate):
       return sum(i.price for i in items) * (1 + tax_rate)
   

   // GOOD
   def calculate_total(items: list[LineItem], tax_rate: float) -> Decimal:
       return sum(i.price for i in items) * (1 + tax_rate)
   
   ```

4. **if __name__ == __main__ Guard** - Scripts with a main() function should have an 'if __name__ == "__main__":' guard.

   ```
   def main():
       app = create_app()
       app.run()
   
   if __name__ == "__main__":
       main()
   ```

5. **Use pathlib for File Operations** - Prefer pathlib over os.path for file operations. pathlib provides a cleaner, more object-oriented API.

   ```
   // BAD
   import os
   config_path = os.path.join(base_dir, "config.json")
   

   // GOOD
   from pathlib import Path
   config_path = Path(base_dir) / "config.json"
   
   ```

6. **Use logging Module** - Large files (>50 lines) should use the logging module for proper log levels and configuration.

   ```
   import logging
   logger = logging.getLogger(__name__)
   
   logger.debug("Detailed info for debugging")
   logger.info("General information")
   logger.warning("Something unexpected")
   logger.error("Error occurred", exc_info=True)
   ```

7. **Docstrings on Public Functions** - Public functions should have docstrings explaining their purpose, arguments, and return values.

   ```
   def calculate_shipping(
       weight: float,
       destination: str,
       express: bool = False
   ) -> Decimal:
       """Calculate shipping cost for an order.
   
       Args:
           weight: Package weight in kg
           destination: Country code (ISO 3166-1)
           express: Whether to use express shipping
   
       Returns:
           Shipping cost in USD
   
       Raises:
           InvalidDestination: If country code not supported
       """
   ```

### GUIDANCE (not mechanically checked)

1. **Module Structure** - Standard module structure with imports organized by category, module-level constants, and main guard.


2. **Error Handling Pattern** - Define custom exception hierarchies for your domain. Catch specific exceptions and log appropriately.


3. **Configuration Pattern** - Use pydantic-settings for type-safe configuration from environment variables.


4. **Async Pattern** - Use asyncio.gather for concurrent operations and async iterators for streaming.


5. **Use Dataclasses or Pydantic** - Use dataclasses or Pydantic models for structured data instead of plain dicts or tuples.


6. **Use Enums for Fixed Choices** - Use Enum classes for values with a fixed set of choices.


7. **Use Comprehensions** - Use list/dict/set comprehensions for simple transformations instead of explicit loops.


8. **Context Managers for Resources** - Use context managers (with statement) for resources that need cleanup.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| except: |  | Specific exceptions |
| except Exception: pass |  | Log or handle |
| def f(x=[]) |  | x=None pattern |
| from x import * |  | Explicit imports |
| s += item in loop |  | "".join() |
| type(x) == Y |  | isinstance() |
| print() for logs |  | logging module |
| Magic numbers |  | Named constants |
| No type hints |  | Add annotations |
| Nested if > 3 |  | Early returns |
| Hardcoded paths |  | pathlib.Path |
| Generic names |  | Domain terms |
