// Negative Test: Similar Patterns
// These patterns look similar to violations but are actually valid code
// AST queries should NOT match these

// =============================================================================
// N1-like: Names containing generic words but are descriptive
// =============================================================================
const userData = fetchUser();           // "userData" != "data"
const searchResult = performSearch();   // "searchResult" != "result"
const tempFile = createTempFile();      // "tempFile" != "temp"
const userInfo = getUserDetails();      // "userInfo" != "info"
const lineItem = getLineItem();         // "lineItem" != "item"
const configValue = getConfig();        // "configValue" != "value"
const jsonObject = parseJSON();         // "jsonObject" != "obj"
const importantThing = getImportant();  // "importantThing" != "thing"
const stuffedAnimal = getToy();         // "stuffedAnimal" != "stuff"
const tmpDirectory = getTmpDir();       // "tmpDirectory" != "tmp"
const returnValue = calculate();        // "returnValue" != "ret"
const validationResult = validate();    // "validationResult" != "val"

// =============================================================================
// N2-like: Conditionals returning non-boolean or complex logic
// =============================================================================
function getStatusText(isActive) {
  if (isActive) return 'active'; else return 'inactive';  // returns strings, not booleans
}

function getScore(passed) {
  if (passed) return 100; else return 0;  // returns numbers, not booleans
}

function getValue(condition) {
  if (condition) return 'yes'; else return 'no';  // returns strings
}

// =============================================================================
// N3-like: Ternary with non-boolean values
// =============================================================================
const statusText = isActive ? 'active' : 'inactive';
const displayCount = hasItems ? itemCount : 0;
const userName = isLoggedIn ? currentUser.name : 'Guest';
const iconClass = isExpanded ? 'expanded' : 'collapsed';

// =============================================================================
// N4-like: Comparisons that are not to true/false literals
// =============================================================================
if (status === 'active') {
  enableFeature();
}

if (count === 0) {
  showEmpty();
}

if (userRole === 'admin') {
  grantAccess();
}

if (errorCode !== 200) {
  handleError();
}

// Comparing variables (not literals)
const isEnabled = true;
const checkValue = true;
if (flag === isEnabled) {  // comparing to variable, not literal
  proceed();
}

// =============================================================================
// N5-like: Multiplication that doesn't form 3+ number chain
// =============================================================================
const twoNumbers = 60 * 1000;           // Only 2 numbers
const simpleCalc = 24 * 60;             // Only 2 numbers
const withVariable = hours * 60 * 60;  // Has variable, not pure numbers

// Using named constants
const MS_PER_SECOND = 1000;
const SECONDS_PER_MINUTE = 60;
const calculatedValue = MS_PER_SECOND * SECONDS_PER_MINUTE;  // Uses constants

// =============================================================================
// N6-like: Functions with handle/process but specific nouns
// =============================================================================
function handleUserLogin(credentials) {
  return authenticate(credentials);
}

function handlePaymentSubmission(payment) {
  return processPayment(payment);
}

function processOrderConfirmation(order) {
  return confirmOrder(order);
}

function processCustomerRefund(refundRequest) {
  return issueRefund(refundRequest);
}

function executeQueryPlan(query) {
  return runQuery(query);
}

function manageDatabaseConnection(config) {
  return connect(config);
}

// =============================================================================
// N7-like: Allowed single letters (i, j, k, m) and longer names
// =============================================================================
for (let i = 0; i < 10; i++) {
  // i is allowed as loop counter
}

for (let j = 0; j < rows.length; j++) {
  for (let k = 0; k < cols.length; k++) {
    // j and k are allowed as loop counters
  }
}

const m = getMatrix();  // m is allowed

// Two-letter names are fine
const id = getId();
const fn = getFunction();
const cb = getCallback();

// =============================================================================
// N8-like: Other console methods (only console.log is flagged)
// =============================================================================
console.error('Error occurred:', errorDetails);
console.warn('Warning: deprecated method');
console.info('Application started');
console.debug('Debug information');
console.trace('Stack trace');
console.table(dataArray);

// Logger usage (proper logging)
// logger.log('message');  // This would be a logger, not console

// =============================================================================
// N9-like: const and let declarations (not var)
// =============================================================================
const constantValue = 'immutable';
let mutableValue = 'can change';
const anotherConst = 123;
let anotherLet = 456;

// Using const/let in loops
for (let loopIndex = 0; loopIndex < 10; loopIndex++) {
  const iterationValue = loopIndex * 2;
}

// =============================================================================
// N10-like: Strict equality (=== and !==)
// =============================================================================
if (userAge === 18) {
  allowEntry();
}

if (status === 'active') {
  enableFeature();
}

if (userRole !== 'admin') {
  restrictAccess();
}

if (errorCount !== 0) {
  showErrors();
}

// Proper null/undefined checks
if (userValue === null || userValue === undefined) {
  setDefault();
}

if (configOption === undefined) {
  useDefaultConfig();
}

// =============================================================================
// S1-like: Await outside of loops
// =============================================================================
async function singleFetch() {
  const response = await fetch('/api/endpoint');
  return response.json();
}

async function sequentialCalls() {
  const first = await getFirst();
  const second = await getSecond();
  return { first, second };
}

// Using Promise.all (proper pattern)
async function parallelFetch(urls) {
  const responses = await Promise.all(urls.map(url => fetch(url)));
  return responses;
}

// This file should have ZERO violations when analyzed with AST queries
// because all patterns here are valid code that looks similar but doesn't match.
