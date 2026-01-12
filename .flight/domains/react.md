# Domain: React

## Invariants

### MUST
- Use functional components with hooks (no class components)
- Use named exports for components: `export function ComponentName()`
- Destructure props in function signature
- Use TypeScript or PropTypes for prop validation
- Keep components under 200 lines; extract sub-components if larger
- Use `useCallback` for functions passed to child components
- Use `useMemo` for expensive computations
- Handle loading and error states explicitly

### NEVER
- Use `useEffect` with missing dependencies (follow exhaustive-deps rule)
- Mutate state directly; always use setState/dispatch
- Use index as key for dynamic lists
- Leave async operations unhandled in useEffect
- Use inline object/array literals in JSX props (causes re-renders)
- Define components inside other components

## Patterns

### Basic Component Structure

```jsx
export function UserCard({ user, onSelect }) {
  // 1. Hooks first
  const [isExpanded, setIsExpanded] = useState(false);
  
  // 2. Derived state / memoization
  const fullName = useMemo(
    () => `${user.firstName} ${user.lastName}`,
    [user.firstName, user.lastName]
  );
  
  // 3. Callbacks
  const handleClick = useCallback(() => {
    setIsExpanded(prev => !prev);
    onSelect?.(user.id);
  }, [user.id, onSelect]);
  
  // 4. Effects (if needed)
  useEffect(() => {
    // Side effects here
  }, [/* dependencies */]);
  
  // 5. Early returns for edge cases
  if (!user) return null;
  
  // 6. Render
  return (
    <div onClick={handleClick}>
      <h3>{fullName}</h3>
      {isExpanded && <UserDetails user={user} />}
    </div>
  );
}
```

### Loading/Error States

```jsx
export function DataDisplay({ dataId }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    let cancelled = false;
    
    async function fetchData() {
      try {
        setLoading(true);
        setError(null);
        const result = await api.getData(dataId);
        if (!cancelled) {
          setData(result);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }
    
    fetchData();
    return () => { cancelled = true; };
  }, [dataId]);
  
  if (loading) return <Spinner />;
  if (error) return <ErrorMessage message={error} />;
  if (!data) return <EmptyState />;
  
  return <DataView data={data} />;
}
```

### List Rendering with Stable Keys

```jsx
// CORRECT - stable unique key
{items.map(item => (
  <ListItem key={item.id} item={item} />
))}

// INCORRECT - index as key
{items.map((item, index) => (
  <ListItem key={index} item={item} />  // ❌ Never do this
))}
```

### Avoiding Inline Objects

```jsx
// INCORRECT - creates new object every render
<Component style={{ margin: 10 }} />  // ❌
<Component data={{ name, age }} />     // ❌

// CORRECT - stable reference
const style = useMemo(() => ({ margin: 10 }), []);
const data = useMemo(() => ({ name, age }), [name, age]);
<Component style={style} />
<Component data={data} />
```

## State Management

### Local State
Use `useState` for component-specific state.

### Shared State  
Use Context + useReducer for state shared between components:

```jsx
const StateContext = createContext();
const DispatchContext = createContext();

function reducer(state, action) {
  switch (action.type) {
    case 'SET_USER':
      return { ...state, user: action.payload };
    default:
      return state;
  }
}

export function StateProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  
  return (
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={dispatch}>
        {children}
      </DispatchContext.Provider>
    </StateContext.Provider>
  );
}

export const useAppState = () => useContext(StateContext);
export const useAppDispatch = () => useContext(DispatchContext);
```

## Edge Cases

### Cleanup in useEffect
MUST return cleanup function for subscriptions/timers:

```jsx
useEffect(() => {
  const subscription = eventBus.subscribe(handler);
  return () => subscription.unsubscribe();  // ✓ Cleanup
}, []);
```

### Conditional Hooks
NEVER call hooks conditionally - MUST always call in same order:

```jsx
// INCORRECT
if (condition) {
  const [state, setState] = useState();  // ❌
}

// CORRECT
const [state, setState] = useState();
// Use condition in the logic, not around the hook
```
