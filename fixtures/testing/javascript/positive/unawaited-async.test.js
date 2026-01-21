// N5: Unawaited Async Assertions - VIOLATIONS

test('fetches data without await', () => {
  fetchData().then(data => expect(data).toBeDefined());
});

test('fetches with arrow assertion', () => {
  getData().then(result => {
    expect(result.status).toBe(200);
  });
});

test('chains then with assert', () => {
  apiCall().then(response => assert.ok(response));
});
