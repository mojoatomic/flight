// Webhooks test fixture - Should NOT trigger violations
// Safe webhook patterns

import crypto from 'crypto';

interface SafeWebhookPayload {
  event: string;
  data: {
    user_id: string;  // GOOD: IDs only, no secrets
    order_id: string;
  };
}

// GOOD: Safe payload without secrets
export function createSafePayload(): SafeWebhookPayload {
  return {
    event: 'order.completed',
    data: {
      user_id: 'usr_123',
      order_id: 'ord_456',
    },
  };
}

// GOOD: Timing-safe signature verification
export function verifySignatureSafe(signature: string, expected: string): boolean {
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expected, 'hex')
  );
}

// GOOD: Retry with max attempts and backoff
export async function sendWebhookSafe(
  url: string,
  payload: unknown,
  maxRetries = 5
): Promise<void> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      await fetch(url, { method: 'POST', body: JSON.stringify(payload) });
      return;
    } catch {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw new Error('Max retries exceeded');
}

// GOOD: HTTPS URLs
const webhookUrl = 'https://api.customer.com/webhooks';

// GOOD: localhost is allowed for development
const devUrl = 'http://localhost:3000/webhook';
const loopbackUrl = 'http://127.0.0.1:3000/webhook';

// GOOD: Comments mentioning bad patterns should not trigger
// Don't use file:// or ftp:// URLs!
// Never include password or api_key in payloads

// GOOD: Documentation strings should not trigger
const WARNING = "Never use signature === expected or while(true) loops";

export { webhookUrl, devUrl, loopbackUrl };
