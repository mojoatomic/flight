// N3: Hardcoded Sleep/Delays - VIOLATIONS

test('waits with sleep', async () => {
  await sleep(1000);
  expect(true).toBe(true);
});

test('waits with Promise setTimeout', async () => {
  await new Promise(r => setTimeout(r, 100));
  expect(true).toBe(true);
});

test('waits with Promise resolve setTimeout', async () => {
  await new Promise(resolve => setTimeout(resolve, 500));
  expect(true).toBe(true);
});
