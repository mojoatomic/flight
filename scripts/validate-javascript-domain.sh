#!/bin/bash
set -euo pipefail

# =============================================================================
# JavaScript Domain Validation Script
# Tests AST-based rules against positive/negative fixtures
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly FLIGHT_LINT_DIR="$PROJECT_ROOT/flight-lint"
readonly FLIGHT_LINT_RUNNER="$SCRIPT_DIR/flight-lint-runner.mjs"
readonly RULES_FILE="$PROJECT_ROOT/.flight/domains/javascript.rules.json"
readonly FIXTURES_DIR="$PROJECT_ROOT/fixtures/javascript"
readonly EXPECTED_FILE="$FIXTURES_DIR/expected/results.json"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() { printf '%s\n' "$*"; }
success() { printf '%b✓ %s%b\n' "$GREEN" "$*" "$NC"; }
fail() { printf '%b✗ %s%b\n' "$RED" "$*" "$NC"; }
warn() { printf '%b⚠ %s%b\n' "$YELLOW" "$*" "$NC"; }
header() { printf '%b═══ %s ═══%b\n' "$BLUE" "$*" "$NC"; }

# Counters
POSITIVE_PASS=0
POSITIVE_FAIL=0
NEGATIVE_PASS=0
NEGATIVE_FAIL=0
FALSE_POSITIVES=()

# -----------------------------------------------------------------------------
# check_prerequisites - Verify flight-lint is built
# -----------------------------------------------------------------------------
check_prerequisites() {
    if [[ ! -d "$FLIGHT_LINT_DIR/dist" ]]; then
        log "Building flight-lint..."
        cd "$FLIGHT_LINT_DIR" || exit 1
        npm run build || {
            fail "Failed to build flight-lint"
            exit 1
        }
        cd "$PROJECT_ROOT" || exit 1
    fi

    if [[ ! -f "$FLIGHT_LINT_RUNNER" ]]; then
        fail "Flight-lint runner not found: $FLIGHT_LINT_RUNNER"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# count_violations - Count violations from flight-lint JSON output
# -----------------------------------------------------------------------------
count_violations() {
    local file="$1"
    local output
    local count=0

    # Run flight-lint runner with JSON format and capture output
    output=$(node "$FLIGHT_LINT_RUNNER" "$RULES_FILE" "$file" --format json 2>&1) || true

    # Parse JSON to count violations
    if command -v jq &>/dev/null; then
        count=$(echo "$output" | jq -r '.summary.total // 0' 2>/dev/null) || count=0
    else
        # Fallback: count "severity" occurrences in JSON
        count=$(echo "$output" | grep -c '"severity"' 2>/dev/null) || count=0
    fi

    echo "$count"
}

# -----------------------------------------------------------------------------
# get_expected_count - Get expected violation count from results.json
# -----------------------------------------------------------------------------
get_expected_count() {
    local file_name="$1"
    local section="$2"

    if command -v jq &>/dev/null; then
        jq -r ".$section.\"$file_name\".expectedViolations // 0" "$EXPECTED_FILE" 2>/dev/null || echo "0"
    else
        # Fallback: grep for the expected count
        grep -A5 "\"$file_name\"" "$EXPECTED_FILE" | grep "expectedViolations" | grep -oE '[0-9]+' | head -1 || echo "0"
    fi
}

# -----------------------------------------------------------------------------
# test_positive_fixtures - Test files that SHOULD have violations
# -----------------------------------------------------------------------------
test_positive_fixtures() {
    header "Testing Positive Fixtures (expect violations)"
    log ""

    local total_expected=0
    local total_found=0

    for file in "$FIXTURES_DIR/positive/"*.js; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local file_name
        file_name=$(basename "$file")
        local expected
        expected=$(get_expected_count "$file_name" "positive")
        local found
        found=$(count_violations "$file")

        total_expected=$((total_expected + expected))
        total_found=$((total_found + found))

        if [[ "$found" -gt 0 ]]; then
            if [[ "$found" -eq "$expected" ]]; then
                success "$file_name: $found violations (expected $expected)"
                POSITIVE_PASS=$((POSITIVE_PASS + 1))
            else
                warn "$file_name: $found violations (expected $expected)"
                POSITIVE_PASS=$((POSITIVE_PASS + 1))
            fi
        else
            fail "$file_name: 0 violations (expected $expected)"
            POSITIVE_FAIL=$((POSITIVE_FAIL + 1))
        fi
    done

    log ""
    log "Positive fixtures total: $total_found found / $total_expected expected"
}

# -----------------------------------------------------------------------------
# test_negative_fixtures - Test files that should have ZERO violations
# -----------------------------------------------------------------------------
test_negative_fixtures() {
    header "Testing Negative Fixtures (expect ZERO violations)"
    log ""

    for file in "$FIXTURES_DIR/negative/"*.js; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local file_name
        file_name=$(basename "$file")
        local found
        found=$(count_violations "$file")

        if [[ "$found" -eq 0 ]]; then
            success "$file_name: 0 violations (as expected)"
            NEGATIVE_PASS=$((NEGATIVE_PASS + 1))
        else
            fail "$file_name: $found violations (FALSE POSITIVE!)"
            NEGATIVE_FAIL=$((NEGATIVE_FAIL + 1))
            FALSE_POSITIVES+=("$file_name:$found")
        fi
    done
}

# -----------------------------------------------------------------------------
# print_summary - Print test summary
# -----------------------------------------------------------------------------
print_summary() {
    log ""
    header "Validation Summary"
    log ""
    log "Positive fixtures (should find violations):"
    log "  Pass: $POSITIVE_PASS"
    log "  Fail: $POSITIVE_FAIL"
    log ""
    log "Negative fixtures (should find ZERO violations):"
    log "  Pass: $NEGATIVE_PASS"
    log "  Fail: $NEGATIVE_FAIL"
    log ""

    if [[ ${#FALSE_POSITIVES[@]} -gt 0 ]]; then
        fail "FALSE POSITIVES DETECTED:"
        for fp in "${FALSE_POSITIVES[@]}"; do
            log "  - $fp"
        done
        log ""
    fi
}

# -----------------------------------------------------------------------------
# main - Main entry point
# -----------------------------------------------------------------------------
main() {
    header "JavaScript Domain Validation"
    log ""

    # Verify prerequisites
    if [[ ! -f "$RULES_FILE" ]]; then
        fail "Rules file not found: $RULES_FILE"
        exit 1
    fi

    if [[ ! -d "$FIXTURES_DIR/positive" ]] || [[ ! -d "$FIXTURES_DIR/negative" ]]; then
        fail "Fixtures directories not found"
        exit 1
    fi

    # Check prerequisites
    check_prerequisites

    # Run tests
    test_positive_fixtures
    log ""
    test_negative_fixtures

    # Print summary
    print_summary

    # Exit status based on false positives
    if [[ "$NEGATIVE_FAIL" -gt 0 ]]; then
        fail "VALIDATION FAILED: ${#FALSE_POSITIVES[@]} false positive(s) detected"
        exit 1
    elif [[ "$POSITIVE_FAIL" -gt 0 ]]; then
        warn "VALIDATION WARNING: Some positive fixtures not detecting expected violations"
        exit 0
    else
        success "VALIDATION PASSED: Zero false positives"
        exit 0
    fi
}

main "$@"
