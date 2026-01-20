// N2 Negative Test: "@ts-ignore" in String Literals
// All @ts-ignore patterns below are inside strings
// AST queries should NOT match these - they are string content, not comments

// =============================================================================
// Double-quoted strings with "@ts-ignore"
// =============================================================================

const doubleQuote1 = "// @ts-ignore";
const doubleQuote2 = "@ts-ignore";
const doubleQuote3 = "Use // @ts-ignore to suppress errors";
const doubleQuote4 = "The @ts-ignore directive suppresses type errors";

// =============================================================================
// Single-quoted strings with "@ts-ignore"
// =============================================================================

const singleQuote1 = '// @ts-ignore';
const singleQuote2 = '@ts-ignore';
const singleQuote3 = 'Add @ts-ignore above the line';

// =============================================================================
// Template literals with "@ts-ignore"
// =============================================================================

const template1 = `// @ts-ignore`;
const template2 = `Use // @ts-ignore for type suppression`;
const template3 = `
  Example:
  // @ts-ignore
  badCode();
`;
const template4 = `@ts-ignore is a TypeScript directive`;

// =============================================================================
// String containing explanation of @ts-ignore
// =============================================================================

const documentation = `
# TypeScript Ignore Directive

Use \`// @ts-ignore\` to suppress type errors on the next line.

Example:
\`\`\`typescript
// @ts-ignore
problematicCode();
\`\`\`

Better: Use \`// @ts-ignore - reason\` with an explanation.
`;

// =============================================================================
// Array of strings with "@ts-ignore"
// =============================================================================

const directives: string[] = [
  '// @ts-ignore',
  '// @ts-expect-error',
  '// @ts-nocheck',
];

// =============================================================================
// Valid code (no violations expected)
// =============================================================================

const validMessage: string = 'Hello, World!';
const validCount: number = 42;

function validFunction(input: string): string {
  return input.trim();
}
