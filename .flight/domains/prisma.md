# Domain: Prisma Design

Prisma ORM patterns for TypeScript/Next.js applications with multi-tenant SaaS focus. Covers schema design, query patterns, N+1 prevention, error handling, connection management, and orgId-scoped data access for tenant isolation.


**Validation:** `prisma.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Queries Without orgId (Multi-tenant)** - All data queries must include orgId for tenant isolation. Queries without orgId can leak data between tenants in multi-tenant applications.

   ```
   // BAD
   prisma.post.findMany()
   // BAD
   prisma.post.findMany({ where: { published: true } })

   // GOOD
   prisma.post.findMany({ where: { orgId } })
   // GOOD
   prisma.post.findMany({ where: { orgId, published: true } })
   ```

2. **$queryRawUnsafe with User Input** - $queryRawUnsafe bypasses parameterization. Using it with user input creates SQL injection vulnerabilities. Use $queryRaw with tagged templates instead.

   ```
   // BAD
   prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = '${userId}'`)
   // BAD
   prisma.$executeRawUnsafe(`DELETE FROM posts WHERE id = ${id}`)

   // GOOD
   prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`
   // GOOD
   prisma.$executeRaw`DELETE FROM posts WHERE id = ${id}`
   ```

3. **N+1 Query Pattern** - Fetching related data in loops instead of using include creates N+1 queries. This causes severe performance issues as the number of records grows.

   ```
   // BAD
   const users = await prisma.user.findMany()
   for (const user of users) {
     const posts = await prisma.post.findMany({ where: { userId: user.id } })
   }
   

   // GOOD
   const users = await prisma.user.findMany({
     include: { posts: true }
   })
   
   ```

4. **Unhandled Prisma Errors** - Prisma throws specific error codes (P2002, P2025, etc.) that need handling. Generic catch blocks hide the actual error and provide poor user experience.

   ```
   // BAD
   try {
     await prisma.user.create({ data })
   } catch (e) {
     throw new Error('Database error')
   }
   

   // GOOD
   import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library'
   
   try {
     await prisma.user.create({ data })
   } catch (e) {
     if (e instanceof PrismaClientKnownRequestError) {
       if (e.code === 'P2002') throw new Error('Email already exists')
       if (e.code === 'P2025') throw new Error('Record not found')
     }
     throw e
   }
   
   ```

5. **New PrismaClient Per Request** - Creating PrismaClient instances per request exhausts database connections. Use a singleton pattern to reuse the client across requests.

   ```
   // BAD
   export async function handler() {
     const prisma = new PrismaClient()
     // ...
   }
   

   // GOOD
   import { PrismaClient } from '@prisma/client'
   
   const globalForPrisma = globalThis as { prisma?: PrismaClient }
   export const prisma = globalForPrisma.prisma ?? new PrismaClient()
   if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
   
   ```

6. **Fetching All Fields When Not Needed** - Fetching all fields when only some are needed wastes bandwidth and memory. Use select to fetch only required fields, especially for large tables.


   > Use select to fetch specific fields:

BAD:
  const users = await prisma.user.findMany()  // fetches everything

GOOD:
  const users = await prisma.user.findMany({
    select: { id: true, name: true, email: true }
  })

This is especially important for:
- Large text/JSON fields
- Tables with many columns
- High-traffic endpoints


7. **Missing Unique Constraint Handling** - create() without handling unique violations crashes on duplicate data. Either use upsert or catch P2002 errors.

   ```
   // BAD
   await prisma.user.create({ data: { email } })

   // GOOD
   await prisma.user.upsert({
     where: { email },
     update: {},
     create: { email, name }
   })
   
   ```

### MUST (validator will reject)

1. **Use include for Relations** - Fetch related data in a single query using include instead of separate queries. This prevents N+1 problems and improves performance.


   > Use include to fetch related data:

const userWithPosts = await prisma.user.findUnique({
  where: { id },
  include: {
    posts: true,
    profile: true
  }
})

Or use select for fine-grained control:

const userWithPosts = await prisma.user.findUnique({
  where: { id },
  include: {
    posts: {
      select: { id: true, title: true }
    }
  }
})


2. **Handle P2002 (Unique Constraint)** - Unique constraint violations must have user-friendly error messages. Don't expose raw database errors to users.


   > P2002 means a unique constraint was violated. Handle it:

try {
  await prisma.user.create({ data })
} catch (e) {
  if (e instanceof PrismaClientKnownRequestError) {
    if (e.code === 'P2002') {
      // e.meta.target contains the field(s) that caused the violation
      const field = (e.meta?.target as string[])?.[0] ?? 'field'
      throw new Error(`A record with this ${field} already exists`)
    }
  }
  throw e
}


3. **Handle P2025 (Record Not Found)** - Record not found errors from update/delete need handling. Provide clear feedback when the record doesn't exist.


   > P2025 occurs when update/delete can't find the record:

try {
  await prisma.post.update({
    where: { id },
    data: { title: 'New Title' }
  })
} catch (e) {
  if (e instanceof PrismaClientKnownRequestError) {
    if (e.code === 'P2025') {
      throw new Error('Post not found')
    }
  }
  throw e
}

Or use updateMany which returns count instead of throwing:

const { count } = await prisma.post.updateMany({
  where: { id, orgId },
  data: { title: 'New Title' }
})
if (count === 0) throw new Error('Post not found')


4. **Singleton Client Pattern** - Use the global singleton pattern for PrismaClient, not per-request instantiation. This is critical for connection pool management.


5. **Type Generated Client** - Run `prisma generate` after schema changes to regenerate the typed client. Stale types cause runtime errors and type mismatches.


   > After any schema.prisma change:

1. npx prisma generate  # Regenerate client
2. npx prisma db push   # Or prisma migrate dev

Add to package.json for CI:
{
  "scripts": {
    "postinstall": "prisma generate"
  }
}

This ensures the client is always in sync with the schema.


6. **Include orgId in Schema** - All tenant-scoped models must have an orgId field for multi-tenant data isolation. This is the foundation of tenant security.

   ```
   model Post {
     id        String   @id @default(cuid())
     orgId     String
     title     String
     org       Organization @relation(fields: [orgId], references: [id])
   
     @@index([orgId])
   }
   ```

### SHOULD (validator warns)

1. **Use select Over include When Possible** - select returns only specified fields, include returns all fields of related models. Use select for better performance when you don't need all fields.


   > include fetches all fields of the relation:

// Fetches ALL post fields
prisma.user.findMany({ include: { posts: true } })

select fetches only specified fields:

// Fetches only id and title
prisma.user.findMany({
  include: {
    posts: {
      select: { id: true, title: true }
    }
  }
})


2. **Use Transactions for Multi-Step Operations** - Use transactions when multiple operations must succeed or fail together. This ensures data consistency.


   > Use $transaction for atomic operations:

// Sequential transaction (simple)
await prisma.$transaction([
  prisma.post.create({ data: post1 }),
  prisma.post.create({ data: post2 }),
])

// Interactive transaction (complex logic)
await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: userData })
  await tx.post.create({ data: { ...postData, userId: user.id } })
  return user
})

Transactions rollback all operations if any fails.


3. **Enable Query Logging in Development** - Enable query logging in development to identify slow queries and N+1 problems early.


   > Enable logging in PrismaClient:

const prisma = new PrismaClient({
  log: [
    { level: 'query', emit: 'event' },
    { level: 'error', emit: 'stdout' },
    { level: 'warn', emit: 'stdout' },
  ],
})

// Log queries with duration
prisma.$on('query', (e) => {
  console.log(`Query: ${e.query}`)
  console.log(`Duration: ${e.duration}ms`)
})

This helps identify:
- N+1 query patterns
- Slow queries
- Missing indexes


4. **Use Prisma Error Types** - Import and check PrismaClientKnownRequestError for proper error handling. This enables specific error messages for different failure modes.


   > Import error types from Prisma:

import {
  PrismaClientKnownRequestError,
  PrismaClientValidationError,
} from '@prisma/client/runtime/library'

try {
  await prisma.user.create({ data })
} catch (e) {
  if (e instanceof PrismaClientKnownRequestError) {
    // Database-level errors (P2xxx codes)
    console.log('Error code:', e.code)
    console.log('Meta:', e.meta)
  }
  if (e instanceof PrismaClientValidationError) {
    // Query validation errors (wrong types, missing fields)
  }
  throw e
}


### GUIDANCE (not mechanically checked)

1. **Common Error Codes** - Reference for common Prisma error codes and their meanings.


   > Common Prisma error codes:

P2002 - Unique constraint violation
  "Unique constraint failed on the {constraint}"
  Cause: Duplicate value for unique field

P2003 - Foreign key constraint violation
  "Foreign key constraint failed on the field: {field_name}"
  Cause: Referenced record doesn't exist

P2025 - Record not found
  "An operation failed because it depends on one or more records
   that were required but not found."
  Cause: update/delete on non-existent record

P2014 - Required relation violation
  "The change you are trying to make would violate the required
   relation '{relation_name}'"
  Cause: Breaking a required relation

P2024 - Connection pool timeout
  "Timed out fetching a new connection from the connection pool"
  Cause: Too many connections, pool exhausted


2. **Multi-tenant Schema Pattern** - Recommended schema pattern for multi-tenant applications.


   > model Organization {
  id        String   @id @default(cuid())
  clerkOrgId String  @unique  // If using Clerk
  name      String
  slug      String   @unique
  createdAt DateTime @default(now())
  posts     Post[]
  members   Membership[]
}

model User {
  id          String   @id @default(cuid())
  clerkUserId String   @unique  // If using Clerk
  email       String   @unique
  name        String?
  memberships Membership[]
}

model Membership {
  id     String       @id @default(cuid())
  orgId  String
  userId String
  role   String       // admin, member, etc.
  org    Organization @relation(fields: [orgId], references: [id])
  user   User         @relation(fields: [userId], references: [id])

  @@unique([orgId, userId])
}

model Post {
  id        String       @id @default(cuid())
  orgId     String       // REQUIRED for tenant isolation
  userId    String?      // Optional author attribution
  title     String
  content   String
  org       Organization @relation(fields: [orgId], references: [id])

  @@index([orgId])
}


3. **Singleton Pattern for Next.js** - Standard singleton pattern for PrismaClient in Next.js applications.


   > // lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as { prisma?: PrismaClient }

export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development'
    ? ['query', 'error', 'warn']
    : ['error'],
})

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}

Why this works:
- globalThis persists across hot reloads in development
- Production creates one instance per serverless function
- Prevents connection pool exhaustion


4. **Connection Pool Configuration** - Connection pool settings for different environments.


   > Configure connection pool in DATABASE_URL:

# Development (local)
DATABASE_URL="postgresql://user:pass@localhost:5432/db?connection_limit=5"

# Serverless (Vercel, etc.)
DATABASE_URL="postgresql://user:pass@host:5432/db?connection_limit=1&pool_timeout=10"

# With Prisma Accelerate (recommended for serverless)
DATABASE_URL="prisma://accelerate.prisma-data.net/?api_key=xxx"

Key parameters:
- connection_limit: Max connections per instance (low for serverless)
- pool_timeout: How long to wait for connection (seconds)
- connect_timeout: Connection establishment timeout


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Queries without orgId |  | Always include orgId in where clause |
| $queryRawUnsafe with user input |  | Use $queryRaw with tagged templates |
| N+1 queries |  | Use include or select for relations |
| Generic error handling |  | Handle specific Prisma error codes |
| new PrismaClient per request |  | Use singleton pattern |
| Missing orgId in schema |  | Add orgId field to all tenant data models |
| .create without unique handling |  | Use upsert or catch P2002 |
