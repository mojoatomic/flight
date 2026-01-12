# Domain: Embedded C - NASA JPL Power of 10

Safety-critical embedded C following NASA JPL's "Power of 10" rules for reliable software.

**Reference**: Gerard J. Holzmann, "The Power of 10: Rules for Developing Safety-Critical Code", IEEE Computer, 2006

---

## Checks

Executable validation rules. Run with `p10_validate.sh *.c`

### NEVER Rules (must not appear)

| ID | Rule | Command | Pass If |
|----|------|---------|---------|
| N1 | No goto | `grep -n "goto " ${FILES}` | empty |
| N2 | No setjmp/longjmp | `grep -n "setjmp\|longjmp" ${FILES}` | empty |
| N3 | No malloc/free | `grep -n "\bmalloc\b\|\bfree\b\|\bcalloc\b\|\brealloc\b" ${FILES}` | empty |
| N4 | No #ifdef | `grep -n "^#ifdef\|^#if " ${FILES}` | empty |
| N5 | No double deref | `grep -n "[^/]\*\*[a-zA-Z]" ${FILES}` | empty |
| N6 | No chained -> | `grep -n "->.*->" ${FILES}` | empty |
| N7 | No unbounded loops | `grep -n "while\s*(1)\|while\s*(true)\|for\s*(;;)" ${FILES}` | empty |

### MUST Rules (must be satisfied)

| ID | Rule | Command | Pass If |
|----|------|---------|---------|
| M1 | Compile clean | `gcc -Wall -Wextra -Werror -pedantic -std=c11 -fsyntax-only ${FILES}` | empty |
| M2 | Functions ≤60 lines | See awk script below | empty |
| M3 | ≥2 asserts/function | See awk script below | empty |
| M4 | Returns checked | `grep -n "printf\|fprintf" ${FILES} \| grep -v "(void)"` | empty |

---

## Validation Script

Save as `p10_validate.sh` and run: `./p10_validate.sh *.c`

```bash
#!/bin/bash
set -euo pipefail

FILES="${@:-*.c}"
PASS=0
FAIL=0

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [ -z "$result" ]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        echo "$result" | head -5 | sed 's/^/   /'
        ((FAIL++))
    fi
}

echo "═══════════════════════════════════════════"
echo "  P10 Validation: $FILES"
echo "═══════════════════════════════════════════"
echo ""
echo "## NEVER Rules"
check "N1: No goto" grep -n "goto " $FILES
check "N2: No setjmp/longjmp" grep -n "setjmp\|longjmp" $FILES
check "N3: No malloc/free" grep -En "\b(malloc|free|calloc|realloc)\b" $FILES
check "N4: No #ifdef" grep -n "^#ifdef\|^#if " $FILES
check "N5: No **ptr" grep -n "[^/]\*\*[a-zA-Z]" $FILES
check "N6: No ->->" grep -n "->.*->" $FILES
check "N7: No while(1)" grep -En "while\s*\(1\)|while\s*\(true\)|for\s*\(;;\)" $FILES

echo ""
echo "## MUST Rules"
check "M1: Compile -Wall -Wextra -Werror" gcc -Wall -Wextra -Werror -pedantic -std=c11 -fsyntax-only $FILES

# M2: Function length check
check "M2: Functions ≤60 lines" awk '
/^(status_t|static|void|int|uint[0-9]+_t|bool) [a-z_]+\(/ { 
    start=NR; fname=$0; in_func=1 
}
/^}$/ && in_func { 
    len=NR-start
    if (len > 60) { 
        gsub(/\(.*/, "", fname)
        gsub(/^.* /, "", fname)
        print fname": "len" lines"
    }
    in_func=0 
}' $FILES

# M3: Assertion density check
check "M3: ≥2 asserts/function" awk '
/^(status_t|static|void|int|uint[0-9]+_t|bool) [a-z_]+\(/ { 
    fname=$0; asserts=0; in_func=1 
}
/ASSERT\(|assert\(/ && in_func { asserts++ }
/^}$/ && in_func { 
    if (asserts < 2) { 
        gsub(/\(.*/, "", fname)
        gsub(/^.* /, "", fname)
        print fname": "asserts" asserts"
    }
    in_func=0 
}' $FILES

# M4: Return value check
check "M4: printf returns cast to (void)" bash -c "grep -n 'printf\|fprintf' $FILES | grep -v '(void)' | grep -v '= ' || true"

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

exit $FAIL
```

---

## Invariants (for code generation)

### MUST

1. **Simple Control Flow** - Only `if`, `else`, `for`, `while`, `do-while`, `switch` with `default`
2. **Fixed Loop Bounds** - Pattern: `for (uint32_t i = 0U; i < MAX_X; i++)`
3. **Static Memory Only** - No heap allocation
4. **Function Length** - ≤60 lines
5. **Assertion Density** - ≥2 `ASSERT()` per function (precondition + postcondition)
6. **Minimal Scope** - Declare at smallest scope, initialize at declaration
7. **Check All Returns** - Or cast to `(void)`
8. **Limited Preprocessor** - Only `#include` and `#define` constants
9. **Restricted Pointers** - Single dereference only
10. **Zero Warnings** - `-Wall -Wextra -Werror -pedantic`

### NEVER

- `goto`, `setjmp`, `longjmp`
- `malloc`, `free`, `calloc`, `realloc`
- Recursion
- `#ifdef`, `#if`
- `while(1)`, `for(;;)`
- `**ptr`, `->field->field`
- Magic numbers
- Uninitialized variables

---

## Patterns

### Function Template
```c
status_t func_name(const input_t *in, output_t *out)
{
    ASSERT(in != NULL);
    ASSERT(out != NULL);
    
    status_t result = STATUS_OK;
    /* implementation */
    
    ASSERT(result == STATUS_OK || result == STATUS_ERROR);
    return result;
}
```

### Bounded Loop
```c
#define MAX_ITEMS 100U
for (uint32_t i = 0U; i < MAX_ITEMS; i++) { /* body */ }
```

### Status Codes
```c
typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR = -1,
    STATUS_INVALID_PARAM = -2,
    STATUS_BUFFER_FULL = -3,
    STATUS_BUFFER_EMPTY = -4
} status_t;
```

### ASSERT Macro
```c
#define ASSERT(expr) \
    do { if (!(expr)) { assert_failed(__FILE__, __LINE__, #expr); } } while (0)
```
