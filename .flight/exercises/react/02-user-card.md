# Exercise 02: User Card with Data Fetching

## Difficulty
Intermediate

## Task
Create a UserCard component that fetches and displays user data from an API, using a custom hook for data fetching.

## Requirements
- Custom hook `useUser` that fetches user by ID
- Loading state with spinner
- Error state with message and retry button
- Display: avatar, name, email, join date
- Refetch capability

## API
```
GET https://jsonplaceholder.typicode.com/users/{id}

Response:
{
  id: number,
  name: string,
  email: string,
  username: string,
  phone: string
}
```

## Output
Two files:
- `hooks/useUser.ts`
- `UserCard.tsx`

---

## Evaluation Criteria

### Must Pass (Invariants)

**useUser.ts:**
- [ ] Named export `useUser`
- [ ] Returns object: `{ user, loading, error, refetch }`
- [ ] useState for user, loading, error (in that order)
- [ ] useEffect with `[userId]` dependency
- [ ] Proper error typing: `Error | null`
- [ ] Loading starts as `true`

**UserCard.tsx:**
- [ ] Props interface above component
- [ ] Hooks at top in correct order
- [ ] Early returns for loading and error states
- [ ] Handler `handleRetry` for error retry
- [ ] No business logic in component (all in hook)
- [ ] Tailwind styling

### Should Pass (Guidelines)

- [ ] useUser under 50 lines
- [ ] UserCard under 65 lines
- [ ] Type for User defined
- [ ] Accessible loading/error states

### Must Not Have (Forbidden)

- [ ] fetch in component (must be in hook)
- [ ] Missing dependency array on useEffect
- [ ] `any` type
- [ ] Nested ternaries
- [ ] Default exports

---

## Reference Solution

### hooks/useUser.ts

```tsx
// 1. Imports
import { useState, useEffect } from 'react';

// 2. Types
interface User {
  id: number;
  name: string;
  email: string;
  username: string;
  phone: string;
}

interface UseUserResult {
  user: User | null;
  loading: boolean;
  error: Error | null;
  refetch: () => void;
}

// 3. Hook
export function useUser(userId: string): UseUserResult {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  async function fetchUser() {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch(
        `https://jsonplaceholder.typicode.com/users/${userId}`
      );
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      setUser(data);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Unknown error'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchUser();
  }, [userId]);

  return { user, loading, error, refetch: fetchUser };
}
```

### UserCard.tsx

```tsx
// 1. Imports
import { useUser } from './hooks/useUser';

// 2. Types
interface UserCardProps {
  userId: string;
}

// 3. Component
export function UserCard({ userId }: UserCardProps) {
  // 3a. Hooks
  const { user, loading, error, refetch } = useUser(userId);

  // 3b. Handlers
  function handleRetry() {
    refetch();
  }

  // 3c. Early returns
  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin h-8 w-8 border-4 border-blue-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center gap-4 p-8 text-center">
        <div className="text-red-600">Failed to load user</div>
        <div className="text-sm text-gray-500">{error.message}</div>
        <button
          onClick={handleRetry}
          className="px-4 py-2 bg-blue-500 text-white rounded"
        >
          Retry
        </button>
      </div>
    );
  }

  if (!user) {
    return null;
  }

  // 3d. Render
  return (
    <div className="p-6 bg-white rounded-lg shadow">
      <div className="flex items-center gap-4">
        <div className="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center text-2xl">
          {user.name.charAt(0)}
        </div>
        <div>
          <h2 className="text-xl font-bold">{user.name}</h2>
          <p className="text-gray-500">@{user.username}</p>
        </div>
      </div>
      <div className="mt-4 space-y-2 text-sm">
        <div className="flex gap-2">
          <span className="text-gray-500">Email:</span>
          <span>{user.email}</span>
        </div>
        <div className="flex gap-2">
          <span className="text-gray-500">Phone:</span>
          <span>{user.phone}</span>
        </div>
      </div>
    </div>
  );
}
```

---

## Common Failures

| Failure | Root Cause | Tightening |
|---------|------------|------------|
| Fetch logic in component | Doesn't understand separation | Invariant: "No business logic in components" |
| `useEffect(() => { fetch() })` no deps | Training on old patterns | Invariant: "Every useEffect MUST have dependency array" |
| Returns array `[user, loading, error]` | Mimicking useState | Invariant: "Return object from custom hooks" |
| Loading starts as `false` | Optimistic default | Invariant: "Loading starts as true for async hooks" |
| `catch (err: any)` | TypeScript laziness | Invariant: "`err instanceof Error` check" |
| Nested ternary for states | Compactness preference | Invariant: "Early returns for loading/error" |

---

## Tightenings Applied

*None yet - this is the baseline exercise.*
