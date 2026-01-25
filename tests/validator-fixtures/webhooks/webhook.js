// Webhook handler with violations
const express = require('express');
const app = express();

// N1: Plain HTTP webhook URL
const webhookUrl = 'http://example.com/webhook';

// N3: Unsafe signature comparison (timing attack)
function verifySignature(received, expected) {
  return received === expected;
}

// N5: Infinite retry loop
async function sendWithRetry(url, data) {
  while (true) {
    try {
      await fetch(url, { method: 'POST', body: data });
      break;
    } catch (e) {
      // Retry forever
    }
  }
}

// Webhook endpoint
app.post('/webhook', (req, res) => {
  const sig = req.headers['x-signature'];
  if (verifySignature(sig, expectedSig)) {
    processWebhook(req.body);
  }
  res.status(200).send('OK');
});
