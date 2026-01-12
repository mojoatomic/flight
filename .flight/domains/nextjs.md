# Domain: Next.js

Next.js 14+ App Router patterns for server components, routing, and data fetching.

---

## Invariants

### NEVER

1. **`use client` at Top of Server Component**
   ```tsx
   // BAD - makes entire tree client
   'use client';
   export default function Page() { ... }
   
   // GOOD - only mark interactive parts
   // page.tsx (server by default)
   export default function Page() {
     return (
       <div>
         <StaticContent />
         <InteractiveWidget /> {/* this file has 'use client' */}
       </div>
     );
   }
   ```

2. **`useState`/`useEffect` in Server Components**
   ```tsx
   // BAD - hooks don't work server-side
   export default function Page() {
     const [count, setCount] = useState(0); // Error
   }
   
   // GOOD - fetch data directly
   export default async function Page() {
     const data = await fetchData();
     return <Display data={data} />;
   }
   ```

3. **Fetch in `useEffect` for Initial Data**
   ```tsx
   // BAD - client fetch when server fetch works
   'use client';
   export default function Page() {
     const [data, setData] = useState(null);
     useEffect(() => {
       fetch('/api/data').then(r => r.json()).then(setData);
     }, []);
   }
   
   // GOOD - server component fetches
   export default async function Page() {
     const data = await fetch('https://api.example.com/data');
     return <Display data={data} />;
   }
   ```

4. **Secrets in Client Components**
   ```tsx
   // BAD - exposed to browser
   'use client';
   const API_KEY = process.env.API_KEY; // undefined or exposed
   
   // GOOD - server only
   // In server component or route handler
   const API_KEY = process.env.API_KEY; // safe
   ```

5. **Direct Database Calls in Client Components**
   ```tsx
   // BAD
   'use client';
   import { db } from '@/lib/db';
   const users = await db.user.findMany(); // Won't work
   
   // GOOD - server action or route handler
   // actions.ts
   'use server';
   export async function getUsers() {
     return db.user.findMany();
   }
   ```

6. **Hardcoded Routes**
   ```tsx
   // BAD
   <Link href="/dashboard/settings/profile">
   router.push('/dashboard/settings/profile');
   
   // GOOD - centralized routes
   // lib/routes.ts
   export const routes = {
     dashboard: '/dashboard',
     settings: '/dashboard/settings',
     profile: '/dashboard/settings/profile',
   } as const;
   
   <Link href={routes.profile}>
   ```

7. **`router.push` for Data Mutations**
   ```tsx
   // BAD - navigation for side effects
   const handleSubmit = () => {
     fetch('/api/submit', { method: 'POST', body });
     router.push('/success');
   };
   
   // GOOD - server action with redirect
   'use server';
   export async function submitForm(formData: FormData) {
     await saveToDb(formData);
     redirect('/success');
   }
   ```

8. **Importing Server-Only Code in Client**
   ```tsx
   // BAD - db code bundled to client
   'use client';
   import { db } from '@/lib/db';
   
   // GOOD - mark server-only explicitly
   // lib/db.ts
   import 'server-only';
   export const db = ...;
   // Now importing in client component = build error
   ```

9. **Missing Loading/Error Boundaries**
   ```
   // BAD - no loading states
   app/
     dashboard/
       page.tsx
   
   // GOOD - proper boundaries
   app/
     dashboard/
       page.tsx
       loading.tsx
       error.tsx
       not-found.tsx
   ```

10. **Blocking Waterfalls in Server Components**
    ```tsx
    // BAD - sequential fetches
    export default async function Page() {
      const user = await fetchUser();
      const posts = await fetchPosts(user.id);
      const comments = await fetchComments(posts);
    }
    
    // GOOD - parallel when possible
    export default async function Page() {
      const [user, config] = await Promise.all([
        fetchUser(),
        fetchConfig()
      ]);
      // Only sequential when dependent
      const posts = await fetchPosts(user.id);
    }
    ```

11. **Giant Route Handlers**
    ```tsx
    // BAD - all logic in route
    export async function POST(req: Request) {
      // 200 lines of validation, db calls, emails...
    }
    
    // GOOD - thin route, logic extracted
    export async function POST(req: Request) {
      const body = await req.json();
      const result = await createOrder(body);
      return Response.json(result);
    }
    ```

12. **`any` in Route Handlers**
    ```tsx
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

### MUST

1. **Use `async` Server Components for Data**
   ```tsx
   export default async function UsersPage() {
     const users = await getUsers();
     return <UserList users={users} />;
   }
   ```

2. **Validate All Route Handler Input**
   ```tsx
   import { z } from 'zod';
   
   const schema = z.object({
     email: z.string().email(),
     name: z.string().min(1),
   });
   
   export async function POST(req: Request) {
     const body: unknown = await req.json();
     const result = schema.safeParse(body);
     
     if (!result.success) {
       return Response.json(
         { error: result.error.flatten() },
         { status: 400 }
       );
     }
     
     // result.data is typed
   }
   ```

3. **Use `notFound()` for Missing Resources**
   ```tsx
   import { notFound } from 'next/navigation';
   
   export default async function UserPage({ params }: Props) {
     const user = await getUser(params.id);
     
     if (!user) {
       notFound(); // Renders not-found.tsx
     }
     
     return <UserProfile user={user} />;
   }
   ```

4. **Type Route Params and SearchParams**
   ```tsx
   interface PageProps {
     params: { slug: string };
     searchParams: { page?: string; sort?: string };
   }
   
   export default async function Page({ params, searchParams }: PageProps) {
     const page = Number(searchParams.page) || 1;
   }
   ```

5. **Colocate Loading States**
   ```
   app/
     users/
       page.tsx
       loading.tsx      # Shows while page.tsx suspends
       [id]/
         page.tsx
         loading.tsx    # Shows while [id]/page.tsx suspends
   ```

6. **Use Route Groups for Organization**
   ```
   app/
     (marketing)/
       page.tsx         # Landing page
       about/
       pricing/
     (dashboard)/
       layout.tsx       # Dashboard layout with nav
       dashboard/
       settings/
     (auth)/
       login/
       register/
   ```

7. **Server Actions for Mutations**
   ```tsx
   // actions.ts
   'use server';
   
   export async function createPost(formData: FormData) {
     const title = formData.get('title');
     
     await db.post.create({ data: { title } });
     revalidatePath('/posts');
     redirect('/posts');
   }
   
   // form.tsx
   <form action={createPost}>
     <input name="title" />
     <button type="submit">Create</button>
   </form>
   ```

8. **Use `revalidatePath`/`revalidateTag` After Mutations**
   ```tsx
   'use server';
   
   export async function updateUser(id: string, data: UserData) {
     await db.user.update({ where: { id }, data });
     revalidatePath(`/users/${id}`);
     revalidateTag('users');
   }
   ```

---

## Patterns

### File Structure
```
app/
├── (marketing)/
│   ├── page.tsx              # Home
│   └── layout.tsx
├── (dashboard)/
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── loading.tsx
│   │   └── error.tsx
│   └── layout.tsx
├── api/
│   └── webhooks/
│       └── stripe/
│           └── route.ts
├── layout.tsx                 # Root layout
├── not-found.tsx             # Global 404
└── error.tsx                 # Global error

lib/
├── db.ts                     # Database (server-only)
├── auth.ts                   # Auth helpers
├── routes.ts                 # Route constants
└── validations/
    └── user.ts               # Zod schemas

components/
├── ui/                       # Generic UI
└── features/
    └── users/                # Feature-specific
```

### Server Component with Suspense
```tsx
// app/users/page.tsx
import { Suspense } from 'react';
import { UserList } from './user-list';
import { UserListSkeleton } from './user-list-skeleton';

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
  const users = await getUsers(); // This suspends
  return (
    <ul>
      {users.map(user => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

### Route Handler with Validation
```tsx
// app/api/users/route.ts
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
```

### Middleware Pattern
```tsx
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // Auth check
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
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `'use client'` on page | Kills SSR benefits | Push client boundary down |
| `useEffect` fetch | Extra round trip | Server component fetch |
| `process.env.X` client | Secrets exposed | Server only |
| Sequential fetches | Slow load | `Promise.all` |
| No loading.tsx | Layout shift | Add loading boundary |
| No error.tsx | Crashes bubble up | Add error boundary |
| Fat route handlers | Hard to test | Extract to functions |
| Hardcoded paths | Refactor hell | Route constants |
| `any` in handlers | No validation | Zod + unknown |
| No revalidation | Stale data | `revalidatePath` |
