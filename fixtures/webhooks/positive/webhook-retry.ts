// Webhooks test fixture - SHOULD trigger N5 and N6 violations
// Infinite retry loops

export async function sendWebhookBad1(url: string, payload: unknown): Promise<void> {
  // BAD: while(true) without backoff (N5)
  while (true) {
    try {
      await fetch(url, { method: 'POST', body: JSON.stringify(payload) });
      return;
    } catch {
      // Keep trying forever - bad!
    }
  }
}

export async function sendWebhookBad2(url: string, payload: unknown): Promise<void> {
  // BAD: for(;;) infinite loop (N6)
  for (;;) {
    try {
      await fetch(url, { method: 'POST', body: JSON.stringify(payload) });
      return;
    } catch {
      // Keep trying forever - bad!
    }
  }
}
