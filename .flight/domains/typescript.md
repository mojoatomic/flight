# Domain: TypeScript

Type-safe TypeScript patterns that catch errors at compile time.

---

## Invariants

### NEVER

1. **Implicit `any`** - Enable `noImplicitAny` in tsconfig
   ```typescript
   // BAD - implicit any
   function process(data) { ... }
   const handler = (e) => { ... }
   
   // GOOD - explicit types
   function process(data: UserInput): Result { ... }
   const handler = (e: ChangeEvent<HTMLInputElement>) => { ... }
   ```

2. **Unjustified `any`** - Every `any` needs a comment explaining why
   ```typescript
   // BAD
   const response: any = await fetch(url);
   function parse(input: any) { ... }
   
   // GOOD - justified with comment
   const legacyData: any /* TODO: type after v2 migration */ = oldApi.getData();
   
   // BETTER - use unknown instead
   const response: unknown = await fetch(url).then(r => r.json());
   ```

3. **Type Assertions Without Validation** - Don't lie to the compiler
   ```typescript
   // BAD - trusting external data
   const user = data as User;
   const config = JSON.parse(str) as Config;
   
   // GOOD - validate first
   const user = validateUser(data); // throws or returns User
   const config = parseConfig(str); // returns Config | null
   ```

4. **`@ts-ignore` Without Explanation**
   ```typescript
   // BAD
   // @ts-ignore
   doSomething(problematicValue);
   
   // GOOD - explain the issue
   // @ts-ignore - lib types incorrect, fixed in v3.0 (issue #1234)
   doSomething(problematicValue);
   ```

5. **Non-null Assertion Abuse** - `!` hides real bugs
   ```typescript
   // BAD
   const name = user!.profile!.name!;
   const element = document.getElementById('root')!;
   
   // GOOD - handle the null case
   const name = user?.profile?.name ?? 'Anonymous';
   const element = document.getElementById('root');
   if (!element) throw new Error('Root element not found');
   ```

6. **Stringly-Typed Code** - Use unions and enums
   ```typescript
   // BAD
   function setStatus(status: string) { ... }
   setStatus('actve'); // typo not caught
   
   // GOOD
   type Status = 'active' | 'inactive' | 'pending';
   function setStatus(status: Status) { ... }
   setStatus('actve'); // compile error
   ```

7. **Loose Object Types** - Be specific
   ```typescript
   // BAD
   function process(data: object) { ... }
   function handle(options: {}) { ... }
   const cache: Record<string, any> = {};
   
   // GOOD
   function process(data: UserRecord) { ... }
   function handle(options: HandlerOptions) { ... }
   const cache: Map<UserId, UserData> = new Map();
   ```

8. **Ignoring Return Types** - Explicit returns catch bugs
   ```typescript
   // BAD - inferred return type
   function calculateTotal(items) {
     return items.reduce((sum, item) => sum + item.price, 0);
   }
   
   // GOOD - explicit return type
   function calculateTotal(items: LineItem[]): number {
     return items.reduce((sum, item) => sum + item.price, 0);
   }
   ```

9. **Enum Misuse** - Prefer unions for simple cases
   ```typescript
   // BAD - overkill for simple values
   enum Direction {
     Up = 'UP',
     Down = 'DOWN',
   }
   
   // GOOD - union is simpler
   type Direction = 'up' | 'down';
   
   // GOOD - enum when you need reverse mapping or iteration
   enum HttpStatus {
     OK = 200,
     NotFound = 404,
     ServerError = 500,
   }
   ```

10. **Function Overloads When Union Works**
    ```typescript
    // BAD - unnecessary complexity
    function parse(input: string): ParsedString;
    function parse(input: number): ParsedNumber;
    function parse(input: string | number) { ... }
    
    // GOOD - union with discriminated return
    function parse(input: string | number): ParseResult { ... }
    ```

### MUST

1. **Use `unknown` for Truly Dynamic Data**
   ```typescript
   // External data, user input, JSON parsing
   async function fetchUser(id: string): Promise<unknown> {
     const response = await fetch(`/api/users/${id}`);
     return response.json();
   }
   
   // Then validate
   const data = await fetchUser('123');
   if (isUser(data)) {
     // data is now typed as User
   }
   ```

2. **Create Type Guards for Runtime Validation**
   ```typescript
   interface User {
     id: string;
     email: string;
     name: string;
   }
   
   function isUser(value: unknown): value is User {
     return (
       typeof value === 'object' &&
       value !== null &&
       'id' in value &&
       'email' in value &&
       'name' in value &&
       typeof (value as User).id === 'string' &&
       typeof (value as User).email === 'string' &&
       typeof (value as User).name === 'string'
     );
   }
   ```

3. **Use Discriminated Unions for Variants**
   ```typescript
   // BAD
   interface ApiResponse {
     success: boolean;
     data?: User;
     error?: string;
   }
   
   // GOOD - discriminated union
   type ApiResponse =
     | { success: true; data: User }
     | { success: false; error: string };
   
   function handle(response: ApiResponse) {
     if (response.success) {
       // TypeScript knows data exists here
       console.log(response.data.name);
     } else {
       // TypeScript knows error exists here
       console.error(response.error);
     }
   }
   ```

4. **Prefer `interface` for Object Shapes, `type` for Unions/Intersections**
   ```typescript
   // Object shapes - interface (extendable)
   interface User {
     id: string;
     name: string;
   }
   
   interface AdminUser extends User {
     permissions: string[];
   }
   
   // Unions/computed types - type
   type Status = 'active' | 'inactive';
   type UserWithStatus = User & { status: Status };
   type UserId = User['id'];
   ```

5. **Generic Constraints Over `any`**
   ```typescript
   // BAD
   function first(arr: any[]): any {
     return arr[0];
   }
   
   // GOOD
   function first<T>(arr: T[]): T | undefined {
     return arr[0];
   }
   ```

6. **Readonly for Immutable Data**
   ```typescript
   interface Config {
     readonly apiUrl: string;
     readonly timeout: number;
   }
   
   function processItems(items: readonly Item[]) {
     // items.push() would be compile error
   }
   ```

7. **Strict Null Checks** - Enable in tsconfig
   ```typescript
   // With strictNullChecks: true
   function getUser(id: string): User | null {
     // Forces callers to handle null
   }
   
   const user = getUser('123');
   console.log(user.name); // Compile error - user might be null
   console.log(user?.name); // OK
   ```

8. **Utility Types Over Manual Definitions**
   ```typescript
   // Use built-in utility types
   type PartialUser = Partial<User>;
   type RequiredUser = Required<User>;
   type ReadonlyUser = Readonly<User>;
   type UserKeys = keyof User;
   type NameOnly = Pick<User, 'name'>;
   type WithoutId = Omit<User, 'id'>;
   type UserRecord = Record<string, User>;
   ```

---

## Patterns

### Type-Safe API Response
```typescript
type ApiResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: ApiError };

interface ApiError {
  code: string;
  message: string;
}

async function fetchApi<T>(url: string): Promise<ApiResult<T>> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return {
        ok: false,
        error: { code: 'HTTP_ERROR', message: response.statusText }
      };
    }
    const data: unknown = await response.json();
    // Validate data here before returning
    return { ok: true, data: data as T };
  } catch (err) {
    return {
      ok: false,
      error: { code: 'NETWORK_ERROR', message: String(err) }
    };
  }
}
```

### Branded Types for IDs
```typescript
type Brand<T, B> = T & { __brand: B };

type UserId = Brand<string, 'UserId'>;
type OrderId = Brand<string, 'OrderId'>;

function createUserId(id: string): UserId {
  return id as UserId;
}

function getUser(id: UserId): User { ... }
function getOrder(id: OrderId): Order { ... }

const userId = createUserId('123');
const orderId = createOrderId('456');

getUser(userId);  // OK
getUser(orderId); // Compile error - can't mix ID types
```

### Exhaustive Switch
```typescript
type Status = 'pending' | 'approved' | 'rejected';

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${value}`);
}

function handleStatus(status: Status): string {
  switch (status) {
    case 'pending':
      return 'Waiting for review';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return assertNever(status); // Compile error if case missed
  }
}
```

---

## tsconfig.json Essentials

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `data: any` | No type safety | `data: unknown` + guard |
| `obj as Type` | Lies to compiler | Validate first |
| `value!` | Hides null bugs | Handle null case |
| `@ts-ignore` | Hides real errors | Fix or comment why |
| `object` or `{}` | Too loose | Specific interface |
| Return type inferred | Misses bugs | Explicit return type |
| `string` for enums | Typos not caught | Union or enum |
| Manual null checks | Verbose | Optional chaining `?.` |
