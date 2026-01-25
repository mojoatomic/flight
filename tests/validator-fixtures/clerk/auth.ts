// Clerk auth fixture with violations for testing
import { authMiddleware } from '@clerk/nextjs'; // N2: Deprecated authMiddleware

// N5: Hardcoded Clerk key (NEVER do this)
const CLERK_KEY = 'pk_test_abc123xyz456';

// Another N5 violation - secret key
const SECRET_KEY = 'sk_live_secretkey789';

// This is a properly configured component (no violations)
export default function DashboardPage() {
  return <div>Dashboard</div>;
}

// Deprecated middleware export (N2 violation)
export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
};

export default authMiddleware();
