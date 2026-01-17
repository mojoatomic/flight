# Domain: Embedded-C-P10 Design

Safety-critical embedded C following NASA JPL's "Power of 10" rules for reliable software. Reference: Gerard J. Holzmann, "The Power of 10: Rules for Developing Safety-Critical Code", IEEE Computer, 2006.


**Validation:** `embedded-c-p10.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **No goto** - Never use goto. It creates unstructured control flow that is difficult to analyze and verify. Use structured control flow (if, while, for, switch) instead.

   ```
   // BAD
   goto cleanup;
   // BAD
   goto error_handler;

   // GOOD
   return STATUS_ERROR;
   // GOOD
   if (error) { cleanup(); return STATUS_ERROR; }
   ```

2. **No setjmp/longjmp** - Never use setjmp or longjmp. They create non-local jumps that bypass normal control flow and make code impossible to analyze statically.

   ```
   // BAD
   if (setjmp(buf) == 0) { ... }
   // BAD
   longjmp(buf, 1);

   // GOOD
   return STATUS_ERROR;
   // GOOD
   Use structured error handling with return codes
   ```

3. **No Dynamic Memory Allocation** - Never use malloc, free, calloc, or realloc. Dynamic memory allocation introduces unpredictable behavior, fragmentation, and potential for memory leaks. Use static allocation with fixed-size buffers.

   ```
   // BAD
   char *buf = malloc(size);
   // BAD
   free(ptr);
   // BAD
   ptr = realloc(ptr, new_size);

   // GOOD
   static char buffer[MAX_BUFFER_SIZE];
   // GOOD
   char local_buf[FIXED_SIZE];
   ```

4. **No Conditional Compilation** - Never use #ifdef or #if. Conditional compilation creates multiple code paths that may not all be tested. Use runtime configuration or compile separate variants.

   ```
   // BAD
   #ifdef DEBUG
   // BAD
   #if FEATURE_ENABLED

   // GOOD
   #include <stdint.h>
   // GOOD
   #define MAX_ITEMS 100U
   ```

5. **No Double Pointer Dereference** - Never use double pointer dereference (**ptr). It indicates overly complex data structures. Flatten data structures or use single indirection with explicit indexing.

   ```
   // BAD
   **ptr = value;
   // BAD
   result = **data;

   // GOOD
   *ptr = value;
   // GOOD
   array[index].field = value;
   ```

6. **No Chained Pointer Access** - Never chain pointer dereferences (->field->field). It indicates overly coupled data structures. Use local variables to break the chain.

   ```
   // BAD
   value = ptr->inner->data;
   // BAD
   ptr->next->prev = node;

   // GOOD
   inner_t *inner = ptr->inner;
   value = inner->data;
   
   ```

7. **No Unbounded Loops** - Never use unbounded loops (while(1), while(true), for(;;)). All loops must have a fixed upper bound that can be statically verified.

   ```
   // BAD
   while (1) { ... }
   // BAD
   while (true) { ... }
   // BAD
   for (;;) { ... }

   // GOOD
   for (uint32_t i = 0U; i < MAX_ITERATIONS; i++) { ... }
   // GOOD
   while (count < MAX_COUNT) { ... count++; }
   ```

8. **Compile Clean with Strict Warnings** - Code must compile without warnings using strict compiler flags: -Wall -Wextra -Werror -pedantic -std=c11. Any warning is an error.

   ```
   // BAD
   // Code that produces any warning

   // GOOD
   // Code that compiles cleanly with all warnings enabled
   ```

9. **Functions Must Be 60 Lines or Less** - Every function must be 60 lines or less. This ensures functions fit on one screen and are easier to understand, test, and verify.

   ```
   // BAD
   // Function with more than 60 lines

   // GOOD
   // Function with 60 lines or less
   ```

10. **Minimum 2 Assertions Per Function** - Every function must have at least 2 ASSERT() calls - typically one for preconditions (input validation) and one for postconditions (output validation).

   ```
   // BAD
   status_t func(int *ptr) {
     // No assertions
     return STATUS_OK;
   }
   

   // GOOD
   status_t func(int *ptr) {
     ASSERT(ptr != NULL);
     // implementation
     ASSERT(result == STATUS_OK || result == STATUS_ERROR);
     return result;
   }
   
   ```

11. **Check or Cast All Return Values** - All function return values must be checked or explicitly cast to (void) if intentionally ignored. This applies especially to printf and fprintf.

   ```
   // BAD
   printf("Hello");
   // BAD
   fprintf(fp, "data");

   // GOOD
   (void)printf("Hello");
   // GOOD
   int ret = fprintf(fp, "data"); ASSERT(ret > 0);
   ```

### GUIDANCE (not mechanically checked)

1. **Simple Control Flow** - Use only simple control flow constructs: if, else, for, while, do-while, switch with default. No goto, setjmp, longjmp.


2. **Fixed Loop Bounds Pattern** - All loops must have a statically verifiable upper bound.


3. **Static Memory Only** - Use only static memory allocation. No heap allocation.


4. **Minimal Scope Principle** - Declare variables at the smallest possible scope and initialize at declaration.


5. **Limited Preprocessor Usage** - Use preprocessor only for includes and constant definitions. No conditional compilation.


6. **Function Template** - Standard function template with assertions and status return.


7. **Status Codes Pattern** - Standard status code enumeration for function return values.


8. **ASSERT Macro Pattern** - Custom ASSERT macro that captures file, line, and expression.


9. **No Magic Numbers** - All numeric constants must be named with #define or enum.


10. **No Recursion** - Never use recursion. It makes stack usage unpredictable and can lead to stack overflow. Use iteration instead.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| goto |  | Use structured control (if/while/for) |
| setjmp/longjmp |  | Use return codes |
| malloc/free |  | Static allocation only |
| #ifdef/#if |  | Compile separate variants |
| **ptr |  | Flatten structures |
| ->-> |  | Use local variables |
| while(1) |  | Use bounded loop with MAX |
| Magic numbers |  | Named constants (#define) |
| Recursion |  | Use iteration |
| Unchecked return |  | Check or cast to (void) |
