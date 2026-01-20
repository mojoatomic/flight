// N3: Ternary Returning Boolean Literals
// These SHOULD trigger violations
// Pattern: ternary_expression with true/false as consequence and alternative

// Basic ternary boolean - violation
const isValid1 = condition ? true : false;

// With comparison - violation
const isAdult1 = age >= 18 ? true : false;

// Inverted - violation
const isMinor1 = age < 18 ? false : true;

// In return statement - violation
function checkStatus1(status) {
  return status === 'active' ? true : false;
}

// Nested in expression - violation
const flagValue = (userRole === 'admin' ? true : false);

// Assignment with complex condition - violation
const hasAccess = (isLoggedIn && hasPermission) ? true : false;

// Valid code (no violations) - use condition directly
const isValid2 = condition;
const isAdult2 = age >= 18;
const isMinor2 = !(age >= 18);

function checkStatus2(status) {
  return status === 'active';
}

// Valid - ternary with non-boolean values
const statusText = isActive ? 'active' : 'inactive';
const displayValue = count > 0 ? count : 'none';
