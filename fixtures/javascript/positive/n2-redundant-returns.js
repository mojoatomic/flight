// N2: Redundant Conditional Returns
// These SHOULD trigger violations
// Pattern: if_statement with return true/false in consequence and opposite in alternative

// Basic redundant return - violation
function isAdult1(age) {
  if (age >= 18) return true; else return false;
}

// With block syntax - violation
function isAdult2(age) {
  if (age >= 18) {
    return true;
  } else {
    return false;
  }
}

// Inverted - violation
function isMinor1(age) {
  if (age < 18) return false; else return true;
}

// With block syntax inverted - violation
function isMinor2(age) {
  if (age < 18) {
    return false;
  } else {
    return true;
  }
}

// Valid code (no violations) - return condition directly
function isAdultCorrect(age) {
  return age >= 18;
}

function isMinorCorrect(age) {
  return age < 18;
}

// Valid - returns non-boolean values
function getStatus(isActive) {
  if (isActive) return 'active'; else return 'inactive';
}
