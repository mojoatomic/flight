#!/bin/bash
# code-hygiene.validate.sh - Universal code hygiene checks for any language
set -uo pipefail

FILES="${@:-*.js *.ts *.tsx *.py *.go *.rs *.java *.c *.cpp *.h **/*.js **/*.ts **/*.tsx **/*.py **/*.go **/*.rs **/*.java **/*.c **/*.cpp **/*.h}"
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
echo "  Code Hygiene Validation (Universal)"
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

# N1: Generic variable names (assignment context)
# Matches: const/let/var data =, data =, result =, etc.
check "N1: No generic variable names (data, result, temp, info, item, value, obj, thing)" \
    grep -En "^\s*(const|let|var|)\s*(data|result|temp|tmp|info|item|value|val|obj|thing|stuff|ret|res|output|input|payload)\s*=" $FILES

# N2: Redundant conditional returns
check "N2: No 'if (x) return true; else return false'" \
    grep -En "if\s*\([^)]+\)\s*return\s+(true|false)\s*;\s*(else\s*)?(return\s+(true|false))?" $FILES

# N3: Ternary returning boolean literals
check "N3: No 'condition ? true : false'" \
    grep -En "\?\s*true\s*:\s*false|\?\s*false\s*:\s*true" $FILES

# N4: Redundant boolean comparisons
check "N4: No '=== true' or '=== false' or '== true' or '== false'" \
    grep -En "===?\s*true|===?\s*false|!==?\s*true|!==?\s*false" $FILES

# N5: Magic number calculations (time-based) - but not in UPPER_CASE constant definitions
check "N5: No magic calculations (60 * 60, 24 * 60, 1000 *, etc.)" \
    bash -c "
    for f in $FILES; do
        grep -En '60\s*\*\s*60|24\s*\*\s*60|1000\s*\*\s*60|7\s*\*\s*24|1024\s*\*\s*1024' \"\$f\" 2>/dev/null | \
        grep -v '[A-Z_]\{2,\}\s*=' | head -5
    done
    "

# N6: Generic function names
check "N6: No generic function names (handleData, processItem, doSomething)" \
    grep -En "function\s+(handleData|processItem|processItems|doSomething|getData|setData|updateValue|handleEvent|processResult|transformData|handleInput|processInput)\s*\(|def\s+(handle_data|process_item|do_something|get_data|set_data|update_value|handle_event|process_result|transform_data)\s*\(" $FILES

# N7: Single-letter variables (not in loop context)
check "N7: No single-letter variables outside loops" \
    bash -c "
    for f in $FILES; do
        # Find single letter assignments not in for/while lines
        grep -En '^\s*(const|let|var|)\s+[a-hk-wyz]\s*=' \"\$f\" 2>/dev/null | grep -v 'for\s*(' | grep -v 'while\s*(' | head -5
    done
    "

# N8: console.log / print debugging
check "N8: No console.log/print debugging in source files" \
    grep -En "console\.(log|warn|error)\(|print\s*\(|System\.out\.print|println!\(|fmt\.Print" $FILES | grep -v "_test\." | grep -v "test_" | grep -v "\.test\." | head -10

# N9: Negated boolean names
check "N9: No negated boolean names (isNotValid, hasNoErrors)" \
    grep -En "(is|has|can|should|will)(Not|No)[A-Z]" $FILES

# N10: Inconsistent naming (mixed camelCase and snake_case in same file)
warn "N10: Consistent naming style (no mixed camelCase/snake_case)" \
    bash -c "
    for f in $FILES; do
        camel=\$(grep -oE '\b[a-z]+[A-Z][a-zA-Z]*\b' \"\$f\" 2>/dev/null | wc -l)
        snake=\$(grep -oE '\b[a-z]+_[a-z]+\b' \"\$f\" 2>/dev/null | wc -l)
        if [ \"\$camel\" -gt 5 ] && [ \"\$snake\" -gt 5 ]; then
            echo \"\$f: mixed styles (camel: \$camel, snake: \$snake)\"
        fi
    done
    "

echo ""
echo "## MUST Rules (warnings)"

# M1: Boolean variables should have is/has/can/should prefix
warn "M1: Boolean variables should use is/has/can/should prefix" \
    bash -c "
    for f in $FILES; do
        # Find boolean assignments without proper prefix
        grep -En '(const|let|var)\s+[a-z]+\s*=\s*(true|false)\s*;' \"\$f\" 2>/dev/null | \
        grep -vE '(is|has|can|should|will|was|did|does)[A-Z]' | head -3
    done
    "

# M2: Collections should be plural
warn "M2: Arrays/collections should use plural names" \
    bash -c "
    for f in $FILES; do
        # Find array literals or Array() assigned to singular names
        grep -En '(const|let|var)\s+(user|item|order|product|result|file|row|record|entry)\s*=\s*\[' \"\$f\" 2>/dev/null | head -3
    done
    "

# M3: Constants should be UPPER_CASE
warn "M3: Constants should use UPPER_SNAKE_CASE" \
    bash -c "
    for f in $FILES; do
        # Find const with numeric value not in UPPER_CASE
        grep -En 'const\s+[a-z][a-zA-Z]*\s*=\s*[0-9]+\s*;' \"\$f\" 2>/dev/null | \
        grep -vE 'const\s+[A-Z_]+\s*=' | head -3
    done
    "

# M4: Error messages should be descriptive
warn "M4: Error messages should include context" \
    bash -c "
    for f in $FILES; do
        # Find short/generic error messages
        grep -En \"throw.*Error\(['\\\"][^'\\\"]{0,15}['\\\"]|raise.*Exception\(['\\\"][^'\\\"]{0,15}['\\\"]\" \"\$f\" 2>/dev/null | head -3
    done
    "

# M5: Functions should start with verbs
warn "M5: Functions should start with verb" \
    bash -c "
    for f in $FILES; do
        # Find function names that are nouns (no common verb prefix)
        grep -En '^(export\s+)?(async\s+)?function\s+[a-z]+\s*\(' \"\$f\" 2>/dev/null | \
        grep -vE 'function\s+(get|set|fetch|load|save|send|create|update|delete|remove|add|find|check|validate|is|has|can|should|handle|process|render|init|start|stop|on|do|make|build|parse|format|convert|to|from)[A-Z]' | head -3
    done
    "

echo ""
echo "## Info"

# Count potential issues by type
GENERIC_COUNT=$(grep -oE '\b(data|result|temp|info|item|value|obj)\s*=' $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Generic name assignments: ${GENERIC_COUNT:-0}"

BOOL_PREFIX_COUNT=$(grep -oE '\b(is|has|can|should|will|was|did|does)[A-Z][a-zA-Z]*' $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Properly prefixed booleans: ${BOOL_PREFIX_COUNT:-0}"

CONST_UPPER_COUNT=$(grep -oE '\b[A-Z][A-Z_]+\s*=' $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  UPPER_CASE constants: ${CONST_UPPER_COUNT:-0}"

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
