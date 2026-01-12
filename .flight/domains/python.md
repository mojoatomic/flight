# Domain: Python

Production Python patterns for clean, maintainable, type-safe code.

---

## Invariants

### NEVER

1. **Bare `except:`** - Catches everything including KeyboardInterrupt
   ```python
   # BAD
   try:
       do_something()
   except:
       pass
   
   # GOOD
   try:
       do_something()
   except ValueError as e:
       handle_error(e)
   except (TypeError, KeyError) as e:
       handle_other_error(e)
   ```

2. **`except Exception:` with `pass`** - Silent failures hide bugs
   ```python
   # BAD
   try:
       risky_operation()
   except Exception:
       pass
   
   # GOOD
   try:
       risky_operation()
   except SpecificError as e:
       logger.warning(f"Operation failed: {e}")
       return default_value
   ```

3. **Mutable Default Arguments** - Shared across calls
   ```python
   # BAD
   def add_item(item, items=[]):
       items.append(item)
       return items
   
   # GOOD
   def add_item(item, items=None):
       if items is None:
           items = []
       items.append(item)
       return items
   ```

4. **`from module import *`** - Pollutes namespace, hides dependencies
   ```python
   # BAD
   from os import *
   from utils import *
   
   # GOOD
   from os import path, getcwd
   from utils import validate_input, format_output
   ```

5. **String Concatenation in Loops** - O(n²) complexity
   ```python
   # BAD
   result = ""
   for item in items:
       result += str(item) + ", "
   
   # GOOD
   result = ", ".join(str(item) for item in items)
   ```

6. **`type()` for Type Checking** - Breaks inheritance
   ```python
   # BAD
   if type(obj) == list:
       process_list(obj)
   
   # GOOD
   if isinstance(obj, list):
       process_list(obj)
   
   # BETTER - duck typing
   if hasattr(obj, '__iter__'):
       process_iterable(obj)
   ```

7. **Magic Numbers** - Unexplained constants
   ```python
   # BAD
   if retry_count > 3:
       raise TooManyRetries()
   time.sleep(86400)
   
   # GOOD
   MAX_RETRIES = 3
   SECONDS_PER_DAY = 86400
   
   if retry_count > MAX_RETRIES:
       raise TooManyRetries()
   time.sleep(SECONDS_PER_DAY)
   ```

8. **Generic Variable Names** - `data`, `temp`, `result`, `info`, `item`, `obj`
   ```python
   # BAD
   def process(data):
       result = transform(data)
       return result
   
   # GOOD
   def process_order(order: Order) -> Invoice:
       invoice = transform_to_invoice(order)
       return invoice
   ```

9. **Nested Conditionals > 3 Deep** - Hard to follow
   ```python
   # BAD
   if user:
       if user.is_active:
           if user.has_permission:
               if not user.is_banned:
                   do_action()
   
   # GOOD - early returns
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

10. **`print()` for Logging** - No levels, no context
    ```python
    # BAD
    print(f"Processing user {user_id}")
    print(f"Error: {e}")
    
    # GOOD
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info(f"Processing user {user_id}")
    logger.error(f"Processing failed: {e}", exc_info=True)
    ```

11. **Hardcoded Paths** - Breaks across environments
    ```python
    # BAD
    config_path = "/home/user/app/config.json"
    output_dir = "C:\\Users\\app\\output"
    
    # GOOD
    from pathlib import Path
    
    CONFIG_PATH = Path(__file__).parent / "config.json"
    OUTPUT_DIR = Path.home() / "app" / "output"
    ```

12. **No Type Hints on Public Functions**
    ```python
    # BAD
    def calculate_total(items, tax_rate):
        return sum(i.price for i in items) * (1 + tax_rate)
    
    # GOOD
    def calculate_total(items: list[LineItem], tax_rate: float) -> Decimal:
        return sum(i.price for i in items) * (1 + tax_rate)
    ```

### MUST

1. **Use Type Hints for Function Signatures**
   ```python
   def get_user(user_id: str) -> User | None:
       ...
   
   def process_items(items: list[Item]) -> dict[str, int]:
       ...
   ```

2. **Use `pathlib` for File Paths**
   ```python
   from pathlib import Path
   
   config_file = Path("config") / "settings.json"
   if config_file.exists():
       content = config_file.read_text()
   ```

3. **Use Context Managers for Resources**
   ```python
   # Files
   with open("data.txt") as f:
       content = f.read()
   
   # Database connections
   with db.connection() as conn:
       conn.execute(query)
   
   # Locks
   with threading.Lock():
       shared_resource.update()
   ```

4. **Use `logging` Module**
   ```python
   import logging
   
   logger = logging.getLogger(__name__)
   
   logger.debug("Detailed info for debugging")
   logger.info("General information")
   logger.warning("Something unexpected")
   logger.error("Error occurred", exc_info=True)
   ```

5. **Use Dataclasses or Pydantic for Data Structures**
   ```python
   from dataclasses import dataclass
   from typing import Optional
   
   @dataclass
   class User:
       id: str
       email: str
       name: str
       is_active: bool = True
       metadata: Optional[dict] = None
   ```

6. **Use Enums for Fixed Choices**
   ```python
   from enum import Enum, auto
   
   class OrderStatus(Enum):
       PENDING = auto()
       PROCESSING = auto()
       SHIPPED = auto()
       DELIVERED = auto()
   
   def update_status(order: Order, status: OrderStatus) -> None:
       order.status = status
   ```

7. **Use List/Dict/Set Comprehensions**
   ```python
   # Instead of loops for simple transforms
   squares = [x ** 2 for x in range(10)]
   user_map = {u.id: u for u in users}
   unique_names = {u.name for u in users}
   
   # With conditions
   active_users = [u for u in users if u.is_active]
   ```

8. **Use `if __name__ == "__main__":`**
   ```python
   def main():
       app = create_app()
       app.run()
   
   if __name__ == "__main__":
       main()
   ```

9. **Docstrings for Public Functions**
   ```python
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

---

## Patterns

### Module Structure
```python
"""Module docstring explaining purpose."""

# Standard library imports
import logging
from pathlib import Path
from typing import Optional

# Third-party imports
import requests
from pydantic import BaseModel

# Local imports
from .utils import validate
from .models import User

# Module-level constants
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30

# Logger
logger = logging.getLogger(__name__)


# Classes and functions
class UserService:
    ...


def main():
    ...


if __name__ == "__main__":
    main()
```

### Error Handling
```python
class OrderError(Exception):
    """Base exception for order operations."""
    pass

class OrderNotFound(OrderError):
    """Raised when order doesn't exist."""
    pass

class InvalidOrderStatus(OrderError):
    """Raised when order status transition is invalid."""
    pass


def get_order(order_id: str) -> Order:
    """Fetch order by ID.
    
    Raises:
        OrderNotFound: If order doesn't exist
    """
    order = db.orders.get(order_id)
    if order is None:
        raise OrderNotFound(f"Order {order_id} not found")
    return order


# Usage
try:
    order = get_order(order_id)
except OrderNotFound:
    logger.warning(f"Order {order_id} not found")
    return None
except OrderError as e:
    logger.error(f"Order error: {e}")
    raise
```

### Configuration
```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings from environment."""
    
    database_url: str
    api_key: str
    debug: bool = False
    max_connections: int = 10
    
    class Config:
        env_file = ".env"


settings = Settings()
```

### Async Pattern
```python
import asyncio
from typing import AsyncIterator


async def fetch_users(user_ids: list[str]) -> list[User]:
    """Fetch multiple users concurrently."""
    tasks = [fetch_user(uid) for uid in user_ids]
    return await asyncio.gather(*tasks)


async def process_stream(items: AsyncIterator[Item]) -> None:
    """Process items from async stream."""
    async for item in items:
        await process_item(item)
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `except:` | Catches everything | Specific exceptions |
| `except Exception: pass` | Silent failure | Log or handle |
| `def f(x=[])` | Mutable default | `x=None` pattern |
| `from x import *` | Namespace pollution | Explicit imports |
| `s += item` in loop | O(n²) | `"".join()` |
| `type(x) == Y` | Breaks inheritance | `isinstance()` |
| `print()` for logs | No levels | `logging` module |
| Magic numbers | Unclear intent | Named constants |
| No type hints | Hard to maintain | Add annotations |
| Nested `if` > 3 | Hard to read | Early returns |
| Hardcoded paths | Not portable | `pathlib.Path` |
| Generic names | Unclear purpose | Domain terms |
