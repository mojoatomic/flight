// N9: var Declaration
// These SHOULD trigger violations
// Pattern: variable_declaration with kind: "var"

// Basic var - violations
var counter = 0;
var userName = 'Alice';
var isActive = true;

// Multiple declarations - violation (one var keyword)
var firstVar, secondVar, thirdVar;

// With initialization - violation
var initializedVar = 'initialized';

// In for loop - violation
for (var loopIndex = 0; loopIndex < 10; loopIndex++) {
  // loop body
}

// Function scoped - violation
function exampleFunction() {
  var localVariable = 'local';
  return localVariable;
}

// Hoisting example - violation
function hoistingExample() {
  var hoistedVar = 'hoisted';
  if (true) {
    var blockVar = 'block'; // Still function scoped!
  }
  return hoistedVar + blockVar;
}

// Valid code (no violations) - use const/let
const constCounter = 0;
let letCounter = 0;
const constUser = 'Alice';
let mutableFlag = true;

for (let properIndex = 0; properIndex < 10; properIndex++) {
  // loop body
}

function properFunction() {
  const localConst = 'local';
  let localLet = 'mutable';
  return localConst;
}
