#!/bin/bash
# javascript-hygiene.validate.sh - Validate JavaScript against hygiene rules
set -uo pipefail

FILES="${@:-src/*.js}"
PASS=0
FAIL=0

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [ -z "$result" ]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        echo "$result" | head -10 | sed 's/^/   /'
        ((FAIL++))
    fi
}

echo "═══════════════════════════════════════════"
echo "  JavaScript Hygiene Validation"
echo "═══════════════════════════════════════════"
echo ""

# Check files exist
if ! ls $FILES >/dev/null 2>&1; then
    red "No files found matching: $FILES"
    exit 1
fi

echo "## NEVER Rules"

# N1: Generic variable names
check "N1: No generic names (data, result, temp, info, item, value, obj)" \
    grep -En "\b(const|let|var)\s+(data|result|temp|info|item|value|obj|thing|stuff|tmp|ret|val)\s*=" $FILES

# N2: Redundant conditional returns
check "N2: No 'if (x) return true; else return false'" \
    grep -En "return true;?\s*(else|})?\s*return false|return false;?\s*(else|})?\s*return true" $FILES

# N3: Ternary returning boolean literals
check "N3: No 'condition ? true : false'" \
    grep -En "\?\s*true\s*:\s*false|\?\s*false\s*:\s*true" $FILES

# N4: Redundant boolean comparisons
check "N4: No '=== true' or '=== false'" \
    grep -En "===\s*true|===\s*false|!==\s*true|!==\s*false" $FILES

# N5: Magic number calculations (time-based)
check "N5: No magic calculations (60 * 60, 24 * 60, etc.)" \
    grep -En "[0-9]+\s*\*\s*[0-9]+\s*\*\s*[0-9]+" $FILES

# N6: Generic function names without context
check "N6: No generic function names (handleData, processItem, etc.)" \
    grep -En "function\s+(handle|process|do|run|execute|manage)(Data|Item|Value|Info|Result|Object)\s*\(" $FILES

# N7: Single-letter variables (except loop counters)
check "N7: No single-letter variables (except i, j, k in loops)" \
    grep -En "\b(const|let|var)\s+[a-hln-z]\s*=" $FILES

# N8: console.log in source (not tests)
check "N8: No console.log in source files" \
    bash -c "echo '$FILES' | tr ' ' '\n' | grep -v test | grep -v spec | xargs grep -n 'console\.log' 2>/dev/null || true"

echo ""
echo "## SHOULD Rules (warnings only)"

# S1: Check for ESLint (if available)
if command -v npx &> /dev/null && [ -f "package.json" ]; then
    if grep -q '"eslint"' package.json 2>/dev/null; then
        echo "ℹ️  ESLint available - run 'npx eslint $FILES' for full analysis"
    fi
fi

# S2: Boolean naming (informational)
BOOL_COUNT=$(grep -Ec "\b(is|has|can|should|will)[A-Z]" $FILES 2>/dev/null || echo "0")
echo "ℹ️  Boolean-prefixed variables found: $BOOL_COUNT"

# S3: Constant naming (informational)
CONST_UPPER=$(grep -Ec "const\s+[A-Z][A-Z_]+\s*=" $FILES 2>/dev/null || echo "0")
echo "ℹ️  UPPER_CASE constants found: $CONST_UPPER"

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

exit $FAIL
