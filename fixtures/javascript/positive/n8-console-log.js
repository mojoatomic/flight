// N8: console.log in Source Files
// These SHOULD trigger violations
// Pattern: call_expression with console.log

// Basic console.log - violations
console.log('debug message');
console.log(userObject);
console.log('User:', userName);

// With template literal - violation
console.log(`Processing order ${orderId}`);

// In function - violation
function processOrder(order) {
  console.log('Processing:', order);
  return order;
}

// Multiple arguments - violation
console.log('Status:', status, 'Count:', count);

// In conditional - violation
if (debugMode) {
  console.log('Debug info:', debugData);
}

// Chained after other operations - violation
fetchData().then(response => {
  console.log('Response:', response);
  return response;
});

// Valid code (no violations) - proper logging
// logger.debug('Processing order', { orderId });
// logger.info('User logged in', { userId });

// Valid - other console methods (only console.log is flagged)
// Note: These would be flagged in a stricter rule set
// console.error('Error occurred');
// console.warn('Warning message');
// console.info('Info message');
