#!/bin/bash
set -euo pipefail

# =============================================================================
# Flight Validator Runner
# Auto-detects which domain validators to run based on file extensions
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAINS_DIR="$SCRIPT_DIR/domains"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0
FAILED_DOMAINS=()

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Flight Validation Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# -----------------------------------------------------------------------------
# Collect files by type
# -----------------------------------------------------------------------------

# Get files to validate (from args, or find all in src/)
if [ $# -gt 0 ]; then
    ALL_FILES="$*"
else
    ALL_FILES=$(find src -type f \( \
        -name "*.ts" -o \
        -name "*.tsx" -o \
        -name "*.js" -o \
        -name "*.jsx" -o \
        -name "*.py" -o \
        -name "*.sh" -o \
        -name "*.sql" \
    \) 2>/dev/null | tr '\n' ' ' || echo "")
fi

# Filter files by extension
filter_files() {
    local pattern="$1"
    echo "$ALL_FILES" | tr ' ' '\n' | grep -E "$pattern" | tr '\n' ' ' || echo ""
}

TS_FILES=$(filter_files '\.(ts|tsx)$')
JS_FILES=$(filter_files '\.(js|jsx)$')
REACT_FILES=$(filter_files '\.(tsx|jsx)$')
PY_FILES=$(filter_files '\.py$')
SH_FILES=$(filter_files '\.sh$')
SQL_FILES=$(filter_files '\.sql$')

# -----------------------------------------------------------------------------
# Run a validator if files exist
# -----------------------------------------------------------------------------

run_validator() {
    local domain="$1"
    local files="$2"
    local validator="$DOMAINS_DIR/${domain}.validate.sh"

    # Skip if no files
    if [ -z "$files" ] || [ "$files" = " " ]; then
        return 0
    fi

    # Skip if validator doesn't exist
    if [ ! -x "$validator" ]; then
        echo -e "${YELLOW}⚠ Skipping $domain (no validator found)${NC}"
        return 0
    fi

    echo -e "${BLUE}▶ Running $domain validator...${NC}"

    # Run validator and capture output
    local output
    local exit_code=0
    output=$("$validator" $files 2>&1) || exit_code=$?

    # Parse results from output
    local pass=$(echo "$output" | grep -oE 'PASS:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 || echo "0")
    local fail=$(echo "$output" | grep -oE 'FAIL:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 || echo "0")
    local warn=$(echo "$output" | grep -oE 'WARN:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1 || echo "0")

    # Default to 0 if empty
    pass=${pass:-0}
    fail=${fail:-0}
    warn=${warn:-0}

    # Update totals
    TOTAL_PASS=$((TOTAL_PASS + pass))
    TOTAL_FAIL=$((TOTAL_FAIL + fail))
    TOTAL_WARN=$((TOTAL_WARN + warn))

    # Check result
    if [ "$exit_code" -ne 0 ] || [ "$fail" -gt 0 ]; then
        echo -e "${RED}✗ $domain: FAIL (Pass: $pass, Fail: $fail, Warn: $warn)${NC}"
        FAILED_DOMAINS+=("$domain")
        # Show failure details
        echo "$output" | grep -E "(FAIL|ERROR|✗)" | head -10
        echo ""
    else
        echo -e "${GREEN}✓ $domain: PASS (Pass: $pass, Fail: $fail, Warn: $warn)${NC}"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Always run code-hygiene (applies to all code)
# -----------------------------------------------------------------------------

if [ -n "$ALL_FILES" ] && [ "$ALL_FILES" != " " ]; then
    run_validator "code-hygiene" "$ALL_FILES"
fi

# -----------------------------------------------------------------------------
# Run language/framework specific validators
# -----------------------------------------------------------------------------

# TypeScript
if [ -n "$TS_FILES" ]; then
    run_validator "typescript" "$TS_FILES"
fi

# JavaScript (if you have a js validator)
if [ -n "$JS_FILES" ]; then
    run_validator "javascript" "$JS_FILES"
fi

# React (TSX/JSX files)
if [ -n "$REACT_FILES" ]; then
    run_validator "react" "$REACT_FILES"
fi

# Python
if [ -n "$PY_FILES" ]; then
    run_validator "python" "$PY_FILES"
fi

# Bash
if [ -n "$SH_FILES" ]; then
    run_validator "bash" "$SH_FILES"
fi

# SQL
if [ -n "$SQL_FILES" ]; then
    run_validator "sql" "$SQL_FILES"
fi

# -----------------------------------------------------------------------------
# Check for API-related files
# -----------------------------------------------------------------------------

API_FILES=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -iE '(api|service|fetch|endpoint)' | tr '\n' ' ' || echo "")
if [ -n "$API_FILES" ] && [ "$API_FILES" != " " ]; then
    run_validator "api" "$API_FILES"
fi

# -----------------------------------------------------------------------------
# Check for test files
# -----------------------------------------------------------------------------

TEST_FILES=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -E '\.(test|spec)\.(ts|tsx|js|jsx)$' | tr '\n' ' ' || echo "")
if [ -n "$TEST_FILES" ] && [ "$TEST_FILES" != " " ]; then
    run_validator "testing" "$TEST_FILES"
fi

# -----------------------------------------------------------------------------
# Check for webhook files
# -----------------------------------------------------------------------------

WEBHOOK_FILES=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -iE 'webhook' | tr '\n' ' ' || echo "")
if [ -n "$WEBHOOK_FILES" ] && [ "$WEBHOOK_FILES" != " " ]; then
    run_validator "webhooks" "$WEBHOOK_FILES"
fi

# -----------------------------------------------------------------------------
# Check for SMS/Twilio files
# -----------------------------------------------------------------------------

SMS_FILES=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -iE '(sms|twilio|message)' | tr '\n' ' ' || echo "")
if [ -n "$SMS_FILES" ] && [ "$SMS_FILES" != " " ]; then
    run_validator "sms-twilio" "$SMS_FILES"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Validation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "  Total Checks Passed: ${GREEN}$TOTAL_PASS${NC}"
echo -e "  Total Checks Failed: ${RED}$TOTAL_FAIL${NC}"
echo -e "  Total Warnings:      ${YELLOW}$TOTAL_WARN${NC}"
echo ""

if [ ${#FAILED_DOMAINS[@]} -gt 0 ]; then
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}  Failed domains: ${FAILED_DOMAINS[*]}${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
    echo ""
    exit 0
fi
