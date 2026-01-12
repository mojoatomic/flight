#!/bin/bash
# testing.validate.sh - Unit test quality validation
set -uo pipefail  # Note: -e omitted intentionally - grep returns 1 when no violations found

# Default: common test file patterns across languages
DEFAULT_PATTERNS="**/*test*.js **/*spec*.js **/*_test.py **/test_*.py **/*_test.go **/Test*.java"
PASS=0
FAIL=0
WARN=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        printf '%s\n' "$result" | head -10 | sed 's/^/   /'
        ((FAIL++))
    fi
}

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        yellow "⚠️  $name"
        printf '%s\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++))
    fi
}

printf '%s\n' "═══════════════════════════════════════════"
printf '%s\n' "  Testing Domain Validation"
printf '%s\n' "═══════════════════════════════════════════"
printf '\n'

# Handle arguments or use defaults
if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    # Expand default patterns
    shopt -s nullglob globstar
    FILES=($DEFAULT_PATTERNS)
    shopt -u nullglob globstar
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    yellow "No test files found matching: $DEFAULT_PATTERNS"
    printf '%s\n' "  Patterns checked: *test*.js, *spec*.js, *_test.py, test_*.py, *_test.go, Test*.java"
    printf '\n'
    green "  RESULT: SKIP (no test files)"
    exit 0
fi

printf 'Test files: %d\n\n' "${#FILES[@]}"

printf '%s\n' "## NEVER Rules"

# N1: Enumerated test names (test1, test2, testA)
check "N1: No enumerated test names (test1, test2)" \
    grep -En "test\(['\"]test[0-9]|it\(['\"][0-9]|def test[0-9]+|func Test[0-9]+\(" "${FILES[@]}"

# N2: Empty test bodies (JS, Python, Go, Java)
check "N2: No empty test bodies" \
    grep -En "it\([^)]+,\s*\(\)\s*=>\s*\{\s*\}\)|it\(['\"]['\"],|def test[^:]+:\s*pass$|func Test[^{]+\{\s*\}|@Test[^{]+\{\s*\}" "${FILES[@]}"

# N3: Hardcoded sleep/delays (expanded patterns)
check "N3: No hardcoded sleep/delays in tests" \
    grep -En "sleep\s*\(|time\.sleep|Thread\.sleep|\.sleep\(|usleep|nanosleep|await\s+new\s+Promise.*setTimeout" "${FILES[@]}"

# N4: Testing private methods
check "N4: No testing private methods directly" \
    grep -En "expect\([^)]*\._[a-z]|assert.*\._[a-z]|expect\([^)]*\.__" "${FILES[@]}"

# N5: Shared mutable state (beforeAll with let)
warn "N5: Potential shared mutable state (beforeAll + mutable let)" \
    grep -l "beforeAll" "${FILES[@]}" 2>/dev/null | xargs -I{} sh -c 'grep -l "^let\s" "{}" 2>/dev/null && echo "{}: has beforeAll with top-level let"'

# N6: Unawaited async assertions (.then with expect/assert)
check "N6: No unawaited assertions in async tests" \
    grep -En "\.then\s*\(\s*[^)]*expect|\.then\s*\(\s*[^)]*assert" "${FILES[@]}"

# N7: Try-catch swallowing test failures (catch followed by expect within 5 lines)
warn "N7: Potential try-catch swallowing (expect in catch block)" \
    bash -c 'for f in "$@"; do
        if grep -q "catch\s*(" "$f" 2>/dev/null; then
            match=$(grep -A5 "catch\s*(" "$f" | grep -E "expect|assert" | grep -v "toThrow\|rejects")
            if [[ -n "$match" ]]; then
                echo "$f: catch block contains assertions - verify not swallowing"
            fi
        fi
    done' _ "${FILES[@]}"

printf '\n%s\n' "## MUST Rules"

# M1: Test names should be descriptive (only flag truly useless names)
warn "M1: Test names should be descriptive (no 'test', 'works', 'it')" \
    grep -En "test\(['\"]test['\"]|test\(['\"]works['\"]|it\(['\"]it['\"]|it\(['\"]test['\"]" "${FILES[@]}"

printf '\n%s\n' "## SHOULD Rules"

# S1: Logic in tests (if/for/while statements)
warn "S1: Avoid logic in tests (if/for/while in test body)" \
    grep -En "^\s+(if|for|while)\s*\(" "${FILES[@]}" | grep -v "forEach\|test\.each\|pytest\.mark"

printf '\n%s\n' "## Info"

NULL_TESTS=$(grep -l "null\|undefined\|None\|nil" "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
printf 'ℹ️  Files testing null/undefined: %s\n' "$NULL_TESTS"

EMPTY_TESTS=$(grep -l "empty\|\.length.*0\|\.size.*0" "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
printf 'ℹ️  Files testing empty cases: %s\n' "$EMPTY_TESTS"

ERROR_TESTS=$(grep -l "throw\|raise\|Error\|Exception" "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
printf 'ℹ️  Files testing error paths: %s\n' "$ERROR_TESTS"

DESCRIBE_COUNT=$(grep -c "describe\|Describe\|Context" "${FILES[@]}" 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')
printf 'ℹ️  Describe/Context blocks: %s\n' "$DESCRIBE_COUNT"

TEST_COUNT=$(grep -cE "(it\(|test\(|def test_|func Test|@Test)" "${FILES[@]}" 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')
printf 'ℹ️  Test cases: %s\n' "$TEST_COUNT"

AAA_COUNT=$(grep -c "// Arrange\|# Arrange\|// Act\|# Act\|// Assert\|# Assert" "${FILES[@]}" 2>/dev/null | awk -F: '{s+=$NF}END{print s+0}')
printf 'ℹ️  AAA comments found: %s\n' "$AAA_COUNT"

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
