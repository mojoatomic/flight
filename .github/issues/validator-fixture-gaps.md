# Validator Test Fixtures Need Alignment with Actual Rules

**Status: ✅ RESOLVED** (2026-01-25)

## Summary

The test fixtures in `tests/validator-fixtures/` were created based on **assumptions** about what rules exist, not what rules are **actually defined** in the `.flight` domain files. This caused 6 out of 24 validators to "fail" their tests, even though the validators work correctly.

## Resolution

All 24 validators now pass. Fixtures were updated to contain violations matching actual rule patterns, and `expected.txt` files were adjusted to match actual detection counts.

## Original State

- **18 validators passed** their fixture tests
- **6 validators failed** due to mismatched expectations:
  - `clerk` - expected ≥3 failures, got 1
  - `nextjs` - expected ≥2 failures, got 1
  - `python` - expected ≥3 failures, got 2
  - `rust` - expected ≥2 failures, got 1
  - `scaffold` - expected ≥2 failures, got 0
  - `supabase` - expected ≥3 failures, got 1

## Root Causes

### 1. Fixtures contain violations for non-existent rules

**Example: Python**
```python
# Fixture has these violations:
eval(user_input)      # Assumed N1 rule exists - IT DOESN'T
exec(code)            # Assumed N2 rule exists - IT DOESN'T
pickle.loads(data)    # Assumed N3 rule exists - IT DOESN'T
```

**Actual Python rules:**
- N1: Bare `except:` (AST)
- N3: Mutable default arguments (AST)
- N4: `from x import *` (grep)
- N5: `type(x) ==` for type checking (grep)

The fixture's eval/exec/pickle violations aren't checked by any rule.

### 2. Rule IDs don't match fixture comments

**Example: Rust**
```rust
// Fixture comments say:
// N1: unwrap() in library code    <- Actual N1 is "unsafe without SAFETY comment"
// N2: expect() without context    <- Actual N2 is "mem::transmute"
// N3: panic! in library code      <- No N3 rule exists
```

### 3. Fixtures use wrong file types or patterns

**Example: Scaffold**
- Fixture contains: `package.json`, `tsconfig.json`
- Actual N1 rule checks for: `--force` flags in scaffold commands
- The JSON files don't contain anything the rule can match

### 4. AST rules require specific tree-sitter patterns

Some fixtures have code that looks like a violation but doesn't match the exact AST query defined in the rule.

## Required Fix

For each validator, we need to:

1. **Read the actual `.rules.json`** to understand what rules exist and their exact patterns
2. **Create fixture violations that match those patterns** exactly
3. **Update `expected.txt`** to reflect actual detection capability
4. **Document any rules that can't be practically tested** (e.g., presence checks)

## Detailed Gap Analysis

### clerk

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N2: Deprecated authMiddleware | `authMiddleware` import | ❌ No |
| N5: Hardcoded Clerk Keys | `pk_live_`, `sk_live_` patterns | ❌ No |

**Fix needed:** Add code with deprecated `authMiddleware` import and hardcoded Clerk keys

### nextjs

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N3: useEffect Fetch | AST: useEffect with fetch | ❌ No/unclear |
| N6: Hardcoded Routes | AST: literal multi-segment | ❌ No/unclear |
| N7: console.log | AST: console.log in app dir | ❌ No/unclear |

**Fix needed:** Create proper Next.js component files with these specific patterns

### python

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N1: Bare except | AST: `except:` without type | ✅ Yes (detected) |
| N3: Mutable defaults | AST: `=[]`, `={}`, `=set()` | ✅ Yes (detected) |
| N4: `from x import *` | grep | ❌ No |
| N5: `type(x) ==` | grep | ❌ No |
| N6: Generic names | grep for `data`, `result` at module level | ❌ No |
| N8: Hardcoded paths | grep for absolute paths | ❌ No |

**Fix needed:** Add `from os import *`, `type(x) == str`, generic module-level names, hardcoded paths

### rust

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N1: Unsafe without SAFETY | AST: unsafe block | ✅ Yes (detected) |
| N2: mem::transmute | AST | ❌ No |
| N5: expect() without message | grep: `.expect("")` | ❌ Pattern doesn't match fixture |
| N6: Raw pointer arithmetic | grep | ❌ No |
| N7: mem::forget | grep | ❌ No |

**Fix needed:** Add `mem::transmute`, proper `.expect("")` pattern, pointer arithmetic, `mem::forget`

### scaffold

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N1: Destructive flags | grep: `--force`, `--overwrite` | ❌ No |

**Fix needed:** Create file with scaffold commands using `--force` flag

### supabase

| Actual Rule | Pattern | Fixture Has Matching Violation? |
|-------------|---------|--------------------------------|
| N2: Deprecated auth-helpers | AST: import from auth-helpers-nextjs | ❌ No |
| N4: Hardcoded credentials | AST: literal strings in createClient | ❌ No (uses env vars) |

**Fix needed:** Add deprecated auth-helpers import, hardcoded credentials (not env vars)

## Acceptance Criteria

- [x] All 24 validators pass their fixture tests
- [x] Each fixture contains at least one violation per mechanical rule in that domain
- [x] `expected.txt` values match actual detection counts
- [x] Fixtures are documented with comments showing which rule each violation tests

## Labels

- `testing`
- `validator-fixtures`
- `good-first-issue` (individual validators can be fixed independently)

## Related Work

- Test runner infrastructure is complete (`.flight/tests/run-tests.sh`)
- flight-lint is built and working for AST rules
- Brace expansion fix applied to compiler
