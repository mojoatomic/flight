# Domain: Supabase Design

Supabase patterns for TypeScript/Next.js applications. Covers client instantiation with @supabase/ssr, auth patterns (getSession vs getUser), RLS security, query error handling, and realtime subscriptions.


**Validation:** `supabase.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **service_role Key in Client Code** - The service_role key bypasses RLS. NEVER use it in browser-accessible code. Only use in server-side code that is never bundled to client.

   ```
   // BAD
   const supabase = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY)
   // BAD
   const supabase = createClient(url, process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY)

   // GOOD
   // In app/api/admin/route.ts (server-only)
   const supabase = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY)
   
   ```

2. **Deprecated @supabase/auth-helpers-nextjs** - @supabase/auth-helpers-nextjs is deprecated. Use @supabase/ssr instead. The auth-helpers package has known issues with Next.js 13+ App Router.

   ```
   // BAD
   import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
   // BAD
   import { createServerComponentClient } from '@supabase/auth-helpers-nextjs'

   // GOOD
   import { createBrowserClient } from '@supabase/ssr'
   // GOOD
   import { createServerClient } from '@supabase/ssr'
   ```

3. **Raw @supabase/supabase-js in Next.js App Router** - In Next.js App Router, use @supabase/ssr for proper cookie handling. Raw @supabase/supabase-js doesn't handle SSR cookies correctly.

   ```
   // BAD
   'use client'
   import { createClient } from '@supabase/supabase-js'
   

   // GOOD
   'use client'
   import { createBrowserClient } from '@supabase/ssr'
   
   ```

4. **Hardcoded Supabase Credentials** - Never hardcode Supabase URLs or keys. Use environment variables. Hardcoded credentials get committed and leaked.

   ```
   // BAD
   createClient('https://xxx.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...')

   // GOOD
   createClient(
     process.env.NEXT_PUBLIC_SUPABASE_URL!,
     process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
   )
   
   ```

5. **.single() Without Error Handling** - .single() throws PGRST116 error if zero rows OR if multiple rows. Always handle the error or use .maybeSingle() for optional data.

   ```
   // BAD
   const { data } = await supabase.from('users').select().eq('id', id).single()

   // GOOD
   const { data, error } = await supabase
     .from('users')
     .select()
     .eq('id', id)
     .single()
   if (error) {
     if (error.code === 'PGRST116') {
       // No rows found
     }
     throw error
   }
   
   // GOOD
   // When row might not exist
   const { data } = await supabase
     .from('users')
     .select()
     .eq('id', id)
     .maybeSingle()
   
   ```

6. **Realtime Subscription Without Cleanup** - Realtime subscriptions must be cleaned up on component unmount. Leaked subscriptions cause memory leaks and stale callbacks.

   ```
   // BAD
   useEffect(() => {
     supabase.channel('changes')
       .on('postgres_changes', { event: '*', schema: 'public' }, handler)
       .subscribe()
   }, [])
   

   // GOOD
   useEffect(() => {
     const channel = supabase.channel('changes')
       .on('postgres_changes', { event: '*', schema: 'public' }, handler)
       .subscribe()
     return () => {
       supabase.removeChannel(channel)
     }
   }, [])
   
   ```

7. **getSession() in Server Code for Auth Checks** - Never trust getSession() in server code for authentication. It reads from cookies which can be spoofed. Use getClaims() or getUser() instead.

   ```
   // BAD
   // In middleware.ts or API route
   const { data: { session } } = await supabase.auth.getSession()
   if (!session) return unauthorized()
   

   // GOOD
   // In middleware.ts or API route
   const { data: { claims } } = await supabase.auth.getClaims()
   if (!claims) return unauthorized()
   
   ```

### MUST (validator will reject)

1. **Type Database Schema** - Use generated types for type-safe Supabase queries. Without types, query results are `any`.

   ```
   // BAD
   const supabase = createBrowserClient(url, key)

   // GOOD
   import { Database } from '@/types/supabase'
   const supabase = createBrowserClient<Database>(url, key)
   
   ```

2. **Handle Auth State Changes** - Client components using auth should listen for auth state changes. Without this, the UI won't update when user signs in/out.

   ```
   useEffect(() => {
     const { data: { subscription } } = supabase.auth.onAuthStateChange(
       (event, session) => {
         setSession(session)
       }
     )
     return () => subscription.unsubscribe()
   }, [])
   ```

3. **Use createServerClient in Server Components** - Server Components, Server Actions, and Route Handlers must use createServerClient from @supabase/ssr for proper cookie handling.


   > Server-side code needs createServerClient which properly handles
reading and writing cookies. createBrowserClient doesn't work on server.

// app/page.tsx (server component)
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'


4. **Use createBrowserClient in Client Components** - Client Components ('use client') must use createBrowserClient from @supabase/ssr for proper cookie handling in browser.


   > 'use client' components run in the browser and need createBrowserClient
which handles cookies via document.cookie.

// components/MyComponent.tsx
'use client'
import { createBrowserClient } from '@supabase/ssr'


### SHOULD (validator warns)

1. **Use RLS Instead of Application-Level Filtering** - Let Postgres enforce access control with Row Level Security (RLS). Don't rely on application code to filter unauthorized data.


   > RLS policies run at the database level, making them impossible to bypass.
Application-level filtering can have bugs, and bypasses if someone
accesses the database directly.

-- Enable RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Users can only see their own posts
CREATE POLICY "Users see own posts" ON posts
  FOR SELECT USING (auth.uid() = user_id);


2. **Select Specific Columns** - Use .select('specific, columns') instead of .select('*'). Reduces payload size and improves performance.

   ```
   // BAD
   supabase.from('users').select('*')

   // GOOD
   supabase.from('users').select('id, name, email')
   ```

3. **Use Supabase CLI for Type Generation** - Generate TypeScript types from your database schema using Supabase CLI. Keep types in sync by regenerating after schema changes.


   > npx supabase gen types typescript --project-id YOUR_PROJECT_ID > types/supabase.ts

Run this:
- After any schema migration
- In CI to verify types are up to date
- Add to package.json scripts: "gen:types": "supabase gen types..."


4. **Handle PostgrestError Types** - Import and use PostgrestError type for proper error handling. Check error.code for specific error conditions.


   > import { PostgrestError } from '@supabase/supabase-js'

Common error codes:
- PGRST116: No rows returned (from .single())
- 23505: Unique constraint violation
- 23503: Foreign key constraint violation
- 42501: RLS policy violation


### GUIDANCE (not mechanically checked)

1. **Client Setup Pattern for Next.js** - Standard pattern for setting up Supabase clients in Next.js App Router.


   > Create utility files in lib/supabase/:

// lib/supabase/client.ts (for 'use client' components)
import { createBrowserClient } from '@supabase/ssr'
import { Database } from '@/types/supabase'

export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

// lib/supabase/server.ts (for server components/actions)
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: () => {} } }
  )
}


2. **Auth Validation Hierarchy** - Understanding when to use getClaims vs getUser vs getSession.


   > SERVER CODE (API routes, middleware, server actions):
1. getClaims() - RECOMMENDED. Validates JWT locally, fast, secure.
2. getUser() - Makes network call. Use when you need fresh user data.
3. getSession() - DANGEROUS. Reads unvalidated cookie. Don't use for auth.

CLIENT CODE:
1. getSession() - OK. Session already validated by server.
2. getUser() - OK. Makes network call for fresh data.
3. onAuthStateChange() - Listen for changes.


3. **Environment Variables Reference** - Standard environment variables for Supabase in Next.js.


   > # .env.local

# Safe for client (NEXT_PUBLIC_ prefix)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Safe, RLS enforced

# Server only (no NEXT_PUBLIC_ prefix)
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # DANGEROUS - bypasses RLS

Never use NEXT_PUBLIC_ with service_role key!


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| service_role in client |  | Only use in server-side API routes |
| @supabase/auth-helpers-nextjs |  | Use @supabase/ssr |
| createClient from supabase-js in Next.js |  | Use createBrowserClient/createServerClient from @supabase/ssr |
| hardcoded credentials |  | Use environment variables |
| .single() without error handling |  | Handle error or use .maybeSingle() |
| realtime without cleanup |  | Return cleanup function in useEffect |
| getSession() in server for auth |  | Use getClaims() or getUser() |
| select('*') |  | Select specific columns |
