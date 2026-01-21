// Positive test fixture for N6: Hardcoded multi-segment routes
// All patterns below SHOULD trigger violations

'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';

export default function BadRoutes() {
  const router = useRouter();

  const handleClick = () => {
    // Pattern 1: router.push with multi-segment path - SHOULD TRIGGER
    router.push('/dashboard/settings/profile');
  };

  const handleNavigate = () => {
    // Pattern 2: router.push with deep path - SHOULD TRIGGER
    router.push('/admin/users/roles/permissions');
  };

  return (
    <div>
      {/* Pattern 3: Link href with multi-segment path - SHOULD TRIGGER */}
      <Link href="/dashboard/settings/profile">Profile</Link>

      {/* Pattern 4: Link href with deep path - SHOULD TRIGGER */}
      <Link href="/admin/users/edit/123">Edit User</Link>

      <button onClick={handleClick}>Go to Profile</button>
    </div>
  );
}
