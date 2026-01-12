# SMS Consent & Flow Control Domain (Twilio)

A comprehensive reference for SMS consent management, opt-in/opt-out handling, and error code interpretation when using Twilio.

**Label Key:**
- **(REQUIRED)** - Must implement exactly as shown
- **(INVARIANT)** - Must satisfy, implementation may vary
- **(EXAMPLE)** - Suggested approach, not required
- **(REFERENCE)** - For context/understanding, not implementation

## Defaults (REFERENCE)

```yaml
sms:
  provider: twilio
  country: US
  consent_type: double_opt_in    # single_opt_in, double_opt_in, transactional
  number_type: 10dlc             # 10dlc, toll_free, short_code
```

---

## Consent State Machine (REQUIRED)

### States

```
┌─────────────┐
│   UNKNOWN   │  No record of this number
└──────┬──────┘
       │ User provides number
       ▼
┌─────────────┐
│   PENDING   │  Awaiting consent confirmation
└──────┬──────┘
       │ User confirms (replies YES, clicks link, etc.)
       ▼
┌─────────────┐
│  OPTED_IN   │  Can send messages
└──────┬──────┘
       │ User sends STOP (or carrier blocks)
       ▼
┌─────────────┐
│  OPTED_OUT  │  CANNOT send messages
└──────┬──────┘
       │ User sends START/UNSTOP
       ▼
┌─────────────┐
│  OPTED_IN   │  Can send messages again
└─────────────┘
```

### State Transitions (INVARIANT)

| From | To | Trigger | Notes |
|------|------|---------|-------|
| UNKNOWN | PENDING | User submits phone number | Start consent flow |
| PENDING | OPTED_IN | User confirms consent | Double opt-in complete |
| PENDING | UNKNOWN | Timeout (24-72 hours) | Clean up stale pending |
| OPTED_IN | OPTED_OUT | User sends opt-out keyword | Immediate, no delay |
| OPTED_IN | OPTED_OUT | Error 21610 from Twilio | Carrier-level block |
| OPTED_OUT | OPTED_IN | User sends opt-in keyword | Re-subscribe |

**Critical Rule (INVARIANT):** NEVER send to OPTED_OUT or UNKNOWN. Only OPTED_IN receives messages.

---

## Opt-Out Keywords (REFERENCE)

Twilio automatically processes these keywords and blocks the number. Your webhook receives them with `OptOutType` parameter.

### Required (Cannot Remove)
- `STOP` - Primary opt-out
- `START` - Primary opt-in (re-subscribe)
- `UNSTOP` - Re-subscribe (Toll-Free specific)
- `HELP` - Help request

### Standard Opt-Out (Active by Default)
- `STOPALL`
- `UNSUBSCRIBE`
- `CANCEL`
- `END`
- `QUIT`

### FCC-Mandated (Added April 2025)
- `REVOKE`
- `OPTOUT` (no space)

### French Language Support
- `ARRET`
- `ARRÊT`
- `ARRETE`

### Notes
- Case insensitive: "stop" = "STOP" = "Stop"
- Twilio adds number to block list automatically
- Subsequent sends fail with Error 21610
- Cannot override STOP, START, HELP - they're reserved

---

## Opt-In Keywords

### Standard Opt-In
- `START` - Re-subscribe after opt-out
- `UNSTOP` - Re-subscribe (required for Toll-Free)
- `YES` - Confirmation (does NOT re-subscribe opted-out users on Toll-Free)

### Custom Keywords (Configure in Twilio Console)
You can add custom opt-in keywords via Advanced Opt-Out settings.

---

## Required Messages

### First Message (Invariant)

The FIRST message to a newly opted-in user MUST include:

```
[Business Name]: [Message content]. Reply STOP to unsubscribe.
```

**Requirements:**
- Business/brand identifier
- Opt-out instructions
- Message frequency disclosure (for marketing)

**Example:**
```
Acme Co: Your verification code is 123456. 
Reply STOP to opt out. Msg & data rates may apply.
```

### Opt-Out Confirmation

When user opts out, send ONE final message:

```
You have been unsubscribed and will not receive further messages. Reply START to resubscribe.
```

**Rules:**
- Only ONE message allowed after opt-out
- Must confirm the opt-out processed
- Should include re-subscribe instructions
- No further messages after this

### HELP Response

When user sends HELP:

```
[Business Name]: For support, visit [URL] or call [phone]. 
Reply STOP to unsubscribe. Msg & data rates may apply.
```

**Requirements:**
- Business identifier
- Support contact info
- Opt-out reminder

---

## Double Opt-In Flow

```
1. User provides phone number (web form, verbal, etc.)
   → State: PENDING
   
2. Send consent request:
   "{BusinessName}: Reply YES to receive messages from us. 
    Msg & data rates may apply. Reply STOP to cancel."
   → Wait for response
   
3a. User replies YES:
    → State: OPTED_IN
    → Send confirmation: "You're confirmed! You'll receive messages 
       from {BusinessName}. Reply STOP anytime to unsubscribe."
    
3b. User replies STOP or no response in 72 hours:
    → State: UNKNOWN (clean up)
    → No further messages
```

### Developer Config Points

```javascript
// messages.js - Configure these for your application
const SMS_MESSAGES = {
  // Double opt-in request
  CONSENT_REQUEST: 
    '{businessName}: Reply YES to receive {messageType} via SMS. ' +
    'Msg & data rates may apply. Reply STOP to cancel.',
  
  // Consent confirmed
  CONSENT_CONFIRMED: 
    "You're confirmed! You'll receive {messageType} from {businessName}. " +
    'Reply STOP anytime to unsubscribe.',
  
  // Opt-out confirmation  
  OPT_OUT_CONFIRMED:
    'You have been unsubscribed and will not receive further messages from {businessName}. ' +
    'Reply START to resubscribe.',
  
  // Help response
  HELP_RESPONSE:
    '{businessName}: For support, visit {supportUrl} or call {supportPhone}. ' +
    'Reply STOP to unsubscribe. Msg & data rates may apply.',
  
  // Generic transactional message
  TRANSACTIONAL:
    '{businessName}: {message}',
    
  // Consent request timeout
  CONSENT_TIMEOUT_HOURS: 72,
};

// Example messageType values:
// - "appointment reminders"
// - "order updates" 
// - "verification codes"
// - "account alerts"
// - "promotional offers" (requires express written consent)
```

---

## Twilio Error Codes & Actions (REQUIRED)

### Consent/Opt-Out Errors

| Code | Meaning | Action | Retryable |
|------|---------|--------|-----------|
| **21610** | Unsubscribed recipient | Mark OPTED_OUT, do not retry | No |
| **30004** | Message blocked (carrier) | Mark OPTED_OUT, do not retry | No |

**INVARIANT:** On 21610 or 30004, immediately update consent state to OPTED_OUT. Do NOT retry.

### Delivery Errors (Temporary)

| Code | Meaning | Action | Retryable |
|------|---------|--------|-----------|
| **30003** | Unreachable handset | Retry with backoff (phone off, no signal) | Yes (3x) |
| **30017** | Carrier network congestion | Retry with backoff | Yes (3x) |

**Retry Strategy (EXAMPLE):**
```javascript
// Retry for temporary errors only
const RETRY_CONFIG = {
  maxAttempts: 3,
  backoffMs: [60000, 300000, 900000], // 1min, 5min, 15min
  retryableCodes: [30003, 30017],
};
```

### Permanent Delivery Failures

| Code | Meaning | Action | Retryable |
|------|---------|--------|-----------|
| **30005** | Unknown destination | Mark number INVALID, alert user | No |
| **30006** | Landline or unreachable carrier | Mark number INVALID (landline) | No |
| **30007** | Message filtered (spam) | Review message content, alert admin | No |

**INVARIANT:** On 30005 or 30006, mark number as invalid (not a mobile). Do NOT retry.

### Account/Configuration Errors

| Code | Meaning | Action | Retryable |
|------|---------|--------|-----------|
| **30001** | Queue overflow | Slow down send rate | Yes (after delay) |
| **30002** | Account suspended | STOP ALL SENDS, alert admin | No |
| **21611** | Queue limit exceeded | Slow down, wait for queue | Yes (after delay) |

### A2P 10DLC Specific

| Code | Meaning | Action | Retryable |
|------|---------|--------|-----------|
| **30022** | 10DLC rate limit exceeded | Slow down | Yes (after delay) |
| **30023** | 10DLC daily cap reached | Wait until next day | No (until reset) |
| **30027** | T-Mobile daily limit reached | Wait until next day | No (until reset) |
| **30032** | Toll-Free not verified | Complete TF verification | No |
| **30033** | Campaign suspended | Contact Twilio support | No |
| **30034** | Unregistered 10DLC number | Register for A2P 10DLC | No |

---

## Error Handling Code Pattern

```typescript
// types/sms.ts
type ConsentState = 'UNKNOWN' | 'PENDING' | 'OPTED_IN' | 'OPTED_OUT';
type NumberStatus = 'VALID' | 'INVALID' | 'LANDLINE';

interface SMSResult {
  success: boolean;
  messageId?: string;
  errorCode?: number;
  action: 'sent' | 'retry' | 'opt_out' | 'invalid_number' | 'alert_admin' | 'rate_limit';
}

// Handle Twilio webhook/response
function handleTwilioError(errorCode: number): SMSResult['action'] {
  // Consent errors - mark opted out, never retry
  if (errorCode === 21610 || errorCode === 30004) {
    return 'opt_out';
  }
  
  // Invalid number - mark invalid, never retry
  if (errorCode === 30005 || errorCode === 30006) {
    return 'invalid_number';
  }
  
  // Temporary - retry with backoff
  if (errorCode === 30003 || errorCode === 30017) {
    return 'retry';
  }
  
  // Rate limits - slow down
  if ([30001, 30022, 30023, 30027, 21611].includes(errorCode)) {
    return 'rate_limit';
  }
  
  // Account/config issues - alert human
  if ([30002, 30007, 30032, 30033, 30034].includes(errorCode)) {
    return 'alert_admin';
  }
  
  // Unknown error - log and alert
  return 'alert_admin';
}
```

---

## Webhook Handling

### Inbound Message Webhook

Twilio POSTs to your webhook with these fields for opt-in/out:

```typescript
interface TwilioInboundWebhook {
  From: string;          // User's phone number
  To: string;            // Your Twilio number
  Body: string;          // Message text
  OptOutType?: 'STOP' | 'HELP' | 'START';  // Only with Advanced Opt-Out enabled
  MessageSid: string;
}

// Handle inbound
function handleInbound(webhook: TwilioInboundWebhook) {
  const body = webhook.Body.trim().toUpperCase();
  
  // Check OptOutType if available (Advanced Opt-Out)
  if (webhook.OptOutType === 'STOP') {
    return updateConsentState(webhook.From, 'OPTED_OUT');
  }
  if (webhook.OptOutType === 'START') {
    return updateConsentState(webhook.From, 'OPTED_IN');
  }
  
  // Fallback: Check body manually
  const OPT_OUT_KEYWORDS = ['STOP', 'STOPALL', 'UNSUBSCRIBE', 'CANCEL', 'END', 'QUIT', 'REVOKE', 'OPTOUT'];
  const OPT_IN_KEYWORDS = ['START', 'UNSTOP'];
  const HELP_KEYWORDS = ['HELP', 'INFO'];
  
  if (OPT_OUT_KEYWORDS.includes(body)) {
    return updateConsentState(webhook.From, 'OPTED_OUT');
  }
  if (OPT_IN_KEYWORDS.includes(body)) {
    return updateConsentState(webhook.From, 'OPTED_IN');
  }
  if (HELP_KEYWORDS.includes(body)) {
    return sendHelpResponse(webhook.From);
  }
  
  // Regular inbound message - handle normally
  return handleRegularInbound(webhook);
}
```

### Status Callback Webhook

```typescript
interface TwilioStatusCallback {
  MessageSid: string;
  MessageStatus: 'queued' | 'sent' | 'delivered' | 'undelivered' | 'failed';
  ErrorCode?: number;
  To: string;
}

function handleStatusCallback(webhook: TwilioStatusCallback) {
  if (webhook.MessageStatus === 'delivered') {
    return markDelivered(webhook.MessageSid);
  }
  
  if (webhook.MessageStatus === 'failed' || webhook.MessageStatus === 'undelivered') {
    const action = handleTwilioError(webhook.ErrorCode);
    
    switch (action) {
      case 'opt_out':
        return updateConsentState(webhook.To, 'OPTED_OUT');
      case 'invalid_number':
        return markNumberInvalid(webhook.To);
      case 'retry':
        return scheduleRetry(webhook.MessageSid);
      case 'rate_limit':
        return pauseAndRetry(webhook.MessageSid);
      case 'alert_admin':
        return alertAdmin(webhook);
    }
  }
}
```

---

## Database Schema (EXAMPLE - Reference Only)

This is ONE possible approach for persistent storage. For simple implementations, in-memory Map is acceptable.

If you use this schema, you will need a database driver (not in the javascript.md COMPLETE dependency list).

```sql
-- Consent tracking
CREATE TABLE sms_consent (
  phone_number VARCHAR(20) PRIMARY KEY,  -- E.164 format: +1XXXXXXXXXX
  consent_state VARCHAR(20) NOT NULL DEFAULT 'UNKNOWN',
  number_status VARCHAR(20) NOT NULL DEFAULT 'VALID',
  opted_in_at TIMESTAMP,
  opted_out_at TIMESTAMP,
  last_message_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT valid_state CHECK (consent_state IN ('UNKNOWN', 'PENDING', 'OPTED_IN', 'OPTED_OUT')),
  CONSTRAINT valid_status CHECK (number_status IN ('VALID', 'INVALID', 'LANDLINE'))
);

-- Message log (for compliance/audit)
CREATE TABLE sms_log (
  id SERIAL PRIMARY KEY,
  message_sid VARCHAR(50) UNIQUE,
  phone_number VARCHAR(20) NOT NULL,
  direction VARCHAR(10) NOT NULL,  -- 'inbound' or 'outbound'
  body_hash VARCHAR(64),           -- SHA256 of body (don't store PII)
  status VARCHAR(20),
  error_code INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT valid_direction CHECK (direction IN ('inbound', 'outbound'))
);

-- Index for lookups
CREATE INDEX idx_sms_consent_state ON sms_consent(consent_state);
CREATE INDEX idx_sms_log_phone ON sms_log(phone_number);
```

---

## Compliance Checklist (REQUIRED)

### Before Sending ANY Message

- [ ] User consent state is OPTED_IN
- [ ] Number status is VALID (not INVALID or LANDLINE)
- [ ] First message includes business name and opt-out instructions
- [ ] Message content complies with A2P 10DLC campaign type

### For Double Opt-In

- [ ] Consent request sent with clear YES/STOP options
- [ ] Timeout configured (24-72 hours)
- [ ] Confirmation sent after YES received
- [ ] PENDING records cleaned up after timeout

### For Opt-Out Handling

- [ ] STOP processed immediately (Twilio handles automatically)
- [ ] Consent state updated to OPTED_OUT
- [ ] One confirmation message sent
- [ ] No further messages attempted
- [ ] 21610/30004 errors trigger opt-out state update

### For A2P 10DLC (US)

- [ ] Brand registered with The Campaign Registry
- [ ] Campaign registered with use case
- [ ] Phone numbers associated with campaign
- [ ] Sending within rate limits
- [ ] Daily caps respected (especially T-Mobile)

---

## Rate Limits (A2P 10DLC)

| Brand Type | Messages/Second | Daily Limit (T-Mobile) |
|------------|-----------------|------------------------|
| Low Volume | 0.2 (1 per 5 sec) | 500-2,000 |
| Standard | 3-15 | 2,000-200,000 |
| High Trust | 15-60+ | Higher |

**Rule:** Start conservative, monitor 30022/30023/30027 errors, adjust.

---

## Forbidden Patterns

```typescript
// NEVER do these:

// ❌ Send without checking consent
await sendSMS(phoneNumber, message); // WRONG

// ✅ Always check first
const consent = await getConsentState(phoneNumber);
if (consent.state !== 'OPTED_IN') {
  throw new Error('Cannot send to non-opted-in user');
}
await sendSMS(phoneNumber, message);

// ❌ Retry on opt-out error
if (errorCode === 21610) {
  await retry(message); // WRONG - they opted out!
}

// ✅ Mark opted out, stop
if (errorCode === 21610 || errorCode === 30004) {
  await updateConsentState(phoneNumber, 'OPTED_OUT');
  // No retry
}

// ❌ Ignore STOP keyword
if (body === 'STOP') {
  // do nothing // WRONG - legal violation!
}

// ✅ Process immediately (Twilio does this, but verify in your DB)
if (body === 'STOP') {
  await updateConsentState(from, 'OPTED_OUT');
  await sendOptOutConfirmation(from);
}

// ❌ Send marketing without disclosure
await sendSMS(phone, 'Sale! 50% off!'); // WRONG - missing business name, opt-out

// ✅ Include required elements
await sendSMS(phone, 'Acme Co: Sale! 50% off today! Reply STOP to unsubscribe.');
```

---

## Testing Checklist

### Unit Tests

- [ ] Opt-out keywords trigger state change
- [ ] Opt-in keywords trigger state change (from OPTED_OUT)
- [ ] Error code 21610 → OPTED_OUT
- [ ] Error code 30004 → OPTED_OUT
- [ ] Error code 30005 → INVALID number
- [ ] Error code 30006 → LANDLINE
- [ ] Error code 30003 → retry scheduled
- [ ] Cannot send to non-OPTED_IN state

### Integration Tests

- [ ] Double opt-in flow completes
- [ ] STOP → confirmation → no more messages
- [ ] START → re-subscribes
- [ ] HELP → help message received
- [ ] Rate limiting respected

### Compliance Audit

- [ ] All outbound messages logged
- [ ] Consent timestamps recorded
- [ ] Opt-out processed within seconds
- [ ] First message has required disclosures

---

## References

- [Twilio Messaging Policy](https://www.twilio.com/en-us/legal/messaging-policy)
- [Twilio Advanced Opt-Out](https://www.twilio.com/docs/messaging/tutorials/advanced-opt-out)
- [Twilio Error Codes](https://www.twilio.com/docs/api/errors)
- [A2P 10DLC Overview](https://www.twilio.com/docs/messaging/compliance/a2p-10dlc)
- [CTIA Messaging Principles](https://www.ctia.org/the-wireless-industry/industry-commitments/messaging-principles-and-best-practices)
