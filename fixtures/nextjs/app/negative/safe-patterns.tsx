// Next.js test fixture - Should NOT trigger violations
// Safe patterns that comply with Next.js best practices

import Link from 'next/link';
import { routes } from '@/lib/routes';

// GOOD: Server component with direct data fetching (no useEffect)
export default async function Page() {
  const data = await fetch('https://api.example.com/data');
  return <Display data={data} />;
}

// GOOD: Using route constants instead of hardcoded paths
export function Navigation() {
  return (
    <nav>
      <Link href={routes.profile}>Profile</Link>
      <Link href="/about">About</Link>  {/* Single segment is OK */}
      <Link href="/settings">Settings</Link>
    </nav>
  );
}

// GOOD: Comments mentioning patterns should not trigger
// Don't use useEffect(() => { fetch(...) }) for initial data!
// Avoid console.log in production code

// GOOD: String documentation should not trigger
const WARNING = "Don't use console.log or useEffect fetch patterns";

function Display({ data }: { data: unknown }) {
  return <pre>{JSON.stringify(data)}</pre>;
}
