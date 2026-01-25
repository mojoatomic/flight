// API routes with violations
const express = require('express');

// N1: SQL injection via string concatenation
app.get('/users/:id', async (req, res) => {
  const users = await db.query("SELECT * FROM users WHERE id = " + req.params.id);
  res.json(users);
});
