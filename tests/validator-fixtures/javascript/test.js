// JavaScript with violations

// N9: var declaration
var oldStyle = 'bad';

// N10: Loose equality
if (x == null) {
    console.log('loose');
}
if (y != undefined) {
    console.log('also loose');
}

// N11: eval() usage - AST rule
function badEval(userInput) {
    return eval(userInput);
}

// N12: innerHTML assignment - AST rule
function badInnerHTML(element, content) {
    element.innerHTML = content;
}

// N13: document.write() - AST rule
function badDocumentWrite(content) {
    document.write(content);
    document.writeln(content);
}

// Good code for pass count
const goodVar = 'good';
let mutableVar = 1;
if (x === null) {
    console.log('strict');
}
