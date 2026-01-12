# React Line Estimation Formulas

Use these formulas to set reasonable line guidelines for React components.
These are targets, not hard limits. Exceeding by 10-15% is acceptable if all invariants pass.

---

## 1. Simple Display Component

Components that receive props and render UI. No internal state.

```
Base: 25 lines
  - Imports: 2
  - Types: 5
  - Component shell: 8
  - Base JSX: 10

Per prop displayed: +3 lines
Per conditional render: +4 lines
Per child component used: +2 lines
```

**Formula:**
```
25 + (displayed_props × 3) + (conditionals × 4) + (children × 2)
```

**Examples:**
| Component | Calculation | Target |
|-----------|-------------|--------|
| UserAvatar (2 props, 1 conditional) | 25 + 6 + 4 = 35 | ~40 |
| ProductCard (5 props, 2 conditionals) | 25 + 15 + 8 = 48 | ~55 |
| ProfileHeader (8 props, 3 conditionals, 2 children) | 25 + 24 + 12 + 4 = 65 | ~75 |

---

## 2. Stateful Component (useState)

Components with internal state but no data fetching.

```
Base: 35 lines
  - Imports: 3
  - Types: 8
  - Component shell: 10
  - Base JSX: 14

Per useState: +3 lines
Per handler: +5 lines
Per derived value: +2 lines
Per conditional render: +4 lines
```

**Formula:**
```
35 + (useState_count × 3) + (handlers × 5) + (derived × 2) + (conditionals × 4)
```

**Examples:**
| Component | Calculation | Target |
|-----------|-------------|--------|
| Counter (1 state, 3 handlers, 2 derived, 1 conditional) | 35 + 3 + 15 + 4 + 4 = 61 | ~70 |
| Toggle (1 state, 1 handler, 0 derived, 1 conditional) | 35 + 3 + 5 + 0 + 4 = 47 | ~55 |
| Accordion (2 state, 2 handlers, 1 derived, 2 conditionals) | 35 + 6 + 10 + 2 + 8 = 61 | ~70 |

---

## 3. Data Fetching Component + Hook

Component that fetches data via custom hook.

### Custom Hook:
```
Base: 30 lines
  - Imports: 2
  - Return type interface: 6
  - Hook shell: 8
  - Fetch function: 10
  - useEffect: 4

Per response type field: +1 line (data interface)
Per additional state: +3 lines
Per parameter: +2 lines
```

**Hook Formula:**
```
30 + (response_fields × 1) + (extra_states × 3) + (params × 2)
```

### Component using hook:
```
Base: 35 lines
  - Imports: 3
  - Types: 5
  - Component shell: 7
  - Early returns (loading, error, null): 15
  - Base render: 5

Per data field displayed: +4 lines
Per action button: +5 lines
```

**Component Formula:**
```
35 + (fields_displayed × 4) + (actions × 5)
```

**Examples:**
| Component | Hook | Component | Total Target |
|-----------|------|-----------|--------------|
| UserCard (5 response fields, 5 display fields, 1 action) | 30 + 5 + 0 + 2 = 37 | 35 + 20 + 5 = 60 | ~105 |
| ProductDetail (10 response fields, 10 display fields, 3 actions) | 30 + 10 + 0 + 2 = 42 | 35 + 40 + 15 = 90 | ~145 |
| CommentThread (6 response fields, 4 display fields, 2 actions, pagination state) | 30 + 6 + 6 + 4 = 46 | 35 + 16 + 10 = 61 | ~115 |

---

## 4. Form with useReducer

Complex forms with validation and reducer-based state.

```
Base: 90 lines
  - Imports: 3
  - Types (FormValues, FormState, FormAction): 20
  - Constants: 5
  - Reducer: 15
  - Component shell: 25
  - Submit button + wrapper: 12
  - Validation helper base: 10

Per field: +20 lines
  - Type additions: +2
  - Validation function: +5
  - Handler calls: +1
  - JSX (label, input, error): +12

Per custom validation rule (beyond required): +3 lines
```

**Formula:**
```
90 + (fields × 20) + (custom_validations × 3)
```

**Examples:**
| Form | Calculation | Target |
|------|-------------|--------|
| Contact (3 fields, 6 custom rules) | 90 + 60 + 18 = 168 | ~185 |
| Login (2 fields, 2 custom rules) | 90 + 40 + 6 = 136 | ~150 |
| Registration (6 fields, 10 custom rules) | 90 + 120 + 30 = 240 | ~265 |
| Checkout (10 fields, 15 custom rules) | 90 + 200 + 45 = 335 | Split into sections |

---

## 5. List with Items

Components rendering arrays of data.

```
Base: 40 lines
  - Imports: 3
  - Types: 10
  - Component shell: 12
  - List wrapper: 5
  - Empty state: 10

Per item field: +3 lines (in map)
Per item action: +4 lines
Per filter/sort control: +10 lines
```

**Formula:**
```
40 + (item_fields × 3) + (item_actions × 4) + (controls × 10)
```

**Examples:**
| Component | Calculation | Target |
|-----------|-------------|--------|
| SimpleList (3 fields, 0 actions) | 40 + 9 + 0 = 49 | ~55 |
| TodoList (2 fields, 2 actions) | 40 + 6 + 8 = 54 | ~60 |
| DataTable (6 fields, 3 actions, 2 controls) | 40 + 18 + 12 + 20 = 90 | ~100 |

---

## 6. Modal/Dialog

Overlay components with content and actions.

```
Base: 45 lines
  - Imports: 3
  - Types: 8
  - Backdrop + positioning: 10
  - Close handling: 8
  - Content wrapper: 6
  - Base actions: 10

Per content section: +8 lines
Per action button: +5 lines
Per form field (if form modal): +15 lines
```

**Formula:**
```
45 + (sections × 8) + (actions × 5) + (form_fields × 15)
```

**Examples:**
| Modal | Calculation | Target |
|-------|-------------|--------|
| Confirm dialog (1 section, 2 actions) | 45 + 8 + 10 = 63 | ~70 |
| Info modal (3 sections, 1 action) | 45 + 24 + 5 = 74 | ~85 |
| Edit modal (2 sections, 2 actions, 4 fields) | 45 + 16 + 10 + 60 = 131 | ~145 |

---

## Summary Table

| Component Type | Base | Primary Multiplier | Formula |
|----------------|------|-------------------|---------|
| Display | 25 | +3/prop | `25 + (props × 3) + (cond × 4)` |
| Stateful | 35 | +5/handler | `35 + (state × 3) + (handlers × 5)` |
| Hook | 30 | +1/response field | `30 + (resp_fields × 1) + (states × 3) + (params × 2)` |
| Data Component | 35 | +4/field | `35 + (fields × 4) + (actions × 5)` |
| Form (reducer) | 90 | +20/field | `90 + (fields × 20) + (rules × 3)` |
| List | 40 | +3/item field | `40 + (fields × 3) + (actions × 4)` |
| Modal | 45 | +8/section | `45 + (sections × 8) + (actions × 5)` |

---

## Usage in Prompts

When compiling a prompt, calculate the target:

```markdown
## Line Guideline

This is a [Form with useReducer] with:
- 3 fields
- 6 custom validation rules

Estimated size: 90 + (3 × 20) + (6 × 3) = 168 lines
Target: ~185 lines (with 10% buffer)

Aim for this target. All invariants must pass regardless of line count.
```

---

## When to Split

If any formula yields > 250 lines, consider splitting:

| Symptom | Solution |
|---------|----------|
| Form > 250 lines | Extract field groups into sub-components |
| List > 150 lines | Extract ListItem into separate component |
| Component > 300 lines | Extract hooks, split by responsibility |
| Modal > 200 lines | Extract modal content into separate component |

The formula tells you *when* to split, not just that something is "too long."
