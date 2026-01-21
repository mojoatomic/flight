// Supabase test fixture - SHOULD trigger N2 violations
// Deprecated @supabase/auth-helpers-nextjs usage

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs'
import { createRouteHandlerClient } from '@supabase/auth-helpers-react'

// BAD: Using deprecated auth-helpers
export function getClientSupabase() {
  return createClientComponentClient()
}

// BAD: Server component helper also deprecated
export function getServerSupabase() {
  return createServerComponentClient({ cookies: () => ({}) })
}
