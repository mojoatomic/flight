# Exercise 04: Todo List with Filters

## Difficulty
Intermediate

## Task
Create a todo list component with filter controls.

## Requirements
- Display list of todos
- Each item shows: title, completed checkbox, delete button
- Filter tabs: All, Active, Completed
- Empty state: "No todos" message when filtered list is empty
- Clicking checkbox toggles completed
- Clicking delete removes item

## Props
```ts
interface Todo {
  id: string;
  title: string;
  completed: boolean;
}

interface TodoListProps {
  todos: Todo[];
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}
```

## Output
Single file: `TodoList.tsx`

## Line Estimation
```
Formula: 40 + (item_fields × 3) + (item_actions × 4) + (controls × 10)
= 40 + (2 × 3) + (1 × 4) + (1 × 10) = 60 lines
Target: ~66 lines
```

---

## Evaluation Criteria

### Must Pass (Invariants)

- [ ] Named export `TodoList`
- [ ] Todo and TodoListProps interfaces defined above component
- [ ] useState for filter with explicit union type
- [ ] filteredTodos derived with .filter()
- [ ] `key={todo.id}` on list items
- [ ] Checkbox with checked and onChange
- [ ] Title has line-through when completed
- [ ] Delete button calls onDelete(todo.id)
- [ ] Empty state when filteredTodos.length === 0
- [ ] clsx for conditional classes
- [ ] No forbidden patterns

### Should Aim For (Guidelines)

- [ ] Under 66 lines
- [ ] FILTERS as const array for DRY
- [ ] capitalize class for filter button text

### Must Not Have (Forbidden)

- [ ] Default export
- [ ] Index as key
- [ ] useEffect (not needed)
- [ ] useReducer (overkill)
- [ ] `any` type

---

## Reference Solution

```tsx
// 1. Imports
import { useState } from 'react';
import { clsx } from 'clsx';

// 2. Types
interface Todo {
  id: string;
  title: string;
  completed: boolean;
}

interface TodoListProps {
  todos: Todo[];
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}

// 3. Constants
const FILTERS = ['all', 'active', 'completed'] as const;
type Filter = typeof FILTERS[number];

// 4. Component
export function TodoList({ todos, onToggle, onDelete }: TodoListProps) {
  // 4a. Hooks
  const [filter, setFilter] = useState<Filter>('all');
  // 4b. Derived state
  const filteredTodos = todos.filter(todo => {
    if (filter === 'active') return !todo.completed;
    if (filter === 'completed') return todo.completed;
    return true;
  });
  // 4c. Render
  return (
    <div className="max-w-md">
      <div className="flex gap-2 mb-4">
        {FILTERS.map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={clsx('px-3 py-1 rounded capitalize', filter === f ? 'bg-blue-500 text-white' : 'bg-gray-200')}
          >
            {f}
          </button>
        ))}
      </div>
      {filteredTodos.length === 0 ? (
        <p className="text-gray-500 text-center py-4">No todos</p>
      ) : (
        <ul className="space-y-2">
          {filteredTodos.map(todo => (
            <li key={todo.id} className="flex items-center gap-3 p-2 bg-white rounded shadow">
              <input
                type="checkbox"
                checked={todo.completed}
                onChange={() => onToggle(todo.id)}
                className="h-4 w-4"
              />
              <span className={clsx('flex-1', todo.completed && 'line-through text-gray-400')}>{todo.title}</span>
              <button onClick={() => onDelete(todo.id)} className="text-red-500 text-sm">Delete</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

---

## Common Failures

| Failure | Root Cause | Fix |
|---------|------------|-----|
| `key={index}` | Habit from tutorials | Invariant: use stable IDs |
| Missing filter type | Loose typing | Invariant: explicit union type |
| useReducer for filter | Over-engineering | Guideline: useState for single values |
| Handlers for toggle/delete | Unnecessary indirection | Pass props directly |

---

## Tightenings Applied

*None yet - this is the baseline exercise.*
