// Supabase test fixture - Should NOT trigger violations
// Safe patterns using @supabase/ssr and env vars

import { createBrowserClient, createServerClient } from '@supabase/ssr'
import type { Database } from '@/types/supabase'

// GOOD: Using @supabase/ssr (not deprecated auth-helpers)
export function createClientSupabase() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

// GOOD: Server client with env vars
export function createServerSupabase() {
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: {} }
  )
}

// GOOD: Comments mentioning deprecated packages should not trigger
// Don't use @supabase/auth-helpers-nextjs anymore!

// GOOD: String documentation should not trigger
const WARNING = "Migrate from @supabase/auth-helpers-nextjs to @supabase/ssr"
