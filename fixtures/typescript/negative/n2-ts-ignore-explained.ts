// N2 Negative Test: @ts-ignore WITH Explanations
// All @ts-ignore comments below have explanations
// AST queries should NOT match these - they are not bare @ts-ignore

// =============================================================================
// @ts-ignore with dash-separated explanation
// =============================================================================

// @ts-ignore - lib types are incorrect
functionWithBadTypes();

// @ts-ignore - temporary workaround for issue #123
temporaryWorkaround();

// @ts-ignore - will be fixed in v3.0
futureFixPlanned();

// =============================================================================
// @ts-ignore with colon-separated explanation
// =============================================================================

// @ts-ignore: lib types incorrect
colonExplanation1();

// @ts-ignore: workaround for known issue
colonExplanation2();

// @ts-ignore: TODO fix this properly
colonExplanation3();

// =============================================================================
// @ts-ignore with direct text explanation
// =============================================================================

// @ts-ignore lib types wrong
directText1();

// @ts-ignore third-party types are broken
directText2();

// @ts-ignore legacy code migration in progress
directText3();

// @ts-ignore see issue #456 for details
directText4();

// =============================================================================
// @ts-expect-error (different directive entirely)
// =============================================================================

// @ts-expect-error intentionally testing error case
expectError1();

// @ts-expect-error - this should fail
expectError2();

// @ts-expect-error: expected to be wrong type
expectError3();

// =============================================================================
// Valid code declarations
// =============================================================================

declare function functionWithBadTypes(): void;
declare function temporaryWorkaround(): void;
declare function futureFixPlanned(): void;
declare function colonExplanation1(): void;
declare function colonExplanation2(): void;
declare function colonExplanation3(): void;
declare function directText1(): void;
declare function directText2(): void;
declare function directText3(): void;
declare function directText4(): void;
declare function expectError1(): void;
declare function expectError2(): void;
declare function expectError3(): void;

const validCode: string = 'no violations here';
