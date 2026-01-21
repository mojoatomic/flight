// Testing domain test fixture - TypeScript positive cases
// These should trigger violations

import { describe, test, it, expect } from 'vitest';

// N1_ts: Enumerated test names (should trigger)
test('test1', () => {
  expect(true).toBe(true);
});

test('test2', () => {
  expect(true).toBe(true);
});

it('1', () => {
  expect(true).toBe(true);
});

// N3_ts: Sleep function calls (should trigger)
async function badTestWithSleep(): Promise<void> {
  await sleep(1000);
  expect(true).toBe(true);
}

// N3_ts_promise: Promise setTimeout (should trigger)
async function badTestWithPromise(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 100));
  expect(true).toBe(true);
}

// N4_ts: Testing private members (should trigger)
interface Service {
  _privateMethod: () => string;
  publicMethod: () => string;
}

test('tests private method', () => {
  const service: Service = {
    _privateMethod: () => 'private',
    publicMethod: () => 'public',
  };
  expect(service._privateMethod()).toBe('private');
});

// N5_ts: Unawaited .then() callbacks (should trigger)
test('unawaited then', () => {
  fetchData().then((data) => {
    expect(data).toBeDefined();
  });
});

// S4_ts: Logic in tests (should trigger warnings)
test('test with if', () => {
  const value = getValue();
  if (value > 5) {
    expect(value).toBeGreaterThan(5);
  }
});

test('test with for loop', () => {
  for (let i = 0; i < 5; i++) {
    expect(i).toBeLessThan(5);
  }
});

// Helper declarations
declare function sleep(ms: number): Promise<void>;
declare function fetchData(): Promise<unknown>;
declare function getValue(): number;
