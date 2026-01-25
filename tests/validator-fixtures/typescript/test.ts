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

// N9: eval() usage - AST rule
function badEval(userInput: string): unknown {
  return eval(userInput);
}

// N10: innerHTML assignment - AST rule
function badInnerHTML(element: HTMLElement, content: string): void {
  element.innerHTML = content;
}

// N11: document.write() - AST rule
function badDocumentWrite(content: string): void {
  document.write(content);
  document.writeln(content);
}

// Good code for pass count
function goodTyped(x: string): number {
  return x.length;
}
