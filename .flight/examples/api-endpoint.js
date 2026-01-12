// Example: API Endpoint Pattern
// This is the canonical pattern for Express API endpoints in this project.
// Flight prompts will reference this as the pattern to follow.

// 1. Imports
const express = require('express');

// 2. Constants
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.EXTERNAL_API_KEY;
const API_BASE_URL = 'https://api.example.com/v1';

// 3. App initialization
const app = express();

// 4. Route handlers
app.get('/api/resource', async (req, res) => {
  if (!API_KEY) {
    return res.status(502).json({ error: 'Upstream API failure', code: 502 });
  }

  try {
    const response = await fetch(API_BASE_URL, {
      headers: { 'X-API-KEY': API_KEY }
    });

    if (response.status === 429) {
      return res.status(503).json({ error: 'Rate limited', code: 503 });
    }

    if (!response.ok) {
      return res.status(502).json({ error: 'Upstream API failure', code: 502 });
    }

    const data = await response.json();

    if (!(data && data.status === 'success')) {
      return res.status(502).json({ error: 'Upstream API failure', code: 502 });
    }

    if (!(data.result && typeof data.result.value === 'number')) {
      return res.status(502).json({ error: 'Upstream API failure', code: 502 });
    }

    return res.status(200).json({
      value: data.result.value,
      unit: 'USD',
      timestamp: data.timestamp,
      source: 'example.com'
    });

  } catch (err) {
    return res.status(502).json({ error: 'Upstream API failure', code: 502 });
  }
});

app.all('/api/resource', (req, res) => {
  return res.status(405).json({ error: 'Method not allowed', code: 405 });
});

// 5. Server start
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
