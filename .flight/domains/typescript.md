# Domain: Typescript Design

Type-safe TypeScript patterns that catch errors at compile time. Don't lie to the compiler. Use unknown for external data, validate before asserting, and let the type system work for you.


**Validation:** `typescript.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Unjustified any** - Every `any` needs a comment explaining why it's necessary. Prefer `unknown` with type guards for external data.

   ```
   // BAD
   const response: any = await fetch(url);
   // BAD
   function parse(input: any) { ... }

   // GOOD
   const legacyData: any /* TODO: type after v2 migration */ = oldApi.getData();
   // GOOD
   const response: unknown = await fetch(url).then(r => r.json());
   ```

2. **@ts-ignore Without Explanation** - @ts-ignore suppresses all type errors. If you must use it, explain why and reference an issue number if possible.

   ```
   // BAD
   // @ts-ignore
   doSomething(problematicValue);
   

   // GOOD
   // @ts-ignore - lib types incorrect, fixed in v3.0 (issue #1234)
   doSomething(problematicValue);
   
   // GOOD
   // @ts-expect-error - intentionally testing error case
   expectError(invalidInput);
   
   ```

3. **Chained Non-null Assertions** - Multiple `!` assertions in one expression (x!.y!.z!) hide real bugs. Handle null cases explicitly or use optional chaining with fallbacks.

   ```
   // BAD
   const name = user!.profile!.name!;
   // BAD
   const element = document.getElementById('root')!;

   // GOOD
   const name = user?.profile?.name ?? 'Anonymous';
   // GOOD
   const element = document.getElementById('root');
   if (!element) throw new Error('Root element not found');
   
   ```

4. **Type Assertion on Unvalidated Data** - Don't use `as Type` on JSON.parse or fetch responses. External data is unknown until validated.

   ```
   // BAD
   const user = data as User;
   // BAD
   const config = JSON.parse(str) as Config;
   // BAD
   const data = await response.json() as User;

   // GOOD
   const user = validateUser(data);  // throws or returns User
   // GOOD
   const config = parseConfig(str);  // returns Config | null
   // GOOD
   const data: unknown = await response.json();
   if (isUser(data)) { /* data is User */ }
   
   ```

5. **Loose Object Types** - Don't use `: object` or `: {}` as parameter types. They accept anything and provide no type safety.

   ```
   // BAD
   function process(data: object) { ... }
   // BAD
   function handle(options: {}) { ... }
   // BAD
   const cache: Record<string, any> = {};

   // GOOD
   function process(data: UserRecord) { ... }
   // GOOD
   function handle(options: HandlerOptions) { ... }
   // GOOD
   const cache: Map<UserId, UserData> = new Map();
   ```

6. **String Type for Status/Type/Kind Fields** - Don't use `string` for fields named status, type, kind, state, or mode. Use union types to catch typos at compile time.

   ```
   // BAD
   function setStatus(status: string) { ... }
   // BAD
   interface User { status: string; }

   // GOOD
   type Status = 'active' | 'inactive' | 'pending';
   function setStatus(status: Status) { ... }
   
   // GOOD
   interface User { status: 'active' | 'inactive'; }
   ```

7. **Exported Functions Must Have Return Type** - Exported functions must have explicit return types. Inferred types can change unexpectedly and break consumers.

   ```
   // BAD
   export function calculateTotal(items) {
     return items.reduce((sum, item) => sum + item.price, 0);
   }
   

   // GOOD
   export function calculateTotal(items: LineItem[]): number {
     return items.reduce((sum, item) => sum + item.price, 0);
   }
   
   ```

8. **Implicit Any in Callbacks (JSON.parse, as any)** - Don't iterate over JSON.parse() or `as any` results without typing. The callback parameters will be implicit any.

   ```
   // BAD
   JSON.parse(data).map(item => item.name)
   // BAD
   (data as any).filter(x => x.active)

   // GOOD
   const users: User[] = validateUsers(JSON.parse(data));
   users.map(user => user.name);
   
   // GOOD
   const items = JSON.parse(data) as Item[];  // with validation elsewhere
   items.map((item: Item) => item.name);
   
   ```

### MUST (validator will reject)

1. **tsconfig strict Mode** - Enable `strict: true` in tsconfig.json or tsconfig.app.json. This enables all strict type-checking options.

   ```
   {
     "compilerOptions": {
       "strict": true
     }
   }
   ```

2. **Type Guards for unknown** - Files using `unknown` type should have type guards nearby to narrow the type safely.

   ```
   function isUser(value: unknown): value is User {
     return (
       typeof value === 'object' &&
       value !== null &&
       'id' in value &&
       typeof (value as User).id === 'string'
     );
   }
   ```

3. **Interface for Object Shapes** - Prefer `interface` for object shapes. Use `type` for unions, intersections, and computed types.

   ```
   // BAD
   type User = {
     id: string;
     name: string;
   };
   

   // GOOD
   interface User {
     id: string;
     name: string;
   }
   
   // type is correct for unions
   type Status = 'active' | 'inactive';
   type UserWithStatus = User & { status: Status };
   
   ```

4. **Readonly for Array Parameters** - Function parameters that receive arrays but don't mutate them should use `readonly` to prevent accidental mutation.

   ```
   // BAD
   function processItems(items: Item[]) { ... }

   // GOOD
   function processItems(items: readonly Item[]) { ... }
   ```

### SHOULD (validator warns)

1. **Use unknown for External Data** - Use `unknown` for data from external sources (API responses, user input, JSON parsing). Validate before using.


   > External data is never safe to trust. unknown forces you to validate
before accessing properties. any lets bugs slip through.

   ```
   async function fetchUser(id: string): Promise<unknown> {
     const response = await fetch(`/api/users/${id}`);
     return response.json();
   }
   
   const data = await fetchUser('123');
   if (isUser(data)) {
     // data is now typed as User
   }
   ```

2. **Discriminated Unions for Variants** - Use discriminated unions instead of optional properties for mutually exclusive states.


   > Optional properties allow invalid states (both data AND error present).
Discriminated unions make invalid states unrepresentable.

   ```
   // BAD
   interface ApiResponse {
     success: boolean;
     data?: User;
     error?: string;
   }
   

   // GOOD
   type ApiResponse =
     | { success: true; data: User }
     | { success: false; error: string };
   
   ```

3. **Generic Constraints Over any** - Use generics with constraints instead of `any[]` or `any` parameters. Generics preserve type information through the function.

   ```
   // BAD
   function first(arr: any[]): any {
     return arr[0];
   }
   

   // GOOD
   function first<T>(arr: T[]): T | undefined {
     return arr[0];
   }
   
   ```

4. **Exhaustive Switch with assertNever** - Use assertNever in switch default cases to catch missing cases at compile time when union types are extended.

   ```
   function assertNever(value: never): never {
     throw new Error(`Unexpected value: ${value}`);
   }
   
   function handleStatus(status: Status): string {
     switch (status) {
       case 'pending': return 'Waiting';
       case 'approved': return 'Approved';
       case 'rejected': return 'Rejected';
       default: return assertNever(status);
     }
   }
   ```

### GUIDANCE (not mechanically checked)

1. **tsconfig.json Essentials** - Recommended TypeScript compiler options for type safety.


   > {
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


2. **Branded Types for IDs** - Use branded types to prevent mixing different ID types.


   > type Brand<T, B> = T & { __brand: B };
type UserId = Brand<string, 'UserId'>;
type OrderId = Brand<string, 'OrderId'>;

// Now getUser(orderId) is a compile error


3. **Utility Types Reference** - Use built-in utility types instead of manual definitions.


   > Partial<T>    - All properties optional
Required<T>   - All properties required
Readonly<T>   - All properties readonly
Pick<T, K>    - Subset of properties
Omit<T, K>    - Exclude properties
Record<K, V>  - Object with key type K and value type V
ReturnType<F> - Return type of function F
Parameters<F> - Parameter types of function F


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| data: any |  | data: unknown + type guard |
| obj as Type |  | Validate first, then use |
| value! |  | Handle null case explicitly |
| @ts-ignore |  | Fix issue or add explanation |
| : object or : {} |  | Use specific interface |
| status: string |  | Union type or enum |
| export function f() { |  | Add explicit : ReturnType |
| JSON.parse().map(x => |  | Type the parsed result first |
