# Domain: Webhooks

Outbound event notification design. Covers both webhook **providers** (sending) and **consumers** (receiving). Prevents integration failures, data loss, and security breaches.

**Validation:** `webhooks_validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings.

---

## Invariants

### NEVER (validator will reject)

1. **Plain HTTP for Webhook URLs** - All webhook traffic must be encrypted
   ```
   // BAD - payload visible to attackers
   http://api.customer.com/webhooks

   // GOOD - TLS encrypted
   https://api.customer.com/webhooks
   ```

2. **Missing Signature Verification** - Webhooks without signatures can be forged
   ```javascript
   // BAD - accepts any request claiming to be a webhook
   app.post('/webhook', (req, res) => {
     processEvent(req.body);  // No verification!
     res.sendStatus(200);
   });

   // GOOD - verify HMAC signature before processing
   app.post('/webhook', (req, res) => {
     const signature = req.headers['x-webhook-signature'];
     const expected = hmac('sha256', SECRET, JSON.stringify(req.body));
     if (!timingSafeEqual(signature, expected)) {
       return res.sendStatus(401);
     }
     processEvent(req.body);
     res.sendStatus(200);
   });
   ```

3. **Secrets in Payloads** - Webhook payloads may be logged or intercepted
   ```javascript
   // BAD - sensitive data in payload
   {
     "event": "user.created",
     "data": {
       "api_key": "sk_live_abc123",
       "password": "hunter2",
       "ssn": "123-45-6789"
     }
   }

   // GOOD - IDs only, consumer fetches sensitive data via API
   {
     "event": "user.created",
     "data": {
       "user_id": "usr_abc123",
       "fetch_url": "/api/users/usr_abc123"
     }
   }
   ```

4. **Synchronous Processing** - Blocking on webhook handlers causes timeouts
   ```javascript
   // BAD - processing inline (provider may timeout, retry, duplicate)
   app.post('/webhook', async (req, res) => {
     await processPayment(req.body);      // Takes 30 seconds
     await updateInventory(req.body);     // Another 10 seconds
     await sendNotification(req.body);    // More time...
     res.sendStatus(200);                 // Too late, provider already retried
   });

   // GOOD - acknowledge immediately, process async
   app.post('/webhook', async (req, res) => {
     const verified = verifySignature(req);
     if (!verified) return res.sendStatus(401);
     
     await queue.add('process-webhook', req.body);  // Enqueue for async processing
     res.sendStatus(200);                           // ACK within seconds
   });
   ```

5. **No Idempotency Handling** - Webhooks are delivered at-least-once
   ```javascript
   // BAD - duplicate webhook = duplicate charge
   app.post('/webhook', (req, res) => {
     chargeCustomer(req.body.amount);  // Called twice = charged twice
     res.sendStatus(200);
   });

   // GOOD - use delivery ID to dedupe
   app.post('/webhook', async (req, res) => {
     const deliveryId = req.headers['x-webhook-id'];
     
     if (await cache.exists(deliveryId)) {
       return res.sendStatus(200);  // Already processed
     }
     
     await processPayment(req.body);
     await cache.set(deliveryId, true, { ttl: '48h' });
     res.sendStatus(200);
   });
   ```

6. **String Comparison for Signatures** - Vulnerable to timing attacks
   ```javascript
   // BAD - timing attack reveals signature byte-by-byte
   if (signature === expected) { ... }
   if (signature == computedSignature) { ... }

   // GOOD - constant-time comparison
   const crypto = require('crypto');
   if (crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) { ... }
   ```

7. **Infinite Retry Without Backoff** - Hammers failing endpoints
   ```javascript
   // BAD - retry storm on failing endpoint
   while (!success) {
     await sendWebhook(url, payload);  // No delay, no limit
   }

   // GOOD - exponential backoff with cap
   // Retry at: 5s, 25s, 125s, 625s... (5^n seconds)
   // Cap at 10 attempts, then DLQ
   ```

8. **SSRF via Webhook URLs** (Provider) - User-supplied URLs can target internal services
   ```javascript
   // BAD - accept any URL without validation
   app.post('/webhooks', (req, res) => {
     await db.saveWebhook({ url: req.body.url });  // Could be internal!
     res.json({ success: true });
   });

   // Attacker registers:
   // http://169.254.169.254/latest/meta-data/  (AWS metadata)
   // http://localhost:6379/                     (Redis)
   // http://10.0.0.1:8080/admin                 (Internal admin)
   // file:///etc/passwd                         (Local files)

   // GOOD - validate URL before accepting
   const { isValidWebhookUrl } = require('./url-validator');

   app.post('/webhooks', async (req, res) => {
     const validation = await isValidWebhookUrl(req.body.url);
     if (!validation.valid) {
       return res.status(400).json({ error: validation.reason });
     }
     await db.saveWebhook({ url: req.body.url });
     res.json({ success: true });
   });
   ```

9. **Accepting Internal/Private IPs** (Provider) - SSRF attack vector
   ```javascript
   // NEVER allow webhooks to these ranges:
   // 127.0.0.0/8      - Loopback
   // 10.0.0.0/8       - Private Class A
   // 172.16.0.0/12    - Private Class B
   // 192.168.0.0/16   - Private Class C
   // 169.254.0.0/16   - Link-local
   // 0.0.0.0/8        - Current network
   // ::1/128          - IPv6 loopback
   // fc00::/7         - IPv6 private

   // Also block:
   // - file://, ftp://, gopher:// schemes
   // - URLs that resolve to private IPs (DNS rebinding)
   ```

### MUST (validator will reject)

1. **Include Event Type in Payload**
   ```javascript
   // Standard format: resource.action
   {
     "event": "order.completed",      // or "type" or "event_type"
     "data": { ... }
   }

   // Event naming convention: noun.verb (dot-delimited hierarchy)
   // GOOD: user.created, payment.failed, subscription.renewed
   // BAD: createUser, PAYMENT_FAILED, UserWasCreated
   ```

2. **Include Timestamp in Payload**
   ```javascript
   {
     "event": "order.completed",
     "timestamp": "2024-01-15T10:30:00Z",  // ISO 8601, UTC
     "data": { ... }
   }

   // Used for:
   // - Replay attack prevention (reject if too old)
   // - Out-of-order detection
   // - Debugging
   ```

3. **Include Unique Delivery ID**
   ```javascript
   // In header (preferred)
   X-Webhook-ID: whk_abc123xyz
   X-Delivery-ID: del_789def

   // Or in payload
   {
     "id": "evt_abc123",           // Event ID (same across retries)
     "delivery_id": "del_789def", // Delivery ID (unique per attempt)
     ...
   }
   ```

4. **Sign Payloads with HMAC**
   ```javascript
   // Provider: sign the payload
   const payload = JSON.stringify(body);
   const timestamp = Date.now();
   const signedPayload = `${timestamp}.${payload}`;
   const signature = crypto
     .createHmac('sha256', secret)
     .update(signedPayload)
     .digest('hex');

   // Send in headers
   headers['X-Webhook-Signature'] = `t=${timestamp},v1=${signature}`;
   ```

5. **Return 2xx Within Timeout Window**
   ```javascript
   // Most providers expect response within 5-30 seconds
   // GitHub: 10 seconds
   // Stripe: 20 seconds
   // Shopify: 5 seconds

   // Consumer MUST:
   // 1. Verify signature
   // 2. Enqueue for async processing
   // 3. Return 200/202 immediately

   // Provider interprets:
   // 2xx = delivered, stop retrying
   // 4xx = permanent failure, may stop retrying
   // 5xx = temporary failure, will retry
   // Timeout = temporary failure, will retry
   ```

6. **Implement Retry with Exponential Backoff**
   ```javascript
   // Provider retry schedule example:
   // Attempt 1: immediate
   // Attempt 2: 5 seconds
   // Attempt 3: 25 seconds
   // Attempt 4: 125 seconds
   // Attempt 5: 625 seconds (~10 min)
   // Attempt 6: 3125 seconds (~52 min)
   // ...
   // Cap at 10 attempts over ~61 hours

   const delay = Math.min(
     BASE_DELAY * Math.pow(MULTIPLIER, attempt) + jitter(),
     MAX_DELAY
   );

   // Add jitter to prevent thundering herd
   function jitter() {
     return Math.random() * 1000;  // 0-1000ms random
   }
   ```

7. **Route Failed Webhooks to Dead Letter Queue**
   ```javascript
   // After max retries exhausted:
   {
     "webhook_id": "whk_abc123",
     "event": "order.completed",
     "payload": { ... },
     "attempts": 10,
     "last_error": "Connection timeout",
     "last_attempt_at": "2024-01-15T10:30:00Z",
     "created_at": "2024-01-13T10:30:00Z"
   }

   // DLQ enables:
   // - Manual inspection
   // - Replay after fix
   // - Audit trail
   // - Alerting on DLQ depth
   ```

8. **Reject Stale Timestamps** (Consumer)
   ```javascript
   // Prevent replay attacks
   const MAX_AGE_SECONDS = 300;  // 5 minutes

   const timestamp = parseInt(req.headers['x-webhook-timestamp']);
   const age = (Date.now() / 1000) - timestamp;

   if (age > MAX_AGE_SECONDS) {
     return res.status(400).json({ error: 'Webhook timestamp too old' });
   }
   ```

9. **Validate Webhook URLs Before Registration** (Provider)
   ```javascript
   async function validateWebhookUrl(url) {
     // 1. Parse and validate scheme
     const parsed = new URL(url);
     if (parsed.protocol !== 'https:') {
       return { valid: false, reason: 'HTTPS required' };
     }

     // 2. Block internal hostnames
     const blockedHosts = ['localhost', '127.0.0.1', '0.0.0.0'];
     if (blockedHosts.includes(parsed.hostname)) {
       return { valid: false, reason: 'Internal hosts not allowed' };
     }

     // 3. Resolve DNS and check for private IPs
     const addresses = await dns.resolve(parsed.hostname);
     for (const ip of addresses) {
       if (isPrivateIP(ip)) {
         return { valid: false, reason: 'Private IP addresses not allowed' };
       }
     }

     // 4. Optional: Send verification challenge
     return { valid: true };
   }

   function isPrivateIP(ip) {
     // Check against RFC 1918, loopback, link-local, etc.
     const privateRanges = [
       /^127\./,                    // Loopback
       /^10\./,                     // Class A private
       /^172\.(1[6-9]|2\d|3[01])\./, // Class B private
       /^192\.168\./,               // Class C private
       /^169\.254\./,               // Link-local
       /^0\./,                      // Current network
     ];
     return privateRanges.some(r => r.test(ip));
   }
   ```

10. **Use Egress Proxy for Webhook Delivery** (Provider)
    ```javascript
    // Route webhook requests through dedicated proxy
    // that enforces network security policies

    // Options:
    // - Smokescreen (https://github.com/stripe/smokescreen)
    // - Webhook-sentry
    // - Custom egress proxy

    // Benefits:
    // - Centralized IP filtering
    // - Network isolation
    // - Audit logging
    // - Rate limiting per destination
    ```

### SHOULD (validator warns)

1. **Keep Payloads Small (<20KB)**
   ```javascript
   // BAD - huge payload
   {
     "event": "report.generated",
     "data": {
       "report": "<base64 encoded 5MB PDF>"
     }
   }

   // GOOD - reference to resource
   {
     "event": "report.generated",
     "data": {
       "report_id": "rpt_abc123",
       "download_url": "https://api.example.com/reports/rpt_abc123"
     }
   }
   ```

2. **Provide IP Allowlist** (Provider)
   ```
   Publish IPs webhooks originate from:
   
   Webhook Source IPs:
   - 192.0.2.1/32
   - 198.51.100.0/24
   
   Consumers can optionally allowlist (but signature verification is primary defense)
   ```

3. **Support Secret Rotation**
   ```javascript
   // Provider: sign with multiple keys during rotation
   headers['X-Webhook-Signature'] = 
     `v1=${signWithOldKey},v1=${signWithNewKey}`;

   // Consumer: accept either key during transition
   const isValid = secrets.some(secret => 
     verifySignature(payload, signature, secret)
   );
   ```

4. **Include API Version in Payload**
   ```javascript
   {
     "api_version": "2024-01-15",
     "event": "order.completed",
     "data": { ... }
   }

   // Enables:
   // - Schema evolution
   // - Backward compatibility
   // - Consumer-specific handling
   ```

5. **Send Test/Ping Events**
   ```javascript
   // Webhook registration flow:
   // 1. Consumer provides URL
   // 2. Provider sends test event
   // 3. Consumer must respond 2xx
   // 4. Registration succeeds

   {
     "event": "webhook.test",
     "data": {
       "message": "This is a test webhook"
     }
   }
   ```

6. **Log Webhook Activity** (Both sides)
   ```javascript
   // Provider logs:
   {
     "webhook_id": "whk_abc123",
     "endpoint": "https://customer.com/webhook",
     "event": "order.completed",
     "status": 200,
     "latency_ms": 245,
     "attempt": 1
   }

   // Consumer logs:
   {
     "delivery_id": "del_xyz789",
     "event": "order.completed",
     "signature_valid": true,
     "processing_status": "queued",
     "response_code": 200
   }

   // Never log: secrets, full payloads with PII
   ```

7. **Provide Delivery Status API** (Provider)
   ```javascript
   // Let consumers check delivery status
   GET /webhooks/deliveries/del_abc123

   {
     "id": "del_abc123",
     "event": "order.completed",
     "status": "delivered",       // pending, delivered, failed, dead_letter
     "attempts": 2,
     "last_response_code": 200,
     "delivered_at": "2024-01-15T10:30:05Z"
   }
   ```

8. **Support Webhook Replay** (Provider)
   ```javascript
   // Allow consumers to request redelivery
   POST /webhooks/deliveries/del_abc123/replay

   // Use cases:
   // - Consumer had bug, wants to reprocess
   // - Consumer was down during delivery
   // - Debugging integration issues
   ```

9. **Circuit Breaker for Failing Endpoints** (Provider)
   ```javascript
   // If endpoint fails repeatedly:
   // 1. Open circuit breaker
   // 2. Stop sending to that endpoint
   // 3. Queue events for later
   // 4. Notify consumer (email, dashboard)
   // 5. Periodically test endpoint
   // 6. Resume when healthy

   // Prevents:
   // - Wasting resources on dead endpoints
   // - Retry storms
   // - Cascade failures
   ```

10. **Reconciliation Jobs** (Consumer)
    ```javascript
    // Don't rely solely on webhooks
    // Periodic sync catches:
    // - Missed webhooks
    // - Processing bugs
    // - Out-of-order events

    // Daily job:
    async function reconcile() {
      const localOrders = await db.getOrdersSince(yesterday);
      const remoteOrders = await api.getOrdersSince(yesterday);

      const missing = remoteOrders.filter(r =>
        !localOrders.find(l => l.id === r.id)
      );

      for (const order of missing) {
        await processOrder(order);  // Backfill missed events
      }
    }
    ```

11. **Verification Challenge on Registration** (Provider)
    ```javascript
    // Verify URL ownership before accepting webhook registration

    // Step 1: Provider sends challenge to URL
    POST https://customer.com/webhook
    Content-Type: application/json
    {
      "type": "webhook.verification",
      "challenge": "ch_abc123xyz789"
    }

    // Step 2: Consumer must echo challenge in response
    HTTP/1.1 200 OK
    Content-Type: application/json
    {
      "challenge": "ch_abc123xyz789"
    }

    // Step 3: Provider only accepts registration if challenge matches
    // This proves consumer controls the URL

    // Benefits:
    // - Prevents registering URLs you don't control
    // - Confirms endpoint is reachable
    // - Validates consumer can handle webhook format
    ```

12. **Schema Validation** (Consumer)
    ```javascript
    // Validate incoming payloads before processing

    const Joi = require('joi');  // or zod, yup, ajv

    const webhookSchema = Joi.object({
      id: Joi.string().required(),
      type: Joi.string().pattern(/^[a-z]+\.[a-z_]+$/).required(),
      timestamp: Joi.isoDate().required(),
      data: Joi.object().required()
    });

    app.post('/webhook', async (req, res) => {
      // 1. Verify signature first
      if (!verifySignature(req)) {
        return res.status(401).send('Invalid signature');
      }

      // 2. Validate schema
      const { error, value } = webhookSchema.validate(req.body);
      if (error) {
        console.error('Invalid webhook payload:', error.message);
        return res.status(400).send('Invalid payload');
      }

      // 3. Process valid payload
      await queue.add(value);
      res.sendStatus(200);
    });

    // Benefits:
    // - Rejects malformed payloads early
    // - Documents expected format
    // - Prevents injection attacks
    // - Makes debugging easier
    ```

### GUIDANCE (not mechanically checked)

1. **Event Type Naming Convention**
   ```
   Format: resource.action (noun.verb)

   GOOD:
   - user.created
   - order.completed
   - payment.failed
   - subscription.renewed
   - invoice.payment_succeeded

   BAD:
   - createUser (verb first)
   - PAYMENT_FAILED (screaming case)
   - UserWasCreated (past tense, PascalCase)
   - user-created (hyphens)
   ```

2. **Payload Structure**
   ```javascript
   // Recommended envelope
   {
     "id": "evt_abc123",              // Event ID
     "type": "order.completed",       // Event type
     "api_version": "2024-01-15",     // Schema version
     "created": "2024-01-15T10:30:00Z", // When event occurred
     "data": {                        // Event-specific data
       "object": {                    // The resource that changed
         "id": "ord_xyz789",
         "status": "completed",
         ...
       }
     }
   }

   // Headers
   X-Webhook-ID: whk_abc123          // Unique delivery ID
   X-Webhook-Timestamp: 1705315800   // Unix timestamp
   X-Webhook-Signature: v1=abc123... // HMAC signature
   Content-Type: application/json
   ```

3. **Consumer Architecture**
   ```
   Webhook Request
        │
        ▼
   ┌─────────────┐
   │  Receiver   │  ← Verify signature, reject invalid
   │  (HTTP)     │  ← Check timestamp freshness
   │             │  ← Check idempotency key
   └─────┬───────┘  ← Return 200 immediately
         │
         ▼
   ┌─────────────┐
   │   Queue     │  ← Persist before ACK
   │  (Redis/    │  ← Survives restarts
   │   SQS/etc)  │
   └─────┬───────┘
         │
         ▼
   ┌─────────────┐
   │   Worker    │  ← Process asynchronously
   │             │  ← Retry on failure
   │             │  ← Dead letter on exhaust
   └─────────────┘
   ```

4. **Provider Architecture**
   ```
   Event Occurs
        │
        ▼
   ┌─────────────┐
   │  Event Bus  │  ← Dispatch to webhook system
   │             │
   └─────┬───────┘
         │
         ▼
   ┌─────────────┐
   │  Delivery   │  ← Look up registered endpoints
   │   Queue     │  ← Per-customer isolation
   │             │  ← Priority queues
   └─────┬───────┘
         │
         ▼
   ┌─────────────┐
   │   Sender    │  ← Sign payload
   │             │  ← POST to endpoint
   │             │  ← Handle response
   └─────┬───────┘
         │
    ┌────┴────┐
    │         │
   2xx      4xx/5xx/timeout
    │         │
   Done    ┌──┴───┐
           │Retry │ ← Exponential backoff
           │Queue │ ← Max attempts
           └──┬───┘
              │
         Exhausted
              │
              ▼
         ┌────────┐
         │  DLQ   │
         └────────┘
   ```

---

## Patterns

### Signature Verification (Standard Webhooks Spec)
```javascript
// Header format: t=timestamp,v1=signature
const header = req.headers['x-webhook-signature'];
const [tPart, vPart] = header.split(',');
const timestamp = tPart.split('=')[1];
const signature = vPart.split('=')[1];

// Verify timestamp freshness
const age = Math.floor(Date.now() / 1000) - parseInt(timestamp);
if (age > 300) throw new Error('Timestamp too old');

// Verify signature
const signedPayload = `${timestamp}.${JSON.stringify(req.body)}`;
const expected = crypto
  .createHmac('sha256', secret)
  .update(signedPayload)
  .digest('hex');

if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
  throw new Error('Invalid signature');
}
```

### Response Code Handling (Provider)
```
2xx Success:
  200 OK         → Delivered, stop retrying
  202 Accepted   → Delivered, stop retrying

4xx Client Error:
  400 Bad Request → May retry (could be transient)
  401 Unauthorized → Stop retrying, alert consumer (bad secret)
  404 Not Found   → Stop retrying, alert consumer (endpoint removed)
  410 Gone        → Stop retrying, disable webhook

5xx Server Error:
  500-504        → Retry with backoff

Timeout:
  No response    → Retry with backoff
```

### Retry Schedule Examples
```
Stripe:
  Up to 3 days, with exponential backoff

GitHub:
  Immediate, then give up (no automatic retry)
  
Shopify:
  19 retries over 48 hours

Standard approach:
  5s → 25s → 125s → 625s → 3125s...
  Cap at ~10 attempts over ~61 hours
```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| No signature | Accept any POST as valid webhook | HMAC verification |
| Sync processing | Block until processing complete | Queue + async worker |
| No idempotency | Duplicate webhooks = duplicate effects | Delivery ID dedup |
| == for signatures | Timing attack vulnerability | timingSafeEqual |
| Secrets in payload | Sensitive data exposed in transit | IDs only, fetch via API |
| No retry | Single attempt, silent failure | Exponential backoff |
| Infinite retry | Hammer failing endpoints forever | Max attempts + DLQ |
| No timestamp | Replay attacks possible | Timestamp + freshness check |
| No delivery ID | Can't dedupe or debug | Unique ID per delivery |
| Plain HTTP | Payload visible to attackers | HTTPS only |
| Large payloads | Slow, timeout-prone | <20KB, use references |
| No DLQ | Lost events after max retries | Dead letter queue |
| No reconciliation | Missed events stay missed | Periodic sync job |
| No URL validation | SSRF attacks via webhook URLs | Validate + block private IPs |
| Accept any URL | Internal services exposed | HTTPS only, DNS resolution check |
| No schema validation | Malformed payloads processed | Joi/Zod schema validation |
| No verification | URLs registered without proof of ownership | Challenge/response on registration |

---

## Research Sources

- [Standard Webhooks Spec](https://github.com/standard-webhooks/standard-webhooks)
- [Stripe Webhook Best Practices](https://stripe.com/docs/webhooks/best-practices)
- [GitHub Webhook Documentation](https://docs.github.com/en/webhooks)
- [Svix Webhook Security](https://docs.svix.com/security)
- [Svix Webhook Resources](https://www.svix.com/resources/)
- [webhooks.fyi](https://webhooks.fyi/)
- [OWASP SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Convoy - Tackling SSRF](https://www.getconvoy.io/docs/webhook-guides/tackling-ssrf)
- [Smokescreen Egress Proxy](https://github.com/stripe/smokescreen)
