#!/usr/bin/env bash
# =============================================================================
# Flight Validator Test Suite
# =============================================================================
#
# Tests each validator against fixture files containing known violations.
#
# Usage:
#   .flight/tests/run-tests.sh              # Run all tests
#   .flight/tests/run-tests.sh bash         # Run single validator test
#   .flight/tests/run-tests.sh bash yaml    # Run multiple validator tests
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLIGHT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$FLIGHT_DIR")"
FIXTURES_DIR="$PROJECT_DIR/tests/validator-fixtures"

# Find flight-lint
FLIGHT_LINT=""
if [[ -x "$PROJECT_DIR/flight-lint/bin/flight-lint" ]]; then
    FLIGHT_LINT="$PROJECT_DIR/flight-lint/bin/flight-lint"
elif command -v flight-lint &>/dev/null; then
    FLIGHT_LINT="flight-lint"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

# Increment functions that don't fail with set -e
inc_passed() { ((PASSED++)) || true; }
inc_failed() { ((FAILED++)) || true; }
inc_skipped() { ((SKIPPED++)) || true; }

# -----------------------------------------------------------------------------
# Run a single validator test
# -----------------------------------------------------------------------------
run_test() {
    local name="$1"
    local validator="$FLIGHT_DIR/domains/${name}.validate.sh"
    local rules_file="$FLIGHT_DIR/domains/${name}.rules.json"
    local fixture_dir="$FIXTURES_DIR/$name"

    if [[ ! -x "$validator" ]]; then
        echo -e "${YELLOW}SKIP${NC} $name - validator not found"
        inc_skipped
        return 0
    fi

    if [[ ! -d "$fixture_dir" ]]; then
        echo -e "${YELLOW}SKIP${NC} $name - no fixtures"
        inc_skipped
        return 0
    fi

    # Run bash validator against fixtures directory
    export FLIGHT_SEARCH_DIR="$fixture_dir"
    local output
    local exit_code=0
    output=$(timeout 60 "$validator" 2>&1) || exit_code=$?

    # Check for timeout (exit 124)
    if [[ $exit_code -eq 124 ]]; then
        echo -e "${RED}FAIL${NC} $name - TIMEOUT (hung)"
        inc_failed
        return 0  # Continue with other tests
    fi

    # Check for SIGPIPE (exit 141)
    if [[ $exit_code -eq 141 ]]; then
        echo -e "${RED}FAIL${NC} $name - SIGPIPE (exit 141)"
        inc_failed
        return 0  # Continue with other tests
    fi

    # Run flight-lint for AST rules if available and rules file has AST rules
    local ast_fail=0
    local ast_pass=0
    if [[ -n "$FLIGHT_LINT" ]] && [[ -f "$rules_file" ]]; then
        if grep -q '"type": "ast"' "$rules_file" 2>/dev/null; then
            local ast_tmpfile
            ast_tmpfile=$(mktemp)
            # flight-lint scans from current directory, so cd to fixture dir
            # Use temp file to avoid command substitution truncation
            (cd "$fixture_dir" && timeout 60 "$FLIGHT_LINT" "$rules_file" > "$ast_tmpfile" 2>&1) || true
            # Count AST failures (lines with ✗ N error)
            ast_fail=$(grep -oE '✗ [0-9]+ error' "$ast_tmpfile" | grep -oE '[0-9]+' | head -1 || true)
            [[ -z "$ast_fail" ]] && ast_fail=0
            # Append AST output to main output
            local ast_output
            ast_output=$(cat "$ast_tmpfile")
            output="$output"$'\n'"$ast_output"
            rm -f "$ast_tmpfile"
        fi
    fi

    # Parse results from bash validator - ensure numeric results
    local pass fail warn
    pass=$(echo "$output" | grep -oE 'PASS:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 2>/dev/null || true)
    [[ -z "$pass" ]] && pass=0
    fail=$(echo "$output" | grep -oE 'FAIL:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 2>/dev/null || true)
    [[ -z "$fail" ]] && fail=0
    warn=$(echo "$output" | grep -oE 'WARN:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 2>/dev/null || true)
    [[ -z "$warn" ]] && warn=0

    # Add AST results
    pass=$((pass + ast_pass))
    fail=$((fail + ast_fail))

    # Check if we got expected results file
    local expected_file="$fixture_dir/expected.txt"
    if [[ -f "$expected_file" ]]; then
        source "$expected_file"
        local test_passed=true

        if [[ -n "${EXPECT_FAIL:-}" ]] && [[ "$fail" -lt "$EXPECT_FAIL" ]]; then
            echo -e "${RED}FAIL${NC} $name - expected >=$EXPECT_FAIL failures, got $fail"
            test_passed=false
        fi

        if [[ -n "${EXPECT_PASS:-}" ]] && [[ "$pass" -lt "$EXPECT_PASS" ]]; then
            echo -e "${RED}FAIL${NC} $name - expected >=$EXPECT_PASS passes, got $pass"
            test_passed=false
        fi

        if [[ "$test_passed" == true ]]; then
            echo -e "${GREEN}PASS${NC} $name (Pass:$pass Fail:$fail Warn:$warn)"
            inc_passed
        else
            inc_failed
            # Show some failure details (ignore grep exit code)
            echo "$output" | grep -E "^(❌|⚠️)" | head -5 || true
        fi
    else
        # No expected.txt - just verify it ran without hanging
        if [[ "$pass" -gt 0 ]] || [[ "$fail" -gt 0 ]] || [[ "$warn" -gt 0 ]]; then
            echo -e "${GREEN}PASS${NC} $name (Pass:$pass Fail:$fail Warn:$warn)"
            inc_passed
        else
            # Check if it was a skip (no files)
            if echo "$output" | grep -q "SKIP (no files)"; then
                echo -e "${YELLOW}SKIP${NC} $name - no matching files in fixtures"
                inc_skipped
            else
                echo -e "${RED}FAIL${NC} $name - no results (Pass:0 Fail:0 Warn:0)"
                inc_failed
            fi
        fi
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Flight Validator Test Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Get list of validators to test
if [[ $# -gt 0 ]]; then
    VALIDATORS=("$@")
else
    # All validators
    VALIDATORS=()
    for v in "$FLIGHT_DIR"/domains/*.validate.sh; do
        name=$(basename "$v" .validate.sh)
        VALIDATORS+=("$name")
    done
fi

# Run tests
for name in "${VALIDATORS[@]}"; do
    run_test "$name"
done

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "  Passed:  ${GREEN}$PASSED${NC}"
echo -e "  Failed:  ${RED}$FAILED${NC}"
echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
