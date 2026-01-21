// Clerk test fixture - SHOULD trigger N5 violations
// Hardcoded Clerk API keys

import { ClerkProvider } from '@clerk/nextjs'

// BAD: Hardcoded publishable key (test)
const publishableKey = 'pk_test_abc123xyz789def456'

// BAD: Hardcoded publishable key (live)
const liveKey = 'pk_live_productionkey12345'

// BAD: Hardcoded secret key (test) - CRITICAL SECURITY ISSUE
const secretKey = 'sk_test_secretkey987654321'

// BAD: Hardcoded secret key (live) - CRITICAL SECURITY ISSUE
const liveSecretKey = 'sk_live_productiontopsecret'

export function App() {
  return (
    <ClerkProvider publishableKey={publishableKey}>
      <div>App</div>
    </ClerkProvider>
  )
}
