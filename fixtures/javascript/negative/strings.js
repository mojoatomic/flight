// Negative Test: Strings
// All rule violations below are inside string literals
// AST queries should NOT match these - they are string content, not code

// =============================================================================
// N1: Generic Variable Names (in strings)
// =============================================================================
const message1 = "const data = fetchUser();";
const message2 = 'const result = processOrder();';
const message3 = `const temp = calculateTotal();`;
const message4 = "let info = getUserInfo();";
const message5 = 'const item = cart.getItem();';
const message6 = `const value = config.getValue();`;

// =============================================================================
// N2: Redundant Conditional Returns (in strings)
// =============================================================================
const codeExample1 = "if (condition) return true; else return false;";
const codeExample2 = 'if (x) { return true; } else { return false; }';

// =============================================================================
// N3: Ternary Returning Boolean Literals (in strings)
// =============================================================================
const ternaryExample1 = "const isValid = condition ? true : false;";
const ternaryExample2 = `return age >= 18 ? true : false;`;

// =============================================================================
// N4: Redundant Boolean Comparisons (in strings)
// =============================================================================
const boolExample1 = "if (isActive === true) { doSomething(); }";
const boolExample2 = 'if (hasPermission === false) { deny(); }';
const boolExample3 = `if (isValid !== true) { showError(); }`;

// =============================================================================
// N5: Magic Number Calculations (in strings)
// =============================================================================
const mathExample1 = "const msPerHour = 60 * 60 * 1000;";
const mathExample2 = 'const secondsPerDay = 24 * 60 * 60;';
const mathExample3 = `setTimeout(fn, 7 * 24 * 60 * 60 * 1000);`;

// =============================================================================
// N6: Generic Function Names (in strings)
// =============================================================================
const fnExample1 = "function handleData(data) { return data; }";
const fnExample2 = 'function processItem(item) { return item; }';
const fnExample3 = `function doValue(value) { return value; }`;

// =============================================================================
// N7: Single-Letter Variables (in strings)
// =============================================================================
const varExample1 = "const x = getX();";
const varExample2 = 'const a = getFirst();';
const varExample3 = `let n = calculateN();`;

// =============================================================================
// N8: console.log (in strings)
// =============================================================================
const logExample1 = "console.log('debug message');";
const logExample2 = 'console.log(userData);';
const logExample3 = `console.log('Status:', status);`;

// =============================================================================
// N9: var Declaration (in strings)
// =============================================================================
const varDeclExample1 = "var oldVariable = 'old';";
const varDeclExample2 = 'var counter = 0;';
const varDeclExample3 = `for (var i = 0; i < 10; i++) {}`;

// =============================================================================
// N10: Loose Equality (in strings)
// =============================================================================
const eqExample1 = "if (x == y) { doSomething(); }";
const eqExample2 = 'if (a != b) { handleDifference(); }';
const eqExample3 = `while (status == 'pending') { wait(); }`;

// =============================================================================
// S1: Await in Loops (in strings)
// =============================================================================
const asyncExample1 = "for (const item of items) { await process(item); }";
const asyncExample2 = 'while (running) { await checkStatus(); }';
const asyncExample3 = `for (let i = 0; i < urls.length; i++) { await fetch(urls[i]); }`;

// Multi-line template literal with code
const multilineCode = `
  // Example of bad code patterns:
  const data = fetchData();
  const result = processResult();
  if (condition) return true; else return false;
  const flag = isValid ? true : false;
  if (x === true) { }
  const ms = 60 * 60 * 1000;
  function handleData() {}
  const x = getValue();
  console.log('debug');
  var oldStyle = true;
  if (a == b) {}
  for (const i of items) { await fetch(i); }
`;

// Regex patterns (these contain violation text but are regex, not code)
const evalPattern = /const data = /;
const consolePattern = /console\.log\(/;
const varPattern = /var \w+ =/;

// This file should have ZERO violations when analyzed with AST queries
// because all the "bad" code is inside string literals, not actual parsed code.
