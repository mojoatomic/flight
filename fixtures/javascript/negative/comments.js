// Negative Test: Comments
// All rule violations below are inside comments
// AST queries should NOT match these - they are not actual code

// =============================================================================
// N1: Generic Variable Names (in comments)
// =============================================================================
// const data = fetchUser();
// const result = processOrder();
// const temp = calculateTotal();
// const info = getUserInfo();
// const item = cart.getItem();
// const value = config.getValue();

// =============================================================================
// N2: Redundant Conditional Returns (in comments)
// =============================================================================
// if (condition) return true; else return false;
// if (x) { return true; } else { return false; }

// =============================================================================
// N3: Ternary Returning Boolean Literals (in comments)
// =============================================================================
// const isValid = condition ? true : false;
// return age >= 18 ? true : false;

// =============================================================================
// N4: Redundant Boolean Comparisons (in comments)
// =============================================================================
// if (isActive === true) {}
// if (hasPermission === false) {}
// if (isValid !== true) {}

// =============================================================================
// N5: Magic Number Calculations (in comments)
// =============================================================================
// const msPerHour = 60 * 60 * 1000;
// const secondsPerDay = 24 * 60 * 60;

// =============================================================================
// N6: Generic Function Names (in comments)
// =============================================================================
// function handleData() {}
// function processItem() {}
// function doValue() {}

// =============================================================================
// N7: Single-Letter Variables (in comments)
// =============================================================================
// const x = getX();
// const a = getFirst();
// let n = count;

// =============================================================================
// N8: console.log (in comments)
// =============================================================================
// console.log('debug');
// console.log(userData);

// =============================================================================
// N9: var Declaration (in comments)
// =============================================================================
// var oldVariable = 'old';
// var counter = 0;

// =============================================================================
// N10: Loose Equality (in comments)
// =============================================================================
// if (x == y) {}
// if (a != b) {}

// =============================================================================
// S1: Await in Loops (in comments)
// =============================================================================
// for (const item of items) { await process(item); }
// while (running) { await check(); }

/*
 * Multi-line comment block with violations:
 *
 * const data = fetchData();
 * const result = processResult();
 * if (condition) return true; else return false;
 * const flag = isValid ? true : false;
 * if (x === true) { }
 * const ms = 60 * 60 * 1000;
 * function handleData() {}
 * const x = getValue();
 * console.log('debug');
 * var oldStyle = true;
 * if (a == b) {}
 * for (const i of items) { await fetch(i); }
 */

/**
 * JSDoc comment with code examples:
 * @example
 * // Don't do this:
 * const data = getData();
 * var counter = 0;
 * if (x == y) {}
 * console.log(data);
 *
 * @example
 * // Do this instead:
 * const userData = getData();
 * let counter = 0;
 * if (x === y) {}
 * logger.debug(userData);
 */

// This file should have ZERO violations when analyzed with AST queries
// because all the "bad" code is inside comments, not actual parsed code.

const validCode = 'This is the only actual code in this file';
