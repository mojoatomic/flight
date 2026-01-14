# Domain: Clerk Design

Clerk authentication and multi-tenant organization patterns for SaaS applications using TypeScript/Next.js App Router. Covers clerkMiddleware, auth(), organizations, orgId-scoped data access, role-based permissions, and webhook verification.


**Validation:** `clerk.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Secret Key in Client Code** - CLERK_SECRET_KEY must never appear in client-accessible code. It has admin privileges. Only use in server-side code that is never bundled to client.

   ```
   // BAD
   const clerk = createClerkClient({ secretKey: process.env.CLERK_SECRET_KEY })
   // BAD
   process.env.NEXT_PUBLIC_CLERK_SECRET_KEY

   // GOOD
   // In app/api/admin/route.ts (server-only)
   import { clerkClient } from '@clerk/nextjs/server'
   
   ```

2. **Deprecated authMiddleware** - authMiddleware is deprecated. Use clerkMiddleware() instead. authMiddleware has known issues with Next.js 14+ and doesn't support the new routing patterns.

   ```
   // BAD
   import { authMiddleware } from '@clerk/nextjs'
   // BAD
   export default authMiddleware({ publicRoutes: [...] })

   // GOOD
   import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'
   
   const isPublicRoute = createRouteMatcher(['/sign-in(.*)', '/sign-up(.*)'])
   
   export default clerkMiddleware((auth, req) => {
     if (!isPublicRoute(req)) auth.protect()
   })
   
   ```

3. **auth() in Client Components** - auth() from @clerk/nextjs/server cannot be used in client components. It's a server-only function. Use useAuth() hook in client components.

   ```
   // BAD
   'use client'
   import { auth } from '@clerk/nextjs/server'
   

   // GOOD
   'use client'
   import { useAuth, useOrganization } from '@clerk/nextjs'
   
   ```

4. **Synchronous auth() Call in Next.js 15+** - In Next.js 15+, auth() returns a Promise. Must be awaited. Synchronous usage causes runtime errors.

   ```
   // BAD
   const { userId } = auth()
   // BAD
   const { orgId } = auth()

   // GOOD
   const { userId, orgId } = await auth()
   ```

5. **Hardcoded Clerk Keys** - Never hardcode Clerk publishable or secret keys. Use environment variables. Hardcoded credentials get committed and leaked.

   ```
   // BAD
   publishableKey: 'pk_test_abc123'
   // BAD
   secretKey: 'sk_live_xyz789'

   // GOOD
   publishableKey: process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
   ```

6. **Missing Webhook Signature Verification** - Clerk webhooks must verify the svix signature. Without verification, attackers can send fake webhook events to your API.

   ```
   // BAD
   // API route that trusts webhook without verification
   export async function POST(req) {
     const body = await req.json()
     // Processing without verification!
   }
   

   // GOOD
   import { verifyWebhook } from '@clerk/nextjs/webhooks'
   
   export async function POST(req) {
     const payload = await verifyWebhook(req)
     // Now safe to process
   }
   
   ```

7. **Using userId When orgId is Required** - In multi-tenant apps, data must be scoped to orgId, not userId. A user can be in multiple orgs. Using userId creates data leaks.

   ```
   // BAD
   prisma.posts.findMany({ where: { userId } })
   // BAD
   db.query.posts.where(eq(posts.userId, userId))

   // GOOD
   prisma.posts.findMany({ where: { orgId } })
   // GOOD
   prisma.posts.findMany({ where: { orgId, userId } })
   ```

8. **Missing Organization Context in Protected Routes** - Protected routes in multi-tenant apps must check for orgId. A valid session without org context means the user hasn't selected an org.

   ```
   // BAD
   const { userId } = await auth()
   if (!userId) throw new Error('Unauthorized')
   // Missing orgId check!
   

   // GOOD
   const { userId, orgId } = await auth()
   if (!userId) throw new Error('Unauthorized')
   if (!orgId) throw new Error('No organization selected')
   
   ```

9. **Missing Null Checks for Auth Values** - auth() can return null for userId and orgId. Using them without null checks causes runtime errors and security issues.

   ```
   // BAD
   const { userId } = await auth()
   await db.posts.create({ data: { userId: userId! } })
   

   // GOOD
   const { userId } = await auth()
   if (!userId) throw new Error('Unauthorized')
   await db.posts.create({ data: { userId } })
   
   ```

### MUST (validator will reject)

1. **ClerkProvider at Root** - ClerkProvider must wrap the application at the root layout. Without it, Clerk hooks and components won't work.

   ```
   import { ClerkProvider } from '@clerk/nextjs'
   
   export default function RootLayout({ children }) {
     return (
       <ClerkProvider>
         <html><body>{children}</body></html>
       </ClerkProvider>
     )
   }
   ```

2. **Middleware Matcher Configuration** - Clerk middleware must have a matcher config to avoid running on static files and internal Next.js routes.

   ```
   // BAD
   export default clerkMiddleware()
   // Missing config.matcher!
   

   // GOOD
   export default clerkMiddleware()
   
   export const config = {
     matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
   }
   
   ```

3. **Use createRouteMatcher for Route Protection** - Use createRouteMatcher() with clerkMiddleware for route protection. This is the recommended pattern over manual path checks.

   ```
   const isPublicRoute = createRouteMatcher(['/sign-in(.*)', '/sign-up(.*)'])
   
   export default clerkMiddleware((auth, req) => {
     if (!isPublicRoute(req)) auth.protect()
   })
   ```

4. **Validate Organization Slug in Routes** - When using org slug in URL ([orgSlug]), validate it matches the user's current organization to prevent URL manipulation.

   ```
   // BAD
   // app/[orgSlug]/dashboard/page.tsx
   export default async function Page({ params }) {
     const { orgSlug } = params
     // Using URL slug without validation!
   }
   

   // GOOD
   export default async function Page({ params }) {
     const { orgSlug: authSlug } = await auth()
     const { orgSlug: urlSlug } = params
     if (urlSlug !== authSlug) redirect(`/${authSlug}/dashboard`)
   }
   
   ```

5. **Include orgId in Database Queries** - All data queries must include orgId to enforce tenant isolation. This is the fundamental multi-tenant security boundary.

   ```
   // BAD
   prisma.posts.findMany()
   // BAD
   prisma.posts.findMany({ where: { published: true } })

   // GOOD
   prisma.posts.findMany({ where: { orgId } })
   // GOOD
   prisma.posts.findMany({ where: { orgId, published: true } })
   ```

6. **Handle Organization Switching** - When a user switches organizations, the app must handle the context change - clearing cached data and updating UI.

   ```
   <OrganizationSwitcher
     afterSelectOrganization={() => {
       router.refresh()
     }}
   />
   ```

### SHOULD (validator warns)

1. **Use OrganizationSwitcher Component** - Use Clerk's OrganizationSwitcher component instead of building custom org switching UI. It handles edge cases correctly.


   > OrganizationSwitcher handles:
- Loading states
- Create organization flow
- Personal account switching
- Error states
- Accessibility

import { OrganizationSwitcher } from '@clerk/nextjs'

<OrganizationSwitcher
  afterSelectOrganization={() => router.refresh()}
  appearance={{...}}
/>

   ```
   import { OrganizationSwitcher } from '@clerk/nextjs'
   
   export function OrgSwitcher() {
     const router = useRouter()
     return (
       <OrganizationSwitcher
         afterSelectOrganization={() => router.refresh()}
       />
     )
   }
   ```

2. **Use has() for Permission Checks** - Use has() helper for role and permission checks instead of manual role string comparisons.


   > has() provides type-safe permission checking:

const { has } = await auth()

// Check role
if (has({ role: 'org:admin' })) {
  // Admin-only action
}

// Check permission
if (has({ permission: 'org:posts:edit' })) {
  // Can edit posts
}

Define permissions in Clerk Dashboard for type safety.

   ```
   // BAD
   if (user.role === 'admin')
   // BAD
   if (membership.role === 'org:admin')

   // GOOD
   if (has({ role: 'org:admin' }))
   // GOOD
   if (has({ permission: 'org:posts:edit' }))
   ```

3. **Sync Organization to Database** - Sync Clerk organizations to your database using webhooks. This enables querying org data without Clerk API calls.


   > Set up webhooks for organization events:
- organization.created
- organization.updated
- organization.deleted
- organizationMembership.created
- organizationMembership.deleted

Store org data locally for faster queries and joins.
Use Clerk as source of truth, database as cache.


4. **Use Clerk's Built-in Components** - Prefer Clerk's pre-built components (SignIn, SignUp, UserButton, OrganizationSwitcher) over custom implementations.


   > Clerk components handle:
- OAuth flows
- MFA
- Email verification
- Error states
- Accessibility
- Loading states

Customize with appearance prop rather than rebuilding.


### GUIDANCE (not mechanically checked)

1. **Multi-Tenant Route Structure** - Recommended route structure for multi-tenant SaaS apps.


   > app/
├── (auth)/
│   ├── sign-in/[[...sign-in]]/page.tsx
│   └── sign-up/[[...sign-up]]/page.tsx
├── (marketing)/
│   ├── page.tsx                    # Landing page
│   └── pricing/page.tsx
├── (app)/
│   └── [orgSlug]/
│       ├── layout.tsx              # Org-scoped layout
│       ├── dashboard/page.tsx
│       ├── settings/page.tsx
│       └── [...]/
├── api/
│   └── webhooks/
│       └── clerk/route.ts
└── middleware.ts

Use route groups () to separate concerns.
Use [orgSlug] for org-scoped routes.


2. **Environment Variables Reference** - Standard environment variables for Clerk in Next.js.


   > # .env.local

# Safe for client (NEXT_PUBLIC_ prefix)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/dashboard
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/onboarding

# Server only (no NEXT_PUBLIC_ prefix)
CLERK_SECRET_KEY=sk_test_...
CLERK_WEBHOOK_SECRET=whsec_...

Never use NEXT_PUBLIC_ with secret key!


3. **Webhook Event Handling** - Key webhook events to handle for multi-tenant sync.


   > Essential events for multi-tenant apps:

User events:
- user.created → Create user record in database
- user.updated → Sync user profile changes
- user.deleted → Handle user deletion (soft delete?)

Organization events:
- organization.created → Create org record
- organization.updated → Sync org name/slug
- organization.deleted → Handle org deletion

Membership events:
- organizationMembership.created → Add user to org
- organizationMembership.updated → Update role
- organizationMembership.deleted → Remove user from org

Always make handlers idempotent using event IDs.


4. **Data Model for Multi-Tenant** - Database schema patterns for multi-tenant applications.


   > Core tables:

organizations:
  id            String   @id @default(cuid())
  clerkOrgId    String   @unique  // From Clerk
  name          String
  slug          String   @unique
  createdAt     DateTime @default(now())

users:
  id            String   @id @default(cuid())
  clerkUserId   String   @unique  // From Clerk
  email         String   @unique
  name          String?

organization_members:
  id            String   @id @default(cuid())
  orgId         String
  userId        String
  role          String   // org:admin, org:member
  @@unique([orgId, userId])

All tenant data tables must have orgId foreign key:

posts:
  id            String   @id @default(cuid())
  orgId         String   // REQUIRED for tenant isolation
  userId        String   // Optional for user attribution
  content       String


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| CLERK_SECRET_KEY in client |  | Only use in server-side code |
| authMiddleware |  | Use clerkMiddleware with createRouteMatcher |
| auth() in client component |  | Use useAuth() hook |
| sync auth() call |  | Always await auth() |
| hardcoded keys |  | Use environment variables |
| webhook without verification |  | Use verifyWebhook from @clerk/nextjs/webhooks |
| userId without orgId |  | Always scope data to orgId |
| missing orgId check |  | Check orgId after auth() |
