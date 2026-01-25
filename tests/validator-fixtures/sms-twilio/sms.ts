// Twilio SMS with violations
import twilio from 'twilio';

// N1: Hardcoded credentials (use env vars instead)
const accountSid = 'REPLACE_WITH_ENV_VAR';
const authToken = 'REPLACE_WITH_ENV_VAR';

// N2: No rate limiting
async function sendSMS(to: string, body: string) {
  const client = twilio(accountSid, authToken);
  await client.messages.create({
    to,
    from: '+15555555555',
    body
  });
}

// N3: No input validation on phone number
async function badSend(userPhone: string) {
  await sendSMS(userPhone, 'Hello');
}
