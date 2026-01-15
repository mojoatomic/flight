# Domain: Webhooks Design

Outbound event notification design. Covers both webhook providers (sending) and consumers (receiving). Prevents integration failures, data loss, and security breaches.


**Validation:** `webhooks.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Plain HTTP Webhook URLs** - All webhook traffic must be encrypted. Plain HTTP exposes payloads to attackers via MITM attacks.

   ```
   // BAD
   http://api.customer.com/webhooks
   // BAD
   const url = "http://example.com/hook";

   // GOOD
   https://api.customer.com/webhooks
   // GOOD
   const url = "https://example.com/hook";
   ```

2. **Secrets in Webhook Payloads** - Never include secrets, passwords, API keys, SSNs, or credit card numbers in webhook payloads. Payloads may be logged or intercepted.

   ```
   // BAD
   { "event": "user.created", "data": { "api_key": "sk_live_abc123" } }
   // BAD
   { "payload": { "password": "hunter2" } }

   // GOOD
   { "event": "user.created", "data": { "user_id": "usr_abc123" } }
   ```

3. **Unsafe Signature Comparison** - Never use === or == for signature comparison. String comparison is vulnerable to timing attacks that reveal the signature byte-by-byte.

   ```
   // BAD
   if (signature === expected) { ... }
   // BAD
   if (signature == computedSignature) { ... }
   // BAD
   signature.equals(expected)

   // GOOD
   crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
   ```

4. **Infinite Retry Without Backoff** - Never retry webhook delivery in an infinite loop without backoff. This hammers failing endpoints and wastes resources.

   ```
   // BAD
   while (true) { await sendWebhook(url, payload); }
   // BAD
   while (retry) { webhook.send(); }

   // GOOD
   // Retry at: 5s, 25s, 125s... with max 10 attempts
   // GOOD
   const delay = Math.min(BASE * Math.pow(MULT, attempt) + jitter(), MAX);
   ```

5. **Non-HTTPS URL Schemes** - Never allow file://, ftp://, gopher://, or other non-HTTPS schemes in webhook URLs. These enable SSRF attacks.

   ```
   // BAD
   webhook.url = 'file:///etc/passwd'
   // BAD
   endpoint = 'ftp://internal/data'

   // GOOD
   webhook.url = 'https://api.customer.com/hooks'
   ```

### SHOULD (validator warns)

1. **Signature Verification Present** - Webhook handlers should verify HMAC signatures before processing. Without verification, any request claiming to be a webhook will be accepted.

   ```
   // BAD
   app.post('/webhook', (req, res) => {
     processEvent(req.body);  // No verification!
     res.sendStatus(200);
   });
   

   // GOOD
   app.post('/webhook', (req, res) => {
     const signature = req.headers['x-webhook-signature'];
     const expected = hmac('sha256', SECRET, JSON.stringify(req.body));
     if (!timingSafeEqual(signature, expected)) {
       return res.sendStatus(401);
     }
     processEvent(req.body);
   });
   
   ```

2. **Async Processing** - Webhook handlers should enqueue work for async processing rather than blocking. Synchronous processing causes provider timeouts and retries.

   ```
   // BAD
   app.post('/webhook', async (req, res) => {
     await processPayment(req.body);  // Takes 30 seconds
     res.sendStatus(200);  // Too late, provider already retried
   });
   

   // GOOD
   app.post('/webhook', async (req, res) => {
     await queue.add('process-webhook', req.body);
     res.sendStatus(200);  // ACK within seconds
   });
   
   ```

3. **Idempotency Handling** - Webhook handlers should use delivery IDs to deduplicate. Webhooks are delivered at-least-once, so duplicates will occur.

   ```
   // BAD
   app.post('/webhook', (req, res) => {
     chargeCustomer(req.body.amount);  // Called twice = charged twice
     res.sendStatus(200);
   });
   

   // GOOD
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

4. **URL/IP Validation for SSRF Prevention** - Webhook URL registration should validate URLs and block private IPs to prevent SSRF attacks targeting internal services.

   ```
   // BAD
   app.post('/webhooks', (req, res) => {
     await db.saveWebhook({ url: req.body.url });  // Could be internal!
   });
   

   // GOOD
   const validation = await isValidWebhookUrl(req.body.url);
   if (!validation.valid) {
     return res.status(400).json({ error: validation.reason });
   }
   
   ```

5. **Event Type Handling** - Webhook handlers should check and route by event type. Event types enable proper handling of different webhook events.

   ```
   switch (event.type) {
     case 'order.completed': handleOrderCompleted(event.data); break;
     case 'payment.failed': handlePaymentFailed(event.data); break;
   }
   ```

6. **Timestamp Handling** - Webhook handlers should check timestamps for replay attack prevention and out-of-order detection.

   ```
   const age = (Date.now() / 1000) - parseInt(timestamp);
   if (age > MAX_AGE_SECONDS) {
     return res.status(400).json({ error: 'Timestamp too old' });
   }
   ```

7. **HMAC Signature Implementation** - Webhook providers should sign payloads with HMAC to enable consumer verification.


8. **Proper Response Codes** - Webhook handlers should return 2xx within the timeout window. Providers interpret response codes to determine retry behavior.


9. **Retry with Backoff Logic** - Webhook providers should implement exponential backoff with maximum retry limits.


10. **Dead Letter Queue Handling** - Failed webhooks should be routed to a dead letter queue after exhausting retries for manual inspection and replay.


11. **Webhook URL Validation on Registration** - Webhook providers should validate URLs before accepting registration.


12. **Payload Size Limits** - Webhooks should keep payloads small (<20KB). Large payloads are slow and timeout-prone. Send references instead.


13. **Webhook Logging** - Webhook handlers should log activity for debugging and audit trails.


14. **Secret Rotation Support** - Webhook systems should support signing with multiple keys during secret rotation.


15. **Timing-Safe Comparison Used** - Use constant-time comparison functions for signature verification.


16. **Queue Integration** - Webhook handlers should integrate with a queue for async processing.


17. **Schema Validation** - Validate incoming webhook payloads against a schema before processing.


18. **Registration Verification Challenge** - Webhook providers should verify URL ownership via challenge/response during registration.


19. **Egress Proxy for Webhook Delivery** - Webhook providers should route delivery through an egress proxy for centralized security enforcement.


### GUIDANCE (not mechanically checked)

1. **Event Type Naming Convention** - Use resource.action (noun.verb) format for event types with dot-delimited hierarchy.


2. **Payload Structure** - Standard webhook payload envelope with event ID, type, version, timestamp, and data object.


3. **Consumer Architecture** - Recommended architecture for webhook consumers with queue-based async processing.


4. **Provider Architecture** - Recommended architecture for webhook providers with retry and DLQ.


5. **Signature Verification Pattern** - Standard Webhooks Spec signature verification pattern.


6. **Response Code Handling** - How providers should interpret consumer response codes.


7. **Retry Schedule** - Recommended retry schedule with exponential backoff.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| No signature verification |  | HMAC verification |
| Sync processing |  | Queue + async worker |
| No idempotency |  | Delivery ID dedup |
| == for signatures |  | timingSafeEqual |
| Secrets in payload |  | IDs only, fetch via API |
| No retry |  | Exponential backoff |
| Infinite retry |  | Max attempts + DLQ |
| Plain HTTP |  | HTTPS only |
| No URL validation |  | Validate + block private IPs |
