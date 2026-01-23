# Domain: Nextjs Design

Next.js 14+ App Router patterns for server components, routing, and data fetching. Enforces proper client/server boundaries, prevents secret exposure, and promotes parallel data fetching.


**Validation:** `nextjs.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Inconsistent Source Directory Structure** - If src/ directory exists, all application code must live under src/. No parallel directories at root level (lib/ alongside src/lib/). This prevents AI assistants from creating duplicate file structures.

   ```
   // BAD
   # Split structure - NEVER do this
   src/
     app/
     components/
   lib/           # Wrong! Should be src/lib/
   components/    # Wrong! Duplicate of src/components/
   

   // GOOD
   # All code under src/
   src/
     app/
     lib/
     components/
     types/
   
   // GOOD
   # Or no src/ at all (root convention)
   app/
   lib/
   components/
   types/
   
   ```

2. **'use client' in page.tsx Files** - Page components should be server components by default. Adding 'use client' at the page level kills SSR benefits for the entire page tree.

   ```
   // BAD
   // page.tsx
   'use client';
   export default function Page() { ... }  // Entire tree is now client
   

   // GOOD
   // page.tsx (server by default)
   export default function Page() {
     return (
       <div>
         <StaticContent />
         <InteractiveWidget />  {/* Only this file has 'use client' */}
       </div>
     );
   }
   
   ```

3. **React Hooks in Server Components** - useState, useEffect, and other React hooks cannot be used in server components. Files without 'use client' directive are server components.

   ```
   // BAD
   // No 'use client' = server component
   export default function Page() {
     const [count, setCount] = useState(0);  // Error!
   }
   

   // GOOD
   // Server component with direct data fetching
   export default async function Page() {
     const data = await fetchData();
     return <Display data={data} />;
   }
   
   ```

4. **useEffect Fetch for Initial Page Data** - Don't use useEffect to fetch initial page data. Server components can fetch data directly, avoiding the extra round trip.

   ```
   // BAD
   'use client';
   export default function Page() {
     const [data, setData] = useState(null);
     useEffect(() => {
       fetch('/api/data').then(r => r.json()).then(setData);
     }, []);
   }
   

   // GOOD
   // Server component fetches directly
   export default async function Page() {
     const data = await fetch('https://api.example.com/data');
     return <Display data={data} />;
   }
   
   ```

5. **process.env in Client Components** - Non-NEXT_PUBLIC_ environment variables are not available in client components and would expose secrets if they were. Only NEXT_PUBLIC_ vars are safe client-side.

   ```
   // BAD
   'use client';
   const API_KEY = process.env.API_KEY;  // undefined or exposed!
   

   // GOOD
   // Server component or route handler
   const API_KEY = process.env.API_KEY;  // Safe, server only
   
   // GOOD
   'use client';
   const PUBLIC_URL = process.env.NEXT_PUBLIC_API_URL;  // Safe
   
   ```

6. **'any' Type in Route Handlers** - Route handlers should validate input, not use 'any'. External data from requests is unknown until validated.

   ```
   // BAD
   export async function POST(req: Request) {
     const body: any = await req.json();
   }
   

   // GOOD
   export async function POST(req: Request) {
     const body: unknown = await req.json();
     const validated = orderSchema.parse(body);
   }
   
   ```

7. **Hardcoded Multi-segment Routes** - Hardcoded route strings with multiple segments are fragile. Use centralized route constants for maintainability.

   ```
   // BAD
   <Link href="/dashboard/settings/profile">
   // BAD
   router.push('/dashboard/settings/profile');

   // GOOD
   // lib/routes.ts
   export const routes = {
     profile: '/dashboard/settings/profile',
   } as const;
   
   <Link href={routes.profile}>
   
   ```

8. **console.log in App Directory** - Console statements in production code indicate incomplete development or forgotten debugging. Remove before deploying.

   ```
   // BAD
   console.log('data:', data);

   // GOOD
   // Use proper logging service for production
   ```

9. **Fat Route Handlers (>100 lines)** - Route handlers should be thin orchestrators. Extract business logic to separate functions for testability and reuse. 100 lines allows for proper validation, auth, and error handling while flagging genuinely fat handlers.

   ```
   // BAD
   export async function POST(req: Request) {
     // 200 lines of validation, db calls, emails...
   }
   

   // GOOD
   export async function POST(req: Request) {
     const body = await req.json();
     const result = await createOrder(body);  // Logic extracted
     return Response.json(result);
   }
   
   ```

### SHOULD (validator warns)

1. **Dynamic Routes Should Use notFound()** - Dynamic route pages ([id], [slug]) should call notFound() when the resource doesn't exist, rendering the not-found.tsx boundary.

   ```
   import { notFound } from 'next/navigation';
   
   export default async function UserPage({ params }: Props) {
     const user = await getUser(params.id);
     if (!user) notFound();  // Renders not-found.tsx
     return <UserProfile user={user} />;
   }
   ```

2. **Consider Promise.all for Independent Fetches** - Multiple sequential awaits that don't depend on each other should use Promise.all to fetch in parallel and reduce load time.

   ```
   // BAD
   const user = await fetchUser();
   const config = await fetchConfig();  // Waits for user unnecessarily
   const posts = await fetchPosts();    // Waits for config unnecessarily
   

   // GOOD
   const [user, config, posts] = await Promise.all([
     fetchUser(),
     fetchConfig(),
     fetchPosts(),
   ]);
   
   ```

3. **Pages Should Have loading.tsx** - Directories with page.tsx should have loading.tsx to show instant loading state while the page suspends.

   ```
   app/
     dashboard/
       page.tsx
       loading.tsx    # Shows while page.tsx suspends
   ```

4. **Pages Should Have error.tsx** - Directories with page.tsx should have error.tsx to handle errors gracefully instead of crashing the entire app.

   ```
   app/
     dashboard/
       page.tsx
       error.tsx      # Catches errors, allows recovery
   ```

5. **Server-Only Import for Sensitive Files** - Database and auth files should import 'server-only' to prevent accidental import in client components.

   ```
   // lib/db.ts
   import 'server-only';
   export const db = new PrismaClient();
   ```

### GUIDANCE (not mechanically checked)

1. **App Directory File Structure** - Recommended file structure for Next.js App Router projects.


   > app/
├── (marketing)/           # Route group for marketing pages
│   ├── page.tsx           # Home
│   └── layout.tsx
├── (dashboard)/           # Route group for authenticated pages
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── loading.tsx
│   │   └── error.tsx
│   └── layout.tsx
├── api/
│   └── webhooks/
│       └── stripe/
│           └── route.ts
├── layout.tsx             # Root layout
├── not-found.tsx          # Global 404
└── error.tsx              # Global error

lib/
├── db.ts                  # Database (with server-only)
├── auth.ts                # Auth helpers
├── routes.ts              # Route constants
└── validations/
    └── user.ts            # Zod schemas


2. **Server Component with Suspense** - Pattern for async server components with Suspense boundaries.


   > // app/users/page.tsx
import { Suspense } from 'react';

export default function UsersPage() {
  return (
    <div>
      <h1>Users</h1>
      <Suspense fallback={<UserListSkeleton />}>
        <UserList />
      </Suspense>
    </div>
  );
}

// app/users/user-list.tsx
export async function UserList() {
  const users = await getUsers();  // This suspends
  return (
    <ul>
      {users.map(user => <li key={user.id}>{user.name}</li>)}
    </ul>
  );
}


3. **Route Handler with Validation** - Pattern for type-safe route handlers with Zod validation.


   > // app/api/users/route.ts
import { NextResponse } from 'next/server';
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

export async function POST(request: Request) {
  const body: unknown = await request.json();
  const parsed = createUserSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Validation failed', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const user = await createUser(parsed.data);
  return NextResponse.json(user, { status: 201 });
}


4. **Middleware Pattern** - Pattern for Next.js middleware with auth checks and path matching.


   > // middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname.startsWith('/dashboard')) {
    const token = request.cookies.get('token');
    if (!token) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/api/:path*'],
};


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| 'use client' on page |  | Push client boundary down |
| useEffect fetch |  | Server component fetch |
| process.env.X client |  | Server only or NEXT_PUBLIC_ |
| Sequential awaits |  | Promise.all for independent |
| No loading.tsx |  | Add loading boundary |
| No error.tsx |  | Add error boundary |
| Fat route handlers |  | Extract to functions |
| Hardcoded paths |  | Route constants |
| 'any' in handlers |  | Zod + unknown |
