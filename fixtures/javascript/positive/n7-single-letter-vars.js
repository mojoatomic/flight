// N7: Single-Letter Variables
// These SHOULD trigger violations
// Pattern: variable_declarator with single-letter name (except i, j, k, m)

// Single letter violations
const a = getFirstItem();
const b = getSecondItem();
const c = getThirdItem();
const d = getData();
const e = getError();
const f = getFlag();
const g = getGroup();
const h = getHandler();
const l = getList();
const n = getNumber();
const o = getObject();
const p = getPointer();
const q = getQuery();
const r = getResult();
const s = getString();
const t = getTimestamp();
const u = getUser();
const v = getValue();
const w = getWidth();
const x = getX();
const y = getY();
const z = getZ();

// Using let - still violations
let a2 = 1;
let b2 = 2;

// Valid code (no violations) - allowed loop counters
for (let i = 0; i < 10; i++) {
  console.log(i);
}

for (let j = 0; j < 10; j++) {
  console.log(j);
}

for (let k = 0; k < 10; k++) {
  console.log(k);
}

// Valid - 'm' is also allowed
const m = getMatrix();

// Valid - descriptive names
const user = getUser();
const count = getNumber();
const timestamp = getTimestamp();
const errorMessage = getError();
