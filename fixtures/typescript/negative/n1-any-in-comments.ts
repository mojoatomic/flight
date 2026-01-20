// N1 Negative Test: "any" in Comments
// All "any" patterns below are inside comments
// AST queries should NOT match these - they are comment text, not code

// =============================================================================
// Single-line comments with "any"
// =============================================================================

// const data: any = something;
// This function accepts any value as input
// The any type should be avoided
// response: any is bad practice
// Using as any is dangerous
// type Callback = (arg: any) => any;

// =============================================================================
// Multi-line comments with "any"
// =============================================================================

/*
 * This is a multi-line comment mentioning any
 * const config: any = getConfig();
 * value as any
 * function process(x: any): any {}
 */

/* inline any comment */

/*
   any type
   as any
   : any
*/

// =============================================================================
// JSDoc comments with "any"
// =============================================================================

/**
 * @param {any} value - This accepts any value
 * @returns {any} Returns any type
 */
function documentedFunction(value: unknown): unknown {
  return value;
}

/**
 * Example showing any usage:
 * const bad: any = data;
 * const cast = value as any;
 */
const exampleVar: string = 'example';

// =============================================================================
// Valid code (no violations expected)
// =============================================================================

const validUser: string = 'test';
const validNumber: number = 42;
const validUnknown: unknown = null;

interface ValidInterface {
  name: string;
  count: number;
}

function validFunction(input: string): number {
  return input.length;
}
