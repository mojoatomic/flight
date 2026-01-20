// N1: Generic Variable Names
// These SHOULD trigger violations
// Pattern: variable_declarator with names matching: data, result, temp, info, item, value, obj, thing, stuff, tmp, ret, val

// Basic generic names - all violations
const data = fetchUser();
const result = processOrder();
const temp = calculateTotal();
const info = getUserInfo();
const item = cart.getItem();
const value = config.getValue();
const obj = JSON.parse(jsonString);
const thing = createSomething();
const stuff = loadStuff();
const tmp = temporaryCalculation();
const ret = getReturnValue();
const val = extractValue();

// Using let - still violations
let data2 = fetchData();
let result2 = getResult();

// In destructuring context - should NOT match (identifier in different context)
// const { data: userData } = response;  // "data" here is property key, not variable name

// Valid code (no violations) - descriptive names
const user = fetchUser();
const processedOrder = processOrder();
const invoiceTotal = calculateTotal();
