// N1 Negative Test: "any" in String Literals
// All "any" patterns below are inside strings
// AST queries should NOT match these - they are string content, not code

// =============================================================================
// Double-quoted strings with "any"
// =============================================================================

const doubleQuote1 = "accepts any input";
const doubleQuote2 = "type: any";
const doubleQuote3 = "const data: any = value";
const doubleQuote4 = "value as any";
const doubleQuote5 = "function(x: any): any";
const doubleQuote6 = "Array<any>";

// =============================================================================
// Single-quoted strings with "any"
// =============================================================================

const singleQuote1 = 'any value is accepted';
const singleQuote2 = 'type annotation: any';
const singleQuote3 = 'as any cast';
const singleQuote4 = 'let x: any;';

// =============================================================================
// Template literals with "any"
// =============================================================================

const template1 = `value as any`;
const template2 = `const data: any = ${42}`;
const template3 = `
  Multi-line template
  const config: any = getConfig();
  value as any
`;
const template4 = `type Callback = (arg: any) => any`;

// =============================================================================
// Regular expressions with "any"
// =============================================================================

const regex1 = /any/g;
const regex2 = /: any/;
const regex3 = /as any/i;
const regex4 = new RegExp('any');
const regex5 = new RegExp(': any');

// =============================================================================
// Valid code (no violations expected)
// =============================================================================

const validString: string = 'hello world';
const validNumber: number = 123;
const validBoolean: boolean = true;

function validFunc(input: string): string {
  return input.toUpperCase();
}

interface ValidType {
  message: string;
}
