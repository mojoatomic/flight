// N4: Redundant Boolean Comparisons
// These SHOULD trigger violations
// Pattern: binary_expression with === or !== and true/false on right side

// Comparing to true - violations
if (isActive === true) {
  doSomething();
}

if (hasPermission === true) {
  grantAccess();
}

// Comparing to false - violations
if (isDisabled === false) {
  enableFeature();
}

if (hasErrors === false) {
  proceed();
}

// Using !== - violations
if (isValid !== true) {
  showError();
}

if (isEmpty !== false) {
  clearData();
}

// In while loop - violation
while (shouldContinue === true) {
  processNext();
}

// In ternary condition - violation
const status = (isEnabled === true) ? 'on' : 'off';

// Valid code (no violations) - use boolean directly
if (isActive) {
  doSomething();
}

if (!isDisabled) {
  enableFeature();
}

if (!isValid) {
  showError();
}

while (shouldContinue) {
  processNext();
}
