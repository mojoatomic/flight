// Positive test fixture for N7: console.log in App Directory
// All patterns below SHOULD trigger violations

'use client';

import { useState } from 'react';

export default function BadLogging() {
  const [count, setCount] = useState(0);

  // Pattern 1: Direct console.log - SHOULD TRIGGER
  console.log('component rendered');

  const handleClick = () => {
    // Pattern 2: console.log in handler - SHOULD TRIGGER
    console.log('button clicked', count);
    setCount(count + 1);
  };

  // Pattern 3: Debugging log - SHOULD TRIGGER
  console.log('data:', { count });

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={handleClick}>Increment</button>
    </div>
  );
}
