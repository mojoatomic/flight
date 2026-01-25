// TypeScript with violations

// N1: any type
function badAny(x: any): any {
  return x.foo.bar;
}

// N2: Type assertion to any
const value = someValue as any;

// N3: @ts-ignore without explanation
// @ts-ignore
const ignored = badCall();

// N4: Non-null assertion overuse
function badAssert(x?: string) {
  return x!.toUpperCase();
}

// M1: Implicit any in function params
function implicitAny(x, y) {
  return x + y;
}

// Good code for pass count
function goodTyped(x: string): number {
  return x.length;
}
