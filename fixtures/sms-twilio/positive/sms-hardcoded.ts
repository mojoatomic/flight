// SMS Twilio test fixture - SHOULD trigger N10 and N11 violations
// Hardcoded phone numbers and Twilio credentials

// BAD: Hardcoded US phone numbers (N10)
const supportPhone = '+15551234567';
const alertPhone = '+12025551234';
const testPhone = '+19175559876';

// BAD: Hardcoded Twilio Account SID (N11)
// Note: Using XXXX pattern to avoid GitHub secret scanning on test fixtures
const ACCOUNT_SID = 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';

// BAD: Hardcoded Twilio Auth Token (N11)
// Note: Real pattern would be 32 hex chars, using X's for test fixture
const AUTH_TOKEN = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';

// BAD: Another hardcoded SID pattern
const twilioSid = 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';

export { supportPhone, alertPhone, testPhone, ACCOUNT_SID, AUTH_TOKEN, twilioSid };
