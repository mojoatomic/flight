// S4: Logic in Tests - VIOLATIONS

test('validates with if logic', () => {
  const items = getItems();
  if (items.length > 0) {
    expect(items[0]).toBeDefined();
  }
});

test('validates with for loop', () => {
  const items = getItems();
  for (const item of items) {
    expect(item.valid).toBe(true);
  }
});

test('validates with while loop', () => {
  let count = 0;
  while (count < 5) {
    expect(getData(count)).toBeDefined();
    count++;
  }
});
