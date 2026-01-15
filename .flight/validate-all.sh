#!/bin/bash
set -euo pipefail

# =============================================================================
# Flight Validator Runner
# Auto-detects which domain validators to run based on file extensions
#
# Usage:
#   .flight/validate-all.sh                    # Scan current directory
#   .flight/validate-all.sh src                # Scan src/ only
#   .flight/validate-all.sh packages/app lib   # Scan multiple directories
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAINS_DIR="$SCRIPT_DIR/domains"

# Source exclusions helper
if [[ -f "$SCRIPT_DIR/exclusions.sh" ]]; then
    source "$SCRIPT_DIR/exclusions.sh"
    HAS_EXCLUSIONS=true
else
    HAS_EXCLUSIONS=false
fi

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
# Collect files
# -----------------------------------------------------------------------------

# Determine search paths
if [[ $# -gt 0 ]]; then
    SEARCH_PATHS=("$@")
else
    SEARCH_PATHS=(".")
fi

echo -e "${BLUE}Scanning:${NC} ${SEARCH_PATHS[*]}"

# Collect all files with exclusions
collect_files() {
    local pattern="$1"
    local files=""

    for search_path in "${SEARCH_PATHS[@]}"; do
        if [[ -d "$search_path" ]]; then
            if [[ "$HAS_EXCLUSIONS" == true ]]; then
                # Use exclusions-aware discovery
                local found
                found=$(FLIGHT_SEARCH_DIR="$search_path" flight_get_files "$pattern")
                if [[ -n "$found" ]]; then
                    files="$files $found"
                fi
            else
                # Fallback: basic find
                local found
                found=$(find "$search_path" -name "$pattern" -type f 2>/dev/null | tr '\n' ' ')
                files="$files $found"
            fi
        elif [[ -f "$search_path" ]]; then
            # Direct file argument
            if [[ "$search_path" == *"$pattern"* ]] || [[ "$pattern" == "*" ]]; then
                files="$files $search_path"
            fi
        fi
    done

    echo "$files" | tr ' ' '\n' | (grep -v '^$' || true) | sort -u | tr '\n' ' '
}

# Collect files by type
TS_FILES=$(collect_files "*.ts")
TSX_FILES=$(collect_files "*.tsx")
JS_FILES=$(collect_files "*.js")
JSX_FILES=$(collect_files "*.jsx")
PY_FILES=$(collect_files "*.py")
SH_FILES=$(collect_files "*.sh")
SQL_FILES=$(collect_files "*.sql")
GO_FILES=$(collect_files "*.go")
RS_FILES=$(collect_files "*.rs")

# Combine related file types
TYPESCRIPT_FILES="$TS_FILES $TSX_FILES"
JAVASCRIPT_FILES="$JS_FILES $JSX_FILES"
REACT_FILES="$TSX_FILES $JSX_FILES"
ALL_CODE_FILES="$TYPESCRIPT_FILES $JAVASCRIPT_FILES $PY_FILES $SH_FILES $SQL_FILES $GO_FILES $RS_FILES"

# Count files
count_files() {
    local count
    count=$(echo "$1" | tr ' ' '\n' | grep -cv '^$' 2>/dev/null) || count=0
    echo "$count"
}

TOTAL_FILES=$(count_files "$ALL_CODE_FILES")
echo -e "${BLUE}Total files:${NC} $TOTAL_FILES"
echo ""

if [[ "$TOTAL_FILES" -eq 0 ]]; then
    echo -e "${YELLOW}No code files found in search paths${NC}"
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Run a validator if files exist
# -----------------------------------------------------------------------------

run_validator() {
    local domain="$1"
    local files="$2"
    local validator="$DOMAINS_DIR/${domain}.validate.sh"

    # Trim whitespace and check if empty
    files=$(echo "$files" | xargs)
    if [[ -z "$files" ]]; then
        return 0
    fi

    # Skip if validator doesn't exist
    if [[ ! -x "$validator" ]]; then
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
    if [[ "$exit_code" -ne 0 ]] || [[ "$fail" -gt 0 ]]; then
        echo -e "${RED}✗ $domain: FAIL (Pass: $pass, Fail: $fail, Warn: $warn)${NC}"
        FAILED_DOMAINS+=("$domain")
        # Show failure details
        echo "$output" | grep -E "(❌|ERROR)" | head -10
        echo ""
    else
        echo -e "${GREEN}✓ $domain: PASS (Pass: $pass, Fail: $fail, Warn: $warn)${NC}"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Always run code-hygiene (applies to all code)
# -----------------------------------------------------------------------------

run_validator "code-hygiene" "$ALL_CODE_FILES"

# -----------------------------------------------------------------------------
# Run language/framework specific validators
# -----------------------------------------------------------------------------

# TypeScript
run_validator "typescript" "$TYPESCRIPT_FILES"

# JavaScript
run_validator "javascript" "$JAVASCRIPT_FILES"

# React (TSX/JSX files)
run_validator "react" "$REACT_FILES"

# Python
run_validator "python" "$PY_FILES"

# Bash
run_validator "bash" "$SH_FILES"

# SQL
run_validator "sql" "$SQL_FILES"

# Go
run_validator "go" "$GO_FILES"

# Rust
run_validator "rust" "$RS_FILES"

# -----------------------------------------------------------------------------
# Check for pattern-based validators
# -----------------------------------------------------------------------------

# API files (by naming convention)
API_FILES=$(echo "$ALL_CODE_FILES" | tr ' ' '\n' | grep -iE '(api|service|fetch|endpoint|route)' | tr '\n' ' ' || echo "")
run_validator "api" "$API_FILES"

# Test files
TEST_FILES=$(echo "$ALL_CODE_FILES" | tr ' ' '\n' | grep -E '\.(test|spec)\.' | tr '\n' ' ' || echo "")
run_validator "testing" "$TEST_FILES"

# Webhook files
WEBHOOK_FILES=$(echo "$ALL_CODE_FILES" | tr ' ' '\n' | grep -iE 'webhook' | tr '\n' ' ' || echo "")
run_validator "webhooks" "$WEBHOOK_FILES"

# SMS/Twilio files
SMS_FILES=$(echo "$ALL_CODE_FILES" | tr ' ' '\n' | grep -iE '(sms|twilio|message)' | tr '\n' ' ' || echo "")
run_validator "sms-twilio" "$SMS_FILES"

# Prisma files
PRISMA_FILES=$(echo "$TYPESCRIPT_FILES" | tr ' ' '\n' | grep -iE '(prisma|\.server\.|/api/|/actions/)' | tr '\n' ' ' || echo "")
run_validator "prisma" "$PRISMA_FILES"

# Clerk files
CLERK_FILES=$(echo "$TYPESCRIPT_FILES" | tr ' ' '\n' | grep -iE '(clerk|auth|middleware)' | tr '\n' ' ' || echo "")
run_validator "clerk" "$CLERK_FILES"

# Supabase files
SUPABASE_FILES=$(echo "$TYPESCRIPT_FILES" | tr ' ' '\n' | grep -iE 'supabase' | tr '\n' ' ' || echo "")
run_validator "supabase" "$SUPABASE_FILES"

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

if [[ ${#FAILED_DOMAINS[@]} -gt 0 ]]; then
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}  Failed domains: ${FAILED_DOMAINS[*]}${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
    echo ""
    exit 0
fi
