# Domain: React

Production React patterns for functional components, hooks, and state management.

---

## Invariants

### NEVER

1. **Inline Objects in JSX Props** - Creates new reference every render
   ```jsx
   // BAD
   <Component style={{ margin: 10 }} />
   <Component config={{ enabled: true }} />
   
   // GOOD
   const containerStyle = { margin: 10 };
   <Component style={containerStyle} />
   ```

2. **Inline Functions in JSX Props** - Creates new function every render
   ```jsx
   // BAD
   <Button onClick={() => handleClick(id)} />
   <Input onChange={(e) => setName(e.target.value)} />
   
   // GOOD
   const handleButtonClick = useCallback(() => handleClick(id), [id]);
   <Button onClick={handleButtonClick} />
   ```

3. **Index as Key** - Breaks reconciliation on reorder/delete
   ```jsx
   // BAD
   items.map((item, index) => <Item key={index} />)
   
   // GOOD
   items.map((item) => <Item key={item.id} />)
   ```

4. **Direct State Mutation** - Never mutate state directly
   ```jsx
   // BAD
   user.name = 'new';
   setUser(user);
   items.push(newItem);
   setItems(items);
   
   // GOOD
   setUser({ ...user, name: 'new' });
   setItems([...items, newItem]);
   ```

5. **Missing Dependency Arrays** - Causes stale closures or infinite loops
   ```jsx
   // BAD
   useEffect(() => { fetchData(userId); });
   useEffect(() => { fetchData(userId); }, []);
   
   // GOOD
   useEffect(() => { fetchData(userId); }, [userId]);
   ```

6. **Conditional Hooks** - Breaks Rules of Hooks
   ```jsx
   // BAD
   if (isLoggedIn) {
     const [user] = useState(null);
   }
   
   // GOOD
   const [user] = useState(null);
   if (!isLoggedIn) return null;
   ```

7. **Generic Component Names** - Use descriptive, domain-specific names
   ```jsx
   // BAD
   function Item({ data }) { ... }
   function Card({ info }) { ... }
   function Component({ value }) { ... }
   
   // GOOD
   function ProductCard({ product }) { ... }
   function UserAvatar({ user }) { ... }
   function OrderSummary({ order }) { ... }
   ```

8. **Prop Drilling Beyond 2 Levels** - Use context or composition
   ```jsx
   // BAD
   <App user={user}>
     <Layout user={user}>
       <Header user={user}>
         <Avatar user={user} />

   // GOOD
   <UserContext.Provider value={user}>
     <App><Layout><Header><Avatar /></Header></Layout></App>
   </UserContext.Provider>
   ```

9. **Business Logic in Components** - Extract to hooks or utils
   ```jsx
   // BAD
   function OrderPage() {
     const total = items.reduce((sum, i) => sum + i.price * i.qty, 0);
     const tax = total * 0.08;
     const shipping = total > 100 ? 0 : 10;
     // ... 50 more lines of calculation
   }
   
   // GOOD
   function OrderPage() {
     const { total, tax, shipping } = useOrderCalculations(items);
   }
   ```

10. **Unhandled Loading/Error States** - Always handle async states
    ```jsx
    // BAD
    function UserProfile({ userId }) {
      const { data } = useFetch(`/users/${userId}`);
      return <div>{data.name}</div>;
    }
    
    // GOOD
    function UserProfile({ userId }) {
      const { data, isLoading, error } = useFetch(`/users/${userId}`);
      if (isLoading) return <LoadingSpinner />;
      if (error) return <ErrorMessage error={error} />;
      return <div>{data.name}</div>;
    }
    ```

11. **Default Export** - Use named exports for better refactoring
    ```jsx
    // BAD
    export default function UserCard() { ... }

    // GOOD
    export function UserCard() { ... }
    ```

    **Exception:** Next.js App Router special files (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `template.tsx`, `default.tsx`) MUST use `export default` per framework requirement.

12. **Props Named `data`, `info`, `item`, `value`** - Use domain terms
    ```jsx
    // BAD
    function List({ data, onItemClick }) { ... }
    
    // GOOD
    function ProductList({ products, onProductSelect }) { ... }
    ```

### MUST

1. **Handle Loading State First**
   ```jsx
   if (isLoading) return <LoadingSpinner />;
   if (error) return <ErrorMessage error={error} />;
   // Then render content
   ```

2. **Memoize Expensive Computations**
   ```jsx
   const sortedProducts = useMemo(
     () => products.sort((a, b) => a.price - b.price),
     [products]
   );
   ```

3. **Memoize Callbacks Passed to Children**
   ```jsx
   const handleProductSelect = useCallback((productId) => {
     setSelectedProductId(productId);
   }, []);
   ```

4. **Use Descriptive Handler Names**
   ```jsx
   // Pattern: handle + Noun + Verb
   const handleFormSubmit = ...
   const handleUserDelete = ...
   const handleImageUpload = ...
   ```

5. **Colocate Related State**
   ```jsx
   // BAD
   const [firstName, setFirstName] = useState('');
   const [lastName, setLastName] = useState('');
   const [email, setEmail] = useState('');
   
   // GOOD
   const [formData, setFormData] = useState({
     firstName: '',
     lastName: '',
     email: ''
   });
   // OR useReducer for complex forms
   ```

6. **Boolean Props Use is/has/can/should Prefix**
   ```jsx
   // BAD
   <Modal open={true} loading={true} disabled={true} />
   
   // GOOD
   <Modal isOpen={true} isLoading={true} isDisabled={true} />
   ```

7. **Extract Custom Hooks for Reusable Logic**
   ```jsx
   // Reusable auth hook
   function useAuth() {
     const { isLoaded, isSignedIn, user } = useUser();
     const isAuthenticated = isLoaded && isSignedIn;
     return { isLoaded, isAuthenticated, user };
   }
   ```

8. **Use Early Returns for Guard Clauses**
   ```jsx
   function UserProfile({ userId }) {
     const { user, isLoading, error } = useUser(userId);
     
     if (!userId) return null;
     if (isLoading) return <Spinner />;
     if (error) return <Error message={error.message} />;
     if (!user) return <NotFound />;
     
     return <Profile user={user} />;
   }
   ```

---

## Patterns

### Component Structure
```jsx
// 1. Imports (external, then internal)
import { useState, useCallback, useMemo } from 'react';
import { useAuth } from '@clerk/clerk-react';

import { formatCurrency } from '../utils/format';
import { ProductCard } from './ProductCard';

// 2. Constants
const MAX_ITEMS_PER_PAGE = 20;

// 3. Component
export function ProductList({ products, onProductSelect }) {
  // 3a. Hooks (always at top, same order)
  const { isSignedIn } = useAuth();
  const [selectedProductId, setSelectedProductId] = useState(null);
  
  // 3b. Derived state / memoized values
  const sortedProducts = useMemo(
    () => [...products].sort((a, b) => a.name.localeCompare(b.name)),
    [products]
  );
  
  // 3c. Callbacks
  const handleProductClick = useCallback((productId) => {
    setSelectedProductId(productId);
    onProductSelect(productId);
  }, [onProductSelect]);
  
  // 3d. Effects (after callbacks)
  useEffect(() => {
    // side effects
  }, [dependency]);
  
  // 3e. Early returns / guards
  if (!products.length) {
    return <EmptyState message="No products found" />;
  }
  
  // 3f. Render
  return (
    <ul className="product-list">
      {sortedProducts.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          isSelected={product.id === selectedProductId}
          onSelect={handleProductClick}
        />
      ))}
    </ul>
  );
}
```

### Custom Hook Structure
```jsx
export function useProducts(categoryId) {
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    setError(null);

    fetchProducts(categoryId)
      .then((fetchedProducts) => {
        if (isMounted) {
          setProducts(fetchedProducts);
          setIsLoading(false);
        }
      })
      .catch((fetchError) => {
        if (isMounted) {
          setError(fetchError);
          setIsLoading(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, [categoryId]);

  return { products, isLoading, error };
}
```

### Form with useReducer
```jsx
const initialFormState = {
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
      return {
        ...state,
        errors: { ...state.errors, [action.field]: action.error }
      };
    case 'SUBMIT_START':
      return { ...state, isSubmitting: true };
    case 'SUBMIT_END':
      return { ...state, isSubmitting: false };
    default:
      return state;
  }
}

export function LoginForm({ onSuccess }) {
  const [formState, dispatch] = useReducer(formReducer, initialFormState);
  const { values, errors, isSubmitting } = formState;
  
  // ... handlers and render
}
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `<Comp style={{...}}/>` | New ref every render | Extract to const/useMemo |
| `<Comp onClick={() => ...}/>` | New fn every render | useCallback |
| `key={index}` | Breaks on reorder | Use stable ID |
| `arr.push(); setArr(arr)` | Mutation | `setArr([...arr, new])` |
| `useEffect(() => {}, [])` | Missing deps | Add all deps |
| `if (x) useState()` | Hook rules | Hooks at top level |
| `export default` | Refactor issues | Named exports (except Next.js page/layout files) |
| `function Item({data})` | Generic naming | Domain-specific names |
| `{loading && <Spin/>}` | Flash of content | Early return pattern |
| Props > 2 levels deep | Prop drilling | Context or composition |
