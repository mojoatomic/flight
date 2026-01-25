// Test file with violations
import { describe, it, expect } from 'vitest';

// N1: Enumerated test names
describe('MyComponent', () => {
  it('test 1', () => {
    expect(true).toBe(true);
  });
  
  it('test 2', () => {
    expect(false).toBe(false);
  });
});

// N2: Empty test body
it('should do something', () => {
});

// N3: Hardcoded sleep/delay
it('waits for async', async () => {
  await new Promise(resolve => setTimeout(resolve, 1000));
  expect(true).toBe(true);
});

// N4: Testing private methods
it('tests private method', () => {
  const result = component._privateMethod();
  expect(result).toBeDefined();
});

// S4: Logic in tests
it('has conditionals', () => {
  if (process.env.CI) {
    expect(true).toBe(true);
  }
});
