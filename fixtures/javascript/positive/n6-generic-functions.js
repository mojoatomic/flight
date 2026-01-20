// N6: Generic Function Names
// These SHOULD trigger violations
// Pattern: function_declaration with names like handle/process/do/run/execute/manage + Data/Item/Value/Info/Result/Object

// handleX violations
function handleData(input) {
  return input;
}

function handleItem(input) {
  return input;
}

function handleValue(input) {
  return input;
}

function handleInfo(input) {
  return input;
}

function handleResult(input) {
  return input;
}

function handleObject(input) {
  return input;
}

// processX violations
function processData(input) {
  return input;
}

function processItem(input) {
  return input;
}

function processValue(input) {
  return input;
}

// doX violations
function doData(input) {
  return input;
}

function doItem(input) {
  return input;
}

// runX violations
function runData(input) {
  return input;
}

function runValue(input) {
  return input;
}

// executeX violations
function executeData(input) {
  return input;
}

function executeItem(input) {
  return input;
}

// manageX violations
function manageData(input) {
  return input;
}

function manageInfo(input) {
  return input;
}

// Valid code (no violations) - specific function names
function validateUserInput(input) {
  return input.trim();
}

function transformOrderToInvoice(order) {
  return { ...order, type: 'invoice' };
}

function calculateShippingCost(order) {
  return order.weight * 2.5;
}

// Valid - handleX with specific noun
function handleUserLogin(credentials) {
  return authenticate(credentials);
}

function processPaymentRequest(payment) {
  return chargeCard(payment);
}
