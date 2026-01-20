// N2: @ts-ignore Without Explanation
// These SHOULD trigger violations
// Pattern: comment matching "^//\s*@ts-ignore\s*$" (bare, no explanation)

// Basic bare @ts-ignore - violation
// @ts-ignore
doSomething();

// Another bare @ts-ignore - violation
// @ts-ignore
const badCall = problematic();

// Bare with trailing spaces - violation (spaces don't count as explanation)
// @ts-ignore
functionWithSpaces();

// Multiple in sequence - 2 violations
// @ts-ignore
firstBadCall();
// @ts-ignore
secondBadCall();

// Valid code for comparison (no N2 violations - these have explanations)

// @ts-ignore - lib types are incorrect
validIgnoreWithReason();

// @ts-ignore: workaround for issue #123
validIgnoreWithColon();

// @ts-ignore temporary fix until v2.0
validIgnoreWithText();

// @ts-expect-error intentionally testing error case
validExpectError();

// Helper declarations to make file parse
declare function doSomething(): void;
declare function problematic(): number;
declare function functionWithSpaces(): void;
declare function firstBadCall(): void;
declare function secondBadCall(): void;
declare function validIgnoreWithReason(): void;
declare function validIgnoreWithColon(): void;
declare function validIgnoreWithText(): void;
declare function validExpectError(): void;
