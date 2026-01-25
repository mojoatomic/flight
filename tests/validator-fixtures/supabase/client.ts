// Supabase fixture with violations for testing
import { createClient } from '@supabase/supabase-js';

// N2: Deprecated @supabase/auth-helpers-nextjs (NEVER) - AST rule
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';

// This is correct - using env vars
const goodClient = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// N4: Hardcoded Supabase credentials (NEVER) - AST rule
// Note: URL contains "supabase" and key starts with "ey"
const badClient = createClient(
  'https://abcdefg.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret'
);

// Another N4 violation
const anotherBadClient = createClient(
  'https://myproject.supabase.co/rest/v1',
  'eyJhbGciOiJIUzI1NiJ9.anon-key-here'
);
