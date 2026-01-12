---
description: Analyze validation failures and strengthen domain rules to prevent recurrence
---

# /flight-tighten

Analyze validation failures and strengthen domain rules to prevent recurrence.

## Usage

```
/flight-tighten
```

Run after `/flight-validate` reports failures.

## Process

### 1. Review Validation Report

From the most recent `/flight-validate` output, identify:
- Which rules failed
- Which files violated them
- Pattern of failures

### 2. Root Cause Analysis

For each failure, determine:

```markdown
## Failure Analysis

### Failure: [description]

**What happened:**
[Specific violation]

**Why it happened:**
- [ ] Rule was ambiguous
- [ ] Rule was missing
- [ ] Rule conflicted with another rule
- [ ] Implementation misunderstood requirement
- [ ] Edge case not covered

**Root cause:**
[The actual underlying issue]
```

### 3. Categorize the Fix

| Category | Action |
|----------|--------|
| Missing rule | Add new invariant to domain |
| Ambiguous rule | Clarify with examples |
| Conflicting rules | Resolve conflict, document priority |
| Missing pattern | Add code example to domain |
| Edge case | Add specific handling rule |

### 4. Update Domain Files

Based on analysis, modify `.flight/domains/[domain].md`:

#### Adding a New Invariant

```markdown
### MUST
- [existing rules]
- **[NEW]** [New rule based on failure]
```

#### Clarifying Existing Rule

```markdown
### MUST
- [Rule] - **Clarification:** [specific guidance]

#### Example (correct):
```js
// This satisfies the rule
[code]
```

#### Example (incorrect):
```js
// This violates the rule
[code]
```
```

#### Adding Edge Case

```markdown
## Edge Cases

### [Scenario]
When [condition], MUST [behavior].

```js
// Example handling
[code]
```
```

### 5. Document the Change

```markdown
## Tightening Report

### Failures Analyzed
1. [failure 1]
2. [failure 2]

### Domain Updates

#### [domain].md

**Added:**
- New MUST rule: [description]

**Clarified:**
- [Rule]: Added example showing [correct pattern]

**Removed:**
- [Conflicting rule]: Replaced with [new rule]

### Verification

To verify fix, re-run:
```bash
/flight-compile
# Execute generated prompt
/flight-validate
```

### Prevention

This failure pattern now prevented by:
- [Rule 1 in domain]
- [Rule 2 in domain]
```

## Tightening Principles

### Make Rules Specific
❌ "Handle errors properly"
✅ "MUST wrap async calls in try/catch with specific error types"

### Add Concrete Examples
❌ "Use appropriate naming"
✅ "MUST use camelCase for functions, PascalCase for components"
   ```js
   // Correct
   function getUserData() {}
   function UserProfile() {}
   
   // Incorrect
   function get_user_data() {}
   function userProfile() {}
   ```

### Eliminate Ambiguity
❌ "Consider performance"
✅ "MUST use useMemo for computations over 100 items"

### Cover Edge Cases Explicitly
❌ "Handle empty states"
✅ "MUST return empty array [] when no data, NEVER return null/undefined"

## Quality Criteria

A well-tightened rule:
- Is testable (can verify pass/fail)
- Is specific (no interpretation needed)
- Has examples (correct and incorrect)
- Is atomic (one concept per rule)

## Notes

- Each tightening makes the system more reliable
- Domain files are living documents - update them
- Good invariants prevent entire categories of bugs
- After tightening, the same failure should never recur
