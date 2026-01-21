// Positive test fixture for N3: useEffect fetch for initial page data
// All patterns below SHOULD trigger violations

'use client';

import { useState, useEffect } from 'react';

export default function BadDataFetching() {
  const [data, setData] = useState(null);
  const [users, setUsers] = useState([]);

  // Pattern 1: Direct fetch in useEffect - SHOULD TRIGGER
  useEffect(() => {
    fetch('/api/data').then(r => r.json()).then(setData);
  }, []);

  // Pattern 2: axios in useEffect - SHOULD TRIGGER
  useEffect(() => {
    axios.get('/api/users').then(r => setUsers(r.data));
  }, []);

  return <div>{data}</div>;
}
