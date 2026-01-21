// N4: Testing Private Methods - VIOLATIONS

test('tests private method', () => {
  const obj = createObject();
  expect(obj._privateMethod()).toBe(true);
});

test('tests private property', () => {
  const obj = createObject();
  expect(obj._internalValue).toBe(42);
});

test('tests dunder private', () => {
  const obj = createObject();
  expect(obj.__veryPrivate).toBeDefined();
});
