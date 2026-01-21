// Webhooks test fixture - SHOULD trigger N2 violations
// Secrets in webhook payloads

interface WebhookPayload {
  event: string;
  data: {
    user_id: string;
    // BAD: Sensitive fields in webhook payloads
    password: string;
    secret: string;
    api_key: string;
    ssn: string;
    credit_card: string;
  };
}

export function createPayload(): WebhookPayload {
  return {
    event: 'user.created',
    data: {
      user_id: 'usr_123',
      password: 'hunter2',
      secret: 'sk_live_abc',
      api_key: 'api_key_123',
      ssn: '123-45-6789',
      credit_card: '4111111111111111',
    },
  };
}
