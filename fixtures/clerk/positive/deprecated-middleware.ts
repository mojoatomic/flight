// Clerk test fixture - SHOULD trigger N2 violation
// Deprecated authMiddleware usage

import { authMiddleware } from '@clerk/nextjs'

// BAD: Using deprecated authMiddleware
export default authMiddleware({
  publicRoutes: ['/sign-in', '/sign-up'],
})

export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
}
