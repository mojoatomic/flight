# Domain: React Design

Production React patterns for functional components, hooks, and state management. Prevents common performance issues, broken reconciliation, and Rules of Hooks violations.


**Validation:** `react.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Inline Objects in JSX Props** - Creates new object reference every render, causing unnecessary re-renders of child components even when values haven't changed.

   ```
   // BAD
   <Component style={{ margin: 10 }} />
   // BAD
   <Component config={{ enabled: true }} />

   // GOOD
   const containerStyle = { margin: 10 };
   <Component style={containerStyle} />
   
   // GOOD
   const config = useMemo(() => ({ enabled: true }), []);
   <Component config={config} />
   
   ```

2. **Inline Functions in JSX Props** - Creates new function reference every render, causing unnecessary re-renders and breaking React.memo optimization.

   ```
   // BAD
   <Button onClick={() => handleClick(id)} />
   // BAD
   <Input onChange={(e) => setName(e.target.value)} />

   // GOOD
   const handleButtonClick = useCallback(() => handleClick(id), [id]);
   <Button onClick={handleButtonClick} />
   
   ```

3. **Index as Key** - Using array index as key breaks React reconciliation on reorder/delete. Items get wrong state and animations break.

   ```
   // BAD
   items.map((item, index) => <Item key={index} />)
   // BAD
   items.map((item, i) => <Item key={i} />)

   // GOOD
   items.map((item) => <Item key={item.id} />)
   // GOOD
   items.map((item) => <Item key={`${item.type}-${item.id}`} />)
   ```

4. **Direct State Mutation** - Never mutate state directly with push/pop/splice. React won't detect the change and won't re-render.

   ```
   // BAD
   items.push(newItem);
   setItems(items);  // Same reference, no re-render
   
   // BAD
   user.name = 'new';
   setUser(user);
   

   // GOOD
   setItems([...items, newItem]);
   // GOOD
   setUser({ ...user, name: 'new' });
   // GOOD
   setItems(items.filter(i => i.id !== removeId));
   ```

5. **Missing Dependency Arrays** - useEffect/useMemo/useCallback with empty deps but referencing outer variables causes stale closures.

   ```
   // BAD
   useEffect(() => { fetchData(userId); }, []);  // userId stale
   // BAD
   useEffect(() => { fetchData(userId); });  // runs every render

   // GOOD
   useEffect(() => { fetchData(userId); }, [userId]);
   ```

6. **Conditional Hooks** - Calling hooks inside conditions/loops breaks Rules of Hooks. React tracks hooks by call order which must be stable.

   ```
   // BAD
   if (isLoggedIn) {
     const [user] = useState(null);  // Hook inside condition!
   }
   

   // GOOD
   const [user] = useState(null);  // Always called
   if (!isLoggedIn) return null;   // Conditional render is fine
   
   ```

7. **Generic Component Names** - Component functions named Item, Card, Component, etc. are too generic. Use domain-specific names that describe what the component represents.

   ```
   // BAD
   function Item({ data }) { ... }
   // BAD
   function Card({ info }) { ... }
   // BAD
   function Component({ value }) { ... }

   // GOOD
   function ProductCard({ product }) { ... }
   // GOOD
   function UserAvatar({ user }) { ... }
   // GOOD
   function OrderSummary({ order }) { ... }
   ```

8. **Export Default (except Next.js special files)** - Use named exports for better refactoring support and explicit imports. Exception: Next.js App Router special files require export default.

   ```
   // BAD
   export default function UserCard() { ... }

   // GOOD
   export function UserCard() { ... }
   // GOOD
   // page.tsx - Next.js exception
   export default function HomePage() { ... }
   
   // GOOD
   // main.tsx - Vite entry point exception
   import { StrictMode } from 'react'
   import { createRoot } from 'react-dom/client'
   import { App } from './App'
   
   createRoot(document.getElementById('root')!).render(
     <StrictMode>
       <App />
     </StrictMode>
   )
   
   ```

9. **Props Named data/info/item/value** - Generic prop names like data, info, item hide intent. Use domain-specific names that describe the prop's purpose.

   ```
   // BAD
   function List({ data, onItemClick }) { ... }
   // BAD
   const { data } = props;

   // GOOD
   function ProductList({ products, onProductSelect }) { ... }
   // GOOD
   const { products } = props;
   ```

10. **Console.log in Components** - Console statements in components indicate incomplete development or forgotten debugging code. Remove before committing.

   ```
   // BAD
   console.log('rendered', props);
   // BAD
   console.log('state:', user);

   // GOOD
   // Use React DevTools for debugging
   // GOOD
   // Use proper logging service for production
   ```

11. **Ternary Returning Boolean Literals** - condition ? true : false is always redundant. The condition is already boolean (or truthy/falsy).

   ```
   // BAD
   const isActive = status === 'active' ? true : false;
   // BAD
   disabled={isLoading ? true : false}

   // GOOD
   const isActive = status === 'active';
   // GOOD
   disabled={isLoading}
   ```

12. **Redundant Boolean Comparisons** - Comparing to true/false explicitly is redundant. Booleans are already truthy/falsy.

   ```
   // BAD
   if (isLoading === true) { ... }
   // BAD
   if (isValid === false) { ... }

   // GOOD
   if (isLoading) { ... }
   // GOOD
   if (!isValid) { ... }
   ```

### SHOULD (validator warns)

1. **Handle Loading State** - Components with async operations (fetch, useQuery, useSWR) should handle loading state to prevent flash of empty content.

   ```
   // BAD
   function UserProfile({ userId }) {
     const { data } = useFetch(`/users/${userId}`);
     return <div>{data.name}</div>;  // Crashes while loading!
   }
   

   // GOOD
   function UserProfile({ userId }) {
     const { data, isLoading, error } = useFetch(`/users/${userId}`);
     if (isLoading) return <LoadingSpinner />;
     if (error) return <ErrorMessage error={error} />;
     return <div>{data.name}</div>;
   }
   
   ```

2. **Handle Error State** - Components with async operations should handle error state to show meaningful feedback instead of crashing.

   ```
   if (error) return <ErrorMessage error={error} />;
   ```

3. **Boolean Props Use Prefix** - Boolean props should use is/has/can/should prefix for clarity. Exception: HTML attributes like disabled, checked, selected.

   ```
   // BAD
   <Modal open={true} loading={true} disabled={true} />

   // GOOD
   <Modal isOpen={true} isLoading={true} disabled={true} />
   ```

4. **useCallback for Handlers** - Event handlers defined with const should use useCallback when passed to child components to prevent unnecessary re-renders.

   ```
   // BAD
   const handleClick = () => { ... };  // New function every render
   <Button onClick={handleClick} />
   

   // GOOD
   const handleClick = useCallback(() => { ... }, [deps]);
   <Button onClick={handleClick} />
   
   ```

### GUIDANCE (not mechanically checked)

1. **Component Structure** - Recommended structure for React components to improve consistency and readability across the codebase.


   > 1. Imports (external, then internal)
2. Constants
3. Component function
   3a. Hooks (always at top, same order)
   3b. Derived state / memoized values
   3c. Callbacks (useCallback)
   3d. Effects (useEffect)
   3e. Early returns / guards
   3f. Render


2. **Custom Hook Structure** - Pattern for custom hooks that handle async operations with proper cleanup and loading/error states.


   > export function useProducts(categoryId) {
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let isMounted = true;  // Cleanup flag
    setIsLoading(true);
    setError(null);

    fetchProducts(categoryId)
      .then((data) => {
        if (isMounted) {
          setProducts(data);
          setIsLoading(false);
        }
      })
      .catch((err) => {
        if (isMounted) {
          setError(err);
          setIsLoading(false);
        }
      });

    return () => { isMounted = false; };  // Cleanup
  }, [categoryId]);

  return { products, isLoading, error };
}


3. **Form with useReducer** - For complex forms, useReducer provides better state management than multiple useState calls.


   > const initialFormState = {
  values: { email: '', password: '' },
  errors: {},
  isSubmitting: false
};

function formReducer(state, action) {
  switch (action.type) {
    case 'SET_FIELD':
      return {
        ...state,
        values: { ...state.values, [action.field]: action.value },
        errors: { ...state.errors, [action.field]: null }
      };
    case 'SET_ERROR':
      return { ...state, errors: { ...state.errors, [action.field]: action.error } };
    case 'SUBMIT_START':
      return { ...state, isSubmitting: true };
    case 'SUBMIT_END':
      return { ...state, isSubmitting: false };
    default:
      return state;
  }
}


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| <Comp style={{...}}/> |  | Extract to const/useMemo |
| <Comp onClick={() => ...}/> |  | useCallback |
| key={index} |  | Use stable ID |
| arr.push(); setArr(arr) |  | setArr([...arr, new]) |
| useEffect(() => {}, []) |  | Add all deps |
| if (x) useState() |  | Hooks at top level |
| export default |  | Named exports (except Next.js) |
| function Item({data}) |  | Domain-specific names |
| {loading && <Spin/>} |  | Early return pattern |
