// N1: Enumerated Test Names - VIOLATIONS
// These should all be flagged

// test() with enumerated names
test('test1', () => {
  expect(true).toBe(true);
});

test('test2', () => {
  expect(true).toBe(true);
});

// it() with enumerated names
it('1', () => {
  expect(true).toBe(true);
});

it('2', () => {
  expect(true).toBe(true);
});

// Variations
test('testA', () => {
  expect(true).toBe(true);
});

test('test_1', () => {
  expect(true).toBe(true);
});
