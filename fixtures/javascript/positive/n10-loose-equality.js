// N10: Loose Equality
// These SHOULD trigger violations
// Pattern: binary_expression with == or != operators

// Loose equality - violations
if (userAge == 18) {
  allowEntry();
}

if (status == 'active') {
  enableFeature();
}

if (count == 0) {
  showEmpty();
}

// Null checks with == - violations (even though sometimes intentional)
if (userValue == null) {
  setDefault();
}

if (configOption == undefined) {
  useDefault();
}

// Loose inequality - violations
if (userRole != 'admin') {
  restrictAccess();
}

if (errorCount != 0) {
  showErrors();
}

// In ternary - violation
const isZero = count == 0 ? true : false;

// In while condition - violation
while (status != 'complete') {
  waitForCompletion();
}

// Type coercion danger - violation
if (inputValue == 1) {  // '1' == 1 is true!
  processAsOne();
}

// Valid code (no violations) - strict equality
if (userAge === 18) {
  allowEntry();
}

if (status === 'active') {
  enableFeature();
}

if (userRole !== 'admin') {
  restrictAccess();
}

// Proper null/undefined check
if (userValue === null || userValue === undefined) {
  setDefault();
}
