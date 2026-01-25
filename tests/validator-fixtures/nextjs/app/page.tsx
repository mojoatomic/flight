// Next.js page fixture with violations for testing
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function Page() {
  const [data, setData] = useState(null);
  const router = useRouter();

  // N3: useEffect with fetch for initial page data (NEVER)
  useEffect(() => {
    fetch('/api/data')
      .then(res => res.json())
      .then(setData);
  }, []);

  // N7: console.log in app directory (NEVER)
  console.log('Debug: rendering page');

  const handleClick = () => {
    // N6: Hardcoded multi-segment route in router.push (NEVER)
    router.push('/dashboard/settings/profile');
  };

  return (
    <div>
      {/* N6: Hardcoded multi-segment route in href (NEVER) */}
      <a href="/users/admin/dashboard">Admin Dashboard</a>

      {/* N7: Another console.log */}
      {console.log('Rendering data:', data)}

      <button onClick={handleClick}>Settings</button>
    </div>
  );
}
