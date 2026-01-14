#!/bin/bash
# react.validate.sh - Validate React code against domain rules
set -uo pipefail

FILES="${@:-src/**/*.jsx src/**/*.tsx src/*.jsx src/*.tsx}"
PASS=0
FAIL=0
WARN=0

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

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

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [ -z "$result" ]; then
        green "✅ $name"
        ((PASS++))
    else
        yellow "⚠️  $name"
        echo "$result" | head -5 | sed 's/^/   /'
        ((WARN++))
    fi
}

echo "═══════════════════════════════════════════"
echo "  React Domain Validation"
echo "═══════════════════════════════════════════"
echo ""

# Expand globs
EXPANDED_FILES=$(ls $FILES 2>/dev/null || true)
if [ -z "$EXPANDED_FILES" ]; then
    red "No files found matching: $FILES"
    exit 1
fi
FILES="$EXPANDED_FILES"

echo "Files: $(echo "$FILES" | wc -w | tr -d ' ')"
echo ""

echo "## NEVER Rules"

# N1: Inline objects in JSX props (style={{ }}, config={{ }})
check "N1: No inline objects in JSX props" \
    grep -En "=[{][{]|=\{\s*\{" $FILES

# N2: Inline arrow functions in JSX props
check "N2: No inline functions in JSX props" \
    grep -En "onClick=\{.*=>|onChange=\{.*=>|onSubmit=\{.*=>|onBlur=\{.*=>|onFocus=\{.*=>" $FILES

# N3: Index as key
check "N3: No index as key" \
    grep -En "key=\{.*index|key=\{i\}|key=\{idx\}" $FILES

# N4: Direct state mutation (push, splice, direct assignment)
check "N4: No direct state mutation (.push, .splice on state)" \
    grep -En "\.push\(|\.splice\(|\.pop\(|\.shift\(|\.unshift\(" $FILES

# N5: Empty dependency array with references (common mistake)
check "N5: No useEffect with empty deps referencing outer vars" \
    bash -c "grep -Pzo 'useEffect\(\s*\(\)\s*=>\s*\{[^}]*[a-zA-Z]+[^}]*\},\s*\[\]\)' $FILES 2>/dev/null | head -5 || true"

# N6: Conditional hooks
check "N6: No conditional hooks (if/else before useState/useEffect)" \
    grep -En "if.*\{[^}]*(useState|useEffect|useMemo|useCallback|useRef)" $FILES

# N7: Generic component prop names
check "N7: No generic prop names (data, info, item, value as props)" \
    grep -En "function\s+\w+\(\s*\{\s*(data|info|item|value)\s*\}" $FILES

# N8: Export default (prefer named exports)
# Exception: Next.js App Router special files (page.tsx, layout.tsx, loading.tsx, error.tsx, etc.)
check "N8: No export default (use named exports)" \
    bash -c "
    for f in $FILES; do
        basename=\$(basename \"\$f\")
        # Skip Next.js special files that require export default
        if [[ \"\$basename\" =~ ^(page|layout|loading|error|not-found|template|default)\.(tsx|jsx|ts|js)$ ]]; then
            continue
        fi
        grep -En '^export default' \"\$f\" 2>/dev/null || true
    done
    "

# N9: Props named data/info/item
check "N9: No props destructured as data/info/item/value" \
    grep -En "\{\s*(data|info|item|value)\s*\}" $FILES | grep -v "const\|let\|var"

# N10: console.log
check "N10: No console.log in components" \
    grep -En "console\.(log|warn|error)" $FILES

# N11: Ternary for boolean (condition ? true : false)
check "N11: No ternary returning boolean literals" \
    grep -En "\?\s*true\s*:\s*false|\?\s*false\s*:\s*true" $FILES

# N12: === true / === false
check "N12: No redundant boolean comparisons" \
    grep -En "===\s*true|===\s*false|!==\s*true|!==\s*false" $FILES

echo ""
echo "## MUST Rules (warnings)"

# M1: Loading state handling
warn "M1: Components with fetch/async should handle isLoading" \
    bash -c "
    for f in $FILES; do
        if grep -q 'fetch\|useQuery\|useSWR\|useEffect.*async' \"\$f\"; then
            if ! grep -q 'isLoading\|loading' \"\$f\"; then
                echo \"\$f: has async but no loading state\"
            fi
        fi
    done
    "

# M2: Error state handling  
warn "M2: Components with fetch/async should handle error" \
    bash -c "
    for f in $FILES; do
        if grep -q 'fetch\|useQuery\|useSWR\|useEffect.*async' \"\$f\"; then
            if ! grep -q 'error\|Error' \"\$f\"; then
                echo \"\$f: has async but no error handling\"
            fi
        fi
    done
    "

# M3: Boolean prop prefixes
# Note: Standard HTML boolean attributes (disabled, checked, selected, open) are excluded
warn "M3: Boolean props should use is/has/can/should prefix" \
    grep -En "^\s*(loading|visible|active)=" $FILES

# M4: useCallback for handlers passed to children
warn "M4: Handlers passed to children should use useCallback" \
    bash -c "
    for f in $FILES; do
        # Find functions defined with const that are passed as props
        if grep -q 'const handle' \"\$f\"; then
            if ! grep -q 'useCallback' \"\$f\"; then
                handlers=\$(grep -c 'const handle' \"\$f\")
                if [ \"\$handlers\" -gt 0 ]; then
                    echo \"\$f: \$handlers handlers without useCallback\"
                fi
            fi
        fi
    done
    "

echo ""
echo "## Info"

# Component count
COMPONENT_COUNT=$(grep -lE "^export (async )?function [A-Z]|^export const [A-Z].* = " $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Components found: $COMPONENT_COUNT"

# Hook usage
HOOKS_USED=$(grep -ohE "use[A-Z][a-zA-Z]+" $FILES 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//')
echo "ℹ️  Hooks used: ${HOOKS_USED:-none}"

# Custom hooks
CUSTOM_HOOKS=$(grep -lE "^export function use[A-Z]" $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Custom hooks: $CUSTOM_HOOKS"

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

exit $FAIL
