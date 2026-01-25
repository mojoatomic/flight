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

// Good code for pass count
const goodVar = 'good';
let mutableVar = 1;
if (x === null) {
    console.log('strict');
}
