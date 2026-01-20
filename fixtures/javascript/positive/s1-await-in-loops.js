// S1: Await in Loops
// These SHOULD trigger violations (warnings)
// Pattern: await_expression inside for_statement, for_in_statement, or while_statement

// For loop with await - violation
async function processUsersSequentially(users) {
  for (let userIndex = 0; userIndex < users.length; userIndex++) {
    await sendEmail(users[userIndex]);
  }
}

// For-of loop with await - violation
async function fetchAllData(urls) {
  const results = [];
  for (const url of urls) {
    await fetch(url);
  }
  return results;
}

// For-in loop with await - violation
async function processObjectProperties(dataObject) {
  for (const key in dataObject) {
    await processProperty(key, dataObject[key]);
  }
}

// While loop with await - violation
async function pollUntilComplete(taskId) {
  let isComplete = false;
  while (!isComplete) {
    await checkStatus(taskId);
    isComplete = true; // simplified
  }
}

// Nested loop with await - violation
async function processMatrix(matrix) {
  for (let rowIndex = 0; rowIndex < matrix.length; rowIndex++) {
    for (let colIndex = 0; colIndex < matrix[rowIndex].length; colIndex++) {
      await processCell(matrix[rowIndex][colIndex]);
    }
  }
}

// Valid code (no violations) - use Promise.all
async function processUsersParallel(users) {
  await Promise.all(users.map(user => sendEmail(user)));
}

async function fetchAllDataParallel(urls) {
  const results = await Promise.all(urls.map(url => fetch(url)));
  return results;
}

// Valid - await outside loop
async function singleAwait() {
  const response = await fetch('/api/data');
  return response;
}
