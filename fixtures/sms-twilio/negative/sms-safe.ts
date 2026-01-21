// SMS Twilio test fixture - Should NOT trigger violations
// Safe patterns using environment variables

// GOOD: Phone numbers from environment variables
const supportPhone = process.env.SUPPORT_PHONE!;
const alertPhone = process.env.ALERT_PHONE!;

// GOOD: Twilio credentials from environment variables
const ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID!;
const AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN!;

// GOOD: Comments mentioning patterns should not trigger
// Don't hardcode phone numbers or Twilio credentials!

// GOOD: Documentation strings should not trigger
const WARNING = "Never hardcode +15551234567 or Twilio credentials";

// GOOD: Partial patterns that don't match the full regex
const shortSid = 'AC123';  // Too short, not a full SID
const partialPhone = '+1555';  // Not a full phone number

// GOOD: Consent states (not credentials)
type ConsentState = 'UNKNOWN' | 'PENDING' | 'OPTED_IN' | 'OPTED_OUT';

export { supportPhone, alertPhone, ACCOUNT_SID, AUTH_TOKEN };
