// Testing domain test fixture - TypeScript negative cases
// These should NOT trigger violations

import { describe, test, it, expect } from 'vitest';

// GOOD: Descriptive test names (not N1_ts violation)
test('should return user when valid ID provided', () => {
  const user = { id: 1, name: 'Alice' };
  expect(user.id).toBe(1);
});

it('returns empty array when no results found', () => {
  const results: string[] = [];
  expect(results).toHaveLength(0);
});

describe('UserService', () => {
  test('creates user with valid email', () => {
    const email = 'test@example.com';
    expect(email).toContain('@');
  });
});

// GOOD: Using waitFor instead of sleep (not N3_ts violation)
async function goodTestWithWaitFor(): Promise<void> {
  await waitFor(() => {
    expect(document.querySelector('.loaded')).toBeTruthy();
  });
}

// GOOD: Using public methods in expect (not N4_ts violation)
interface Service {
  publicMethod: () => string;
  getStatus: () => string;
}

test('tests public method', () => {
  const service: Service = {
    publicMethod: () => 'result',
    getStatus: () => 'active',
  };
  expect(service.publicMethod()).toBe('result');
  expect(service.getStatus()).toBe('active');
});

// GOOD: Using async/await instead of .then (not N5_ts violation)
test('fetches data with async await', async () => {
  const data = await fetchData();
  expect(data).toBeDefined();
});

// GOOD: Another async/await example (not N5_ts violation)
test('processes multiple async operations', async () => {
  const first = await fetchData();
  const second = await fetchData();
  expect(first).toBeDefined();
  expect(second).toBeDefined();
});

// GOOD: Using test.each instead of loops (not S4_ts violation)
test.each([
  [1, 2, 3],
  [2, 3, 5],
  [5, 5, 10],
])('adds %i + %i to equal %i', (a, b, expected) => {
  expect(a + b).toBe(expected);
});

// Helper declarations
declare function waitFor(callback: () => void): Promise<void>;
declare function fetchData(): Promise<unknown>;
