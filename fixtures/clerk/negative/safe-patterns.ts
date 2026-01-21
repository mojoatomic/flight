// Clerk test fixture - Should NOT trigger violations
// Safe patterns using clerkMiddleware and env vars

import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'
import { ClerkProvider } from '@clerk/nextjs'

// GOOD: Using clerkMiddleware (not deprecated authMiddleware)
const isPublicRoute = createRouteMatcher(['/sign-in(.*)', '/sign-up(.*)'])

export default clerkMiddleware((auth, req) => {
  if (!isPublicRoute(req)) auth.protect()
})

export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
}

// GOOD: Using environment variables for keys
export function App() {
  return (
    <ClerkProvider publishableKey={process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY!}>
      <div>App</div>
    </ClerkProvider>
  )
}

// GOOD: Comments mentioning keys should not trigger
// Don't hardcode pk_test_xxx or sk_live_xxx keys!

// GOOD: String documentation should not trigger
const WARNING = "Never use pk_test_ or sk_live_ keys in code"
