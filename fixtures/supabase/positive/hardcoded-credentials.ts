// Supabase test fixture - SHOULD trigger N4 violations
// Hardcoded Supabase credentials

import { createClient } from '@supabase/supabase-js'

// BAD: Hardcoded URL and anon key
const supabase1 = createClient(
  'https://xyzproject.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByb2plY3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoxOTAwMDAwMDAwfQ.abc123'
)

// BAD: Another hardcoded example
const supabase2 = createClient('https://another.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xyz789')
