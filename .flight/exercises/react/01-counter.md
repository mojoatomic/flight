# Exercise 01: Counter Component

## Difficulty
Beginner

## Task
Create a counter component with increment, decrement, and reset buttons.

## Requirements
- Display current count
- Increment button (+1)
- Decrement button (-1)
- Reset button (back to 0)
- Count cannot go below 0
- Show "Maximum reached" message at 10

## Output
Single file: `Counter.tsx`

---

## Evaluation Criteria

### Must Pass (Invariants)

- [ ] Named export `Counter`
- [ ] Props interface defined above component
- [ ] useState at top of component
- [ ] Handlers named `handleIncrement`, `handleDecrement`, `handleReset`
- [ ] Handlers as function declarations (not const arrows)
- [ ] Functional update: `setCount(prev => prev + 1)`
- [ ] Early return or conditional for max message
- [ ] className with Tailwind (no inline styles)
- [ ] No default export

### Should Pass (Guidelines)

- [ ] Under 80 lines
- [ ] Clear separation: hooks, handlers, render
- [ ] Accessible button labels

### Must Not Have (Forbidden)

- [ ] `count + 1` (direct reference in setter)
- [ ] Inline arrow handlers in JSX for main buttons
- [ ] Inline styles
- [ ] `any` type
- [ ] Default export

---

## Reference Solution

```tsx
// 1. Imports
import { useState } from 'react';
import { clsx } from 'clsx';

// 2. Types
interface CounterProps {
  initialValue?: number;
  max?: number;
}

// 3. Constants
const DEFAULT_MAX = 10;

// 4. Component
export function Counter({ initialValue = 0, max = DEFAULT_MAX }: CounterProps) {
  // 4a. Hooks
  const [count, setCount] = useState(initialValue);

  // 4b. Derived state
  const isAtMax = count >= max;
  const isAtMin = count <= 0;

  // 4c. Handlers
  function handleIncrement() {
    setCount(prev => Math.min(prev + 1, max));
  }

  function handleDecrement() {
    setCount(prev => Math.max(prev - 1, 0));
  }

  function handleReset() {
    setCount(initialValue);
  }

  // 4d. Render
  return (
    <div className="flex flex-col items-center gap-4 p-6">
      <div className="text-4xl font-bold">{count}</div>
      
      {isAtMax && (
        <div className="text-amber-600 text-sm">Maximum reached</div>
      )}
      
      <div className="flex gap-2">
        <button
          onClick={handleDecrement}
          disabled={isAtMin}
          className={clsx(
            'px-4 py-2 rounded font-medium',
            isAtMin ? 'bg-gray-200 text-gray-400' : 'bg-blue-500 text-white'
          )}
        >
          -1
        </button>
        
        <button
          onClick={handleReset}
          className="px-4 py-2 rounded font-medium bg-gray-500 text-white"
        >
          Reset
        </button>
        
        <button
          onClick={handleIncrement}
          disabled={isAtMax}
          className={clsx(
            'px-4 py-2 rounded font-medium',
            isAtMax ? 'bg-gray-200 text-gray-400' : 'bg-blue-500 text-white'
          )}
        >
          +1
        </button>
      </div>
    </div>
  );
}
```

---

## Common Failures

| Failure | Root Cause | Tightening |
|---------|------------|------------|
| `setCount(count + 1)` | Training prior from tutorials | Invariant: "Functional update when deriving from previous" |
| Inline `onClick={() => setCount(...)}` | Brevity preference | Invariant: "Handlers as function declarations" |
| Props interface after component | Common habit | Invariant: "Props interface above component" |
| Missing disabled states | Incomplete spec reading | Add to Must Pass checklist |
| `export default` | Training prior | Explicit forbidden pattern |

---

## Tightenings Applied

*None yet - this is the baseline exercise.*
