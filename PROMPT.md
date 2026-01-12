# Task: P10-Compliant Traffic Light State Machine

## Objective

Implement a finite state machine for a traffic light controller following NASA JPL Power of 10 rules, with executable validation.

## Context

Simple 3-state traffic light: RED → GREEN → YELLOW → RED. Each state has a configurable duration. A `tick()` function advances time and handles transitions. All code must pass `p10_validate.sh` checks.

## Invariants

### MUST

| ID | Rule | Validation |
|----|------|------------|
| M1 | Compile clean | `gcc -Wall -Wextra -Werror -pedantic -std=c11 -fsyntax-only` |
| M2 | Functions ≤60 lines | awk script in validator |
| M3 | ≥2 `ASSERT()` per function | awk script in validator |
| M4 | `printf`/`fprintf` cast to `(void)` | grep check |
| M5 | Simple control flow | Only `if`, `else`, `for`, `while`, `switch` with `default` |
| M6 | Fixed loop bounds | `for (uint32_t i = 0U; i < MAX_X; i++)` pattern |
| M7 | Static memory only | No heap allocation |
| M8 | Minimal scope | Declare at smallest scope, initialize at declaration |
| M9 | Single pointer dereference | No `**ptr` |
| M10 | All variables initialized | At declaration |

### NEVER

| ID | Rule | Check |
|----|------|-------|
| N1 | `goto` | `grep "goto "` |
| N2 | `setjmp`/`longjmp` | `grep "setjmp\|longjmp"` |
| N3 | `malloc`/`free`/`calloc`/`realloc` | `grep "\b(malloc|free|calloc|realloc)\b"` |
| N4 | `#ifdef`/`#if` | `grep "^#ifdef\|^#if "` |
| N5 | `**ptr` | `grep "[^/]\*\*[a-zA-Z]"` |
| N6 | `->field->field` | `grep "->.*->"` |
| N7 | `while(1)`/`for(;;)` | `grep "while\s*(1)\|for\s*(;;)"` |
| N8 | Magic numbers | Use `#define` constants |
| N9 | Uninitialized variables | Initialize at declaration |
| N10 | Recursion | No function calls itself |

## Implementation Requirements

### Files to Create

1. **`.flight/domains/p10_validate.sh`** - Validation script (from domain file)

2. **`src/traffic_light.h`** - Public header containing:
   - Include guards
   - `#include <stdint.h>`
   - Duration constants: `TRAFFIC_DURATION_RED`, `TRAFFIC_DURATION_GREEN`, `TRAFFIC_DURATION_YELLOW`
   - `status_t` enum
   - `traffic_state_t` enum: `TRAFFIC_STATE_RED`, `TRAFFIC_STATE_YELLOW`, `TRAFFIC_STATE_GREEN`
   - `traffic_light_t` struct
   - `ASSERT` macro
   - `extern void assert_failed(...)` declaration
   - Function prototypes with Doxygen comments

3. **`src/traffic_light.c`** - Implementation containing:
   - `traffic_light_init(traffic_light_t *tl)` - Initialize to RED, elapsed=0
   - `traffic_light_tick(traffic_light_t *tl, traffic_state_t *state)` - Advance time, transition if needed, return current state
   - `traffic_light_get_state(const traffic_light_t *tl, traffic_state_t *state)` - Query current state

### Data Structures

```c
#define TRAFFIC_DURATION_RED    30U
#define TRAFFIC_DURATION_GREEN  25U
#define TRAFFIC_DURATION_YELLOW 5U

typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR = -1,
    STATUS_INVALID_PARAM = -2
} status_t;

typedef enum {
    TRAFFIC_STATE_RED = 0,
    TRAFFIC_STATE_YELLOW = 1,
    TRAFFIC_STATE_GREEN = 2
} traffic_state_t;

typedef struct {
    traffic_state_t state;
    uint32_t elapsed_ticks;
} traffic_light_t;
```

### State Machine Logic

```
Transitions:
  RED    --[elapsed >= DURATION_RED]-->    GREEN  (reset elapsed)
  GREEN  --[elapsed >= DURATION_GREEN]-->  YELLOW (reset elapsed)
  YELLOW --[elapsed >= DURATION_YELLOW]--> RED    (reset elapsed)

tick() behavior:
  1. Increment elapsed_ticks
  2. Check if elapsed >= duration for current state
  3. If yes: transition to next state, reset elapsed to 0
  4. Return current state via output parameter
```

## Patterns to Follow

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

### ASSERT Macro
```c
#define ASSERT(expr) \
    do { if (!(expr)) { assert_failed(__FILE__, __LINE__, #expr); } } while (0)
```

### Switch with Default
```c
switch (tl->state)
{
    case TRAFFIC_STATE_RED:
        /* handle */
        break;
    case TRAFFIC_STATE_GREEN:
        /* handle */
        break;
    case TRAFFIC_STATE_YELLOW:
        /* handle */
        break;
    default:
        result = STATUS_ERROR;
        break;
}
```

## Acceptance Criteria

- [ ] `.flight/domains/p10_validate.sh` exists and is executable
- [ ] `src/traffic_light.h` exists with all types and prototypes
- [ ] `src/traffic_light.c` exists with all function implementations
- [ ] Each function has ≥2 `ASSERT()` calls
- [ ] No function exceeds 60 lines
- [ ] All variables initialized at declaration
- [ ] No forbidden patterns (goto, malloc, #ifdef, **, ->->)
- [ ] Compiles with `gcc -Wall -Wextra -Werror -pedantic -std=c11`
- [ ] `.flight/domains/p10_validate.sh src/traffic_light.c src/traffic_light.h` passes all checks

## Validation

Run this command to validate:

```bash
chmod +x .flight/domains/p10_validate.sh
.flight/domains/p10_validate.sh src/traffic_light.c src/traffic_light.h
```

Expected output: `RESULT: PASS` with 0 failures.

## Completion

When ALL acceptance criteria are met and `p10_validate.sh` reports PASS:

```
COMPLETE
```

If blocked after significant effort:

```
BLOCKED: [detailed reason]
```
