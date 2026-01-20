// N1: Unjustified any
// These SHOULD trigger violations
// Pattern: type_annotation or as_expression with predefined_type "any"

// Type annotations - all violations
const responseData: any = fetch('/api');
let configValue: any;
var legacyVar: any = getLegacy();

// As expressions - all violations
const parsed = JSON.parse(str) as any;
const forcedCast = unknownValue as any;
const nestedCast = (getValue() as any).property;

// Function parameters - violations
function processInput(inputParam: any): void {
  console.log(inputParam);
}

// Function return types - violation
function getAnything(): any {
  return null;
}

// Combined param and return - 2 violations
function transform(transformInput: any): any {
  return transformInput;
}

// Type alias with any - violations
type AnyCallback = (callbackArg: any) => any;
type AnyArray = any[];

// Interface with any - violation
interface LegacyData {
  payload: any;
}

// Generic with any - violation
const typedArray: Array<any> = [];

// Arrow function - violations
const arrowFn = (arrowParam: any): any => arrowParam;

// Valid code for comparison (no violations from N1)
const validUser: string = 'test';
const validNumber: number = 42;
const unknownData: unknown = getExternalData();

function getExternalData(): unknown {
  return null;
}
declare const str: string;
declare const unknownValue: unknown;
declare function getValue(): unknown;
declare function getLegacy(): unknown;
