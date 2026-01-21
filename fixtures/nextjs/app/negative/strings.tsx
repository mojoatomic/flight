// Negative test fixture: Patterns in strings should NOT trigger violations
// This file tests that AST rules only match actual code, not string contents

'use client';

import { useState } from 'react';

export default function SafeStringsComponent() {
  // N3: Pattern in string - should NOT trigger
  const exampleBad = "useEffect(() => { fetch('/api/data'); }, [])";
  const helpText = 'Do not use useEffect to fetch initial page data';
  const axiosExample = `axios.get('/api/users')`;

  // N6: Path-like strings that are NOT href attributes - should NOT trigger
  const filePath = '/home/user/documents/file.txt';
  const apiEndpoint = '/api/v1/users/create';
  const docText = "Don't use href=\"/dashboard/settings/profile\"";
  const pushExample = "router.push('/admin/users/roles')";

  // N7: Pattern in string - should NOT trigger
  const debugHint = 'Remove console.log before deploying';
  const codeExample = `console.log('debug')`;
  const errorMsg = "Found console.log in production code";

  // Template literals with patterns - should NOT trigger
  const multiLine = `
    Bad patterns:
    - console.log('test')
    - useEffect(() => fetch())
    - href="/a/b/c/d"
  `;

  return (
    <div>
      <p>{helpText}</p>
      <code>{exampleBad}</code>
      <pre>{multiLine}</pre>
    </div>
  );
}
