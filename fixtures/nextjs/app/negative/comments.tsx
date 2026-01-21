// Negative test fixture: Patterns in comments should NOT trigger violations
// This file tests that AST rules ignore comments

'use client';

import { useState } from 'react';

export default function SafeCommentsComponent() {
  const [data, setData] = useState(null);

  // N3: This comment mentions useEffect and fetch but should NOT trigger
  // Example: useEffect(() => { fetch('/api/data'); }, [])
  // Don't use useEffect to fetch initial data

  // N6: This comment mentions hardcoded routes but should NOT trigger
  // Bad: href="/dashboard/settings/profile"
  // Bad: router.push('/admin/users/roles')

  // N7: This comment mentions console.log but should NOT trigger
  // Remove console.log('debug') before committing
  // console.log is not allowed in production

  /*
   * Multi-line comment with violations:
   * - console.log('test')
   * - useEffect(() => fetch())
   * - href="/a/b/c/d"
   * These should NOT trigger
   */

  return (
    <div>
      {/* JSX comment with console.log - should NOT trigger */}
      {/* href="/dashboard/settings/profile" */}
      <p>Safe component with comments</p>
    </div>
  );
}
