# Domain: Sms-Twilio Design

SMS consent management, opt-in/opt-out handling, and Twilio error code interpretation. Compliance-focused domain for TCPA, CTIA, and A2P 10DLC requirements.


**Validation:** `sms-twilio.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Consent States Defined** - SMS consent states (OPTED_IN, OPTED_OUT, PENDING, UNKNOWN) must be defined in code. These states drive the consent state machine.

   ```
   // BAD
   // No consent states defined

   // GOOD
   type ConsentState = 'UNKNOWN' | 'PENDING' | 'OPTED_IN' | 'OPTED_OUT';
   ```

2. **Never Send to OPTED_OUT or UNKNOWN** - INVARIANT: Never send messages to users in OPTED_OUT or UNKNOWN state. Only OPTED_IN users can receive messages. Violating this is a legal compliance issue (TCPA).

   ```
   // BAD
   if (state === 'OPTED_OUT') sendSMS(phone, msg);
   // BAD
   sendSMS(phone, msg); // user is UNKNOWN

   // GOOD
   if (consent.state !== 'OPTED_IN') {
     throw new Error('Cannot send to non-opted-in user');
   }
   await sendSMS(phone, msg);
   
   ```

3. **Consent Check Before Sending** - Always check consent state before sending any SMS. Sending without checking consent violates TCPA and carrier policies.

   ```
   // BAD
   await sendSMS(phoneNumber, message); // WRONG - no consent check

   // GOOD
   const consent = await getConsentState(phoneNumber);
   if (consent.state !== 'OPTED_IN') {
     throw new Error('Cannot send to non-opted-in user');
   }
   await sendSMS(phoneNumber, message);
   
   ```

4. **STOP Keyword Triggers State Change** - STOP keyword must trigger a state change to OPTED_OUT. Ignoring STOP is a legal violation. Twilio handles this automatically but your database must also be updated.

   ```
   // BAD
   if (body === 'STOP') {
     // do nothing // WRONG - legal violation!
   }
   

   // GOOD
   if (body === 'STOP') {
     await updateConsentState(from, 'OPTED_OUT');
     await sendOptOutConfirmation(from);
   }
   
   ```

5. **Error 21610 Marks OPTED_OUT** - INVARIANT: Twilio error 21610 (unsubscribed recipient) must mark the user as OPTED_OUT. This is a carrier-level block. Do NOT retry.

   ```
   // BAD
   // No handling for error 21610

   // GOOD
   if (errorCode === 21610) {
     await updateConsentState(phoneNumber, 'OPTED_OUT');
     // No retry
   }
   
   ```

6. **Error 30004 Marks OPTED_OUT** - INVARIANT: Twilio error 30004 (message blocked by carrier) must mark the user as OPTED_OUT. This indicates carrier-level blocking. Do NOT retry.

   ```
   // BAD
   // No handling for error 30004

   // GOOD
   if (errorCode === 30004) {
     await updateConsentState(phoneNumber, 'OPTED_OUT');
     // No retry
   }
   
   ```

7. **No Retry on Opt-Out Errors** - INVARIANT: Never retry on opt-out errors (21610, 30004). The user has opted out - retrying violates their consent and carrier policies.

   ```
   // BAD
   if (errorCode === 21610) {
     await retry(message); // WRONG - they opted out!
   }
   

   // GOOD
   if (errorCode === 21610 || errorCode === 30004) {
     await updateConsentState(phoneNumber, 'OPTED_OUT');
     // No retry
   }
   
   ```

8. **Error 30005/30006 Marks Number INVALID** - INVARIANT: Twilio errors 30005 (unknown destination) and 30006 (landline/unreachable) must mark the number as INVALID. Do NOT retry.

   ```
   // BAD
   // No handling for invalid number errors

   // GOOD
   if (errorCode === 30005 || errorCode === 30006) {
     await markNumberInvalid(phoneNumber);
     // No retry
   }
   
   ```

9. **First Message Includes Opt-Out Instructions** - The first message to a newly opted-in user MUST include opt-out instructions (STOP keyword). This is required by CTIA guidelines.

   ```
   // BAD
   await sendSMS(phone, 'Sale! 50% off!'); // WRONG - missing opt-out

   // GOOD
   await sendSMS(phone, 'Acme Co: Sale! 50% off today! Reply STOP to unsubscribe.');
   ```

10. **No Hardcoded Phone Numbers** - Never hardcode phone numbers in source code. Use environment variables or configuration for phone numbers.

   ```
   // BAD
   const phone = "+15551234567";

   // GOOD
   const phone = process.env.SUPPORT_PHONE;
   ```

11. **No Hardcoded Twilio Credentials** - Never hardcode Twilio credentials (Account SID, Auth Token) in source code. Use environment variables.

   ```
   // BAD
   const ACCOUNT_SID = "AC1234567890abcdef1234567890abcdef12";
   // BAD
   const AUTH_TOKEN = "abcdef1234567890abcdef1234567890";

   // GOOD
   const ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
   // GOOD
   const AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
   ```

### SHOULD (validator warns)

1. **START/UNSTOP Keywords Handled** - START and UNSTOP keywords should be handled to allow users to re-subscribe after opting out. UNSTOP is required for Toll-Free.

   ```
   if (body === 'START' || body === 'UNSTOP') {
     await updateConsentState(from, 'OPTED_IN');
   }
   ```

2. **HELP Keyword Response** - HELP keyword should trigger a response with support contact information and opt-out reminder.

   ```
   const HELP_RESPONSE =
     '{businessName}: For support, visit {supportUrl} or call {supportPhone}. ' +
     'Reply STOP to unsubscribe.';
   ```

3. **Temporary Errors Retry with Backoff** - Temporary errors (30003 unreachable, 30017 congestion) should trigger retry with exponential backoff.

   ```
   const RETRY_CONFIG = {
     maxAttempts: 3,
     backoffMs: [60000, 300000, 900000], // 1min, 5min, 15min
     retryableCodes: [30003, 30017],
   };
   ```

4. **Rate Limit Errors Handled** - Rate limit errors (30022, 30023, 30027) should be handled by slowing down or waiting until the next day.

   ```
   if ([30022, 30023, 30027].includes(errorCode)) {
     return 'rate_limit'; // Slow down or wait
   }
   ```

5. **Business Name in Messages** - Messages should include business/brand name for identification as required by CTIA guidelines.

   ```
   '{businessName}: {message}. Reply STOP to unsubscribe.'
   ```

6. **Opt-Out Confirmation Message** - When a user opts out, send one final confirmation message. This is the only message allowed after opt-out.

   ```
   const OPT_OUT_CONFIRMED =
     'You have been unsubscribed and will not receive further messages. ' +
     'Reply START to resubscribe.';
   ```

7. **Double Opt-In Flow** - Implement double opt-in flow for marketing messages. User provides number, receives confirmation request, replies YES to confirm.

   ```
   // State: PENDING -> user replies YES -> State: OPTED_IN
   const CONSENT_REQUEST =
     '{businessName}: Reply YES to receive messages. Reply STOP to cancel.';
   ```

8. **Message Logging for Audit** - Log all messages for compliance audit. Store message SID, direction, status, and timestamp. Don't store message body (PII).

   ```
   CREATE TABLE sms_log (
     id SERIAL PRIMARY KEY,
     message_sid VARCHAR(50) UNIQUE,
     phone_number VARCHAR(20) NOT NULL,
     direction VARCHAR(10) NOT NULL,
     status VARCHAR(20),
     created_at TIMESTAMP DEFAULT NOW()
   );
   ```

9. **Consent Timestamps Tracked** - Track timestamps for consent changes (opted_in_at, opted_out_at) for compliance audit and legal requirements.

   ```
   CREATE TABLE sms_consent (
     phone_number VARCHAR(20) PRIMARY KEY,
     consent_state VARCHAR(20) NOT NULL,
     opted_in_at TIMESTAMP,
     opted_out_at TIMESTAMP
   );
   ```

### GUIDANCE (not mechanically checked)

1. **Consent State Machine** - Implement the consent state machine with proper state transitions.


2. **Opt-Out Keywords Reference** - Twilio automatically processes these keywords. Your webhook receives them with OptOutType parameter.


3. **Webhook Handling Pattern** - Handle Twilio inbound webhooks to process opt-in/out keywords and status callbacks to handle delivery errors.


4. **Error Code Action Reference** - Reference for Twilio error codes and required actions.


5. **Database Schema Example** - Example database schema for consent tracking and message logging.


6. **Required Message Templates** - Standard message templates for consent flow.


7. **A2P 10DLC Rate Limits** - Rate limits for A2P 10DLC messaging.


8. **Compliance Checklist** - Checklist for SMS compliance before going live.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Send without consent check |  | Always check OPTED_IN before sending |
| Retry on 21610/30004 |  | Mark OPTED_OUT, no retry |
| Ignore STOP keyword |  | Process immediately, update state |
| No opt-out in first message |  | Include 'Reply STOP to unsubscribe' |
| Hardcoded credentials |  | Use environment variables |
| No error code handling |  | Handle all Twilio error codes |
| No consent timestamps |  | Track opted_in_at, opted_out_at |
| Retry temporary errors forever |  | Max 3 retries with backoff |
