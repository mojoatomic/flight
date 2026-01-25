// Code with hygiene violations

// N1: Generic variable names
const data = fetchData();
const result = process(data);
const temp = result.value;

// N2: Redundant conditional returns
function check(x) {
  if (x > 0) return true;
  return false;
}

// N3: Ternary returning boolean literals
const isValid = condition ? true : false;

// N4: Redundant boolean comparisons
if (isEnabled === true) {
  doSomething();
}

// N5: Magic number calculations
const hours = ms / (1000 * 60 * 60);
const days = ms / (24 * 60 * 60 * 1000);

// N6: Generic function names
function processData(input) {
  return input;
}

// N7: Single letter variables outside loops
const x = getValue();
const y = transform(x);

// N8: Console debugging
console.log('debug:', data);

// M1: Boolean without proper prefix
const enabled = true;

// M3: Constants not UPPER_CASE
const maxRetries = 5;
