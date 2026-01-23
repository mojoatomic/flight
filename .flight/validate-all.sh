#!/usr/bin/env bash
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
CONFIG_FILE="$SCRIPT_DIR/flight.json"

# -----------------------------------------------------------------------------
# Config-driven mode: read enabled domains from flight.json
# -----------------------------------------------------------------------------

if [[ -f "$CONFIG_FILE" ]]; then
    ENABLED_DOMAINS=$(jq -r '.enabled_domains[]' "$CONFIG_FILE" 2>/dev/null || echo "")
    CONFIG_MODE=true
    if [[ -z "$ENABLED_DOMAINS" ]]; then
        echo "Warning: flight.json exists but enabled_domains is empty or invalid" >&2
        CONFIG_MODE=false
    fi
else
    CONFIG_MODE=false
fi

# Source exclusions helper (required - ships with validate-all.sh)
if [[ -f "$SCRIPT_DIR/exclusions.sh" ]]; then
    source "$SCRIPT_DIR/exclusions.sh"
else
    # Define minimal exclusions inline if file missing (shouldn't happen)
    FLIGHT_EXCLUDE_DIRS=(
        "node_modules" "vendor" ".venv" "venv"
        "dist" "build" "target" "obj" "out" ".output"
        ".next" ".turbo" ".nuxt" ".svelte-kit"
        ".git" ".idea" ".vscode"
        "coverage" ".nyc_output" "__pycache__" ".pytest_cache" ".tox" ".nox"
        ".cache" ".parcel-cache" ".webpack" ".rollup.cache"
        ".terraform" ".serverless" ".flight/examples"
    )
    flight_build_find_not_paths() {
        local dir
        for dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
            printf ' -not -path "*/%s/*"' "$dir"
        done
    }
    flight_get_files() {
        local patterns=("$@")
        local search_dir="${FLIGHT_SEARCH_DIR:-.}"
        local exclude_args
        exclude_args=$(flight_build_find_not_paths)
        for pattern in "${patterns[@]}"; do
            pattern="${pattern#\*\*/}"
            eval "find \"$search_dir\" -type f -name \"$pattern\" $exclude_args 2>/dev/null"
        done | sort -u
    }
fi
HAS_EXCLUSIONS=true  # Always true now - either sourced or defined inline

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

# -----------------------------------------------------------------------------
# Check if a domain is enabled (config-driven or legacy mode)
# -----------------------------------------------------------------------------

is_domain_enabled() {
    local domain="$1"
    if [[ "$CONFIG_MODE" == false ]]; then
        return 0  # Legacy mode - all domains enabled
    fi
    echo "$ENABLED_DOMAINS" | grep -qw "$domain"
}

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Flight Validation Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
if [[ "$CONFIG_MODE" == true ]]; then
    echo -e "${GREEN}Mode: Config-driven (flight.json)${NC}"
else
    echo -e "${YELLOW}Mode: Legacy (no flight.json)${NC}"
fi
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
            # Use exclusions-aware discovery (always available)
            local found
            found=$(FLIGHT_SEARCH_DIR="$search_path" flight_get_files "$pattern")
            if [[ -n "$found" ]]; then
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
C_FILES=$(collect_files "*.c")
H_FILES=$(collect_files "*.h")

# Combine related file types
TYPESCRIPT_FILES="$TS_FILES $TSX_FILES"
JAVASCRIPT_FILES="$JS_FILES $JSX_FILES"
REACT_FILES="$TSX_FILES $JSX_FILES"
C_CODE_FILES="$C_FILES $H_FILES"
ALL_CODE_FILES="$TYPESCRIPT_FILES $JAVASCRIPT_FILES $PY_FILES $SH_FILES $SQL_FILES $GO_FILES $RS_FILES $C_CODE_FILES"

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
# Get files for a specific domain based on file type mapping
# -----------------------------------------------------------------------------

get_domain_files() {
    local domain="$1"
    case "$domain" in
        typescript)     echo "$TYPESCRIPT_FILES" ;;
        react)          echo "$REACT_FILES" ;;
        javascript)     echo "$JAVASCRIPT_FILES" ;;
        bash)           echo "$SH_FILES" ;;
        python)         echo "$PY_FILES" ;;
        go)             echo "$GO_FILES" ;;
        rust)           echo "$RS_FILES" ;;
        sql)            echo "$SQL_FILES" ;;
        # C/embedded domains
        rp2040-pico)    echo "$C_CODE_FILES" ;;
        embedded-c-p10) echo "$C_CODE_FILES" ;;
        # Domains that check multiple/all file types
        code-hygiene)   echo "$ALL_CODE_FILES" ;;
        api)            echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES" ;;
        nextjs)         echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES" ;;
        supabase)       echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES" ;;
        prisma)         echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES" ;;
        clerk)          echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES" ;;
        sms-twilio)     echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES $PY_FILES" ;;
        testing)        echo "$ALL_CODE_FILES" ;;
        webhooks)       echo "$TYPESCRIPT_FILES $JAVASCRIPT_FILES $PY_FILES" ;;
        docker)         echo "" ;;  # Dockerfile patterns - needs special handling
        kubernetes)     echo "" ;;  # YAML patterns - needs special handling
        yaml)           echo "" ;;  # YAML patterns - needs special handling
        *)              echo "$ALL_CODE_FILES" ;;
    esac
}

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
        # Show failure details with file:line violations (strip color codes for matching)
        echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^(❌|   )" | head -30
        echo ""
    elif [[ "$warn" -gt 0 ]]; then
        echo -e "${GREEN}✓ $domain: PASS (Pass: $pass, Fail: $fail, Warn: ${YELLOW}$warn${NC}${GREEN})${NC}"
        # Show warning details
        echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^(⚠️|   )" | head -20
    else
        echo -e "${GREEN}✓ $domain: PASS (Pass: $pass, Fail: $fail, Warn: $warn)${NC}"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Run validators for enabled domains
# -----------------------------------------------------------------------------

if [[ "$CONFIG_MODE" == true ]]; then
    # Config-driven: loop over enabled domains from flight.json
    for domain in $ENABLED_DOMAINS; do
        run_validator "$domain" "$(get_domain_files "$domain")"
    done
else
    # Legacy mode: no flight.json found
    echo -e "${YELLOW}No flight.json found. Run /flight-scan to detect domains.${NC}"
    echo -e "${YELLOW}Falling back to code-hygiene only...${NC}"
    echo ""
    run_validator "code-hygiene" "$(get_domain_files "code-hygiene")"
fi

# -----------------------------------------------------------------------------
# AST-based validation (flight-lint)
# -----------------------------------------------------------------------------

# Find flight-lint relative to this script (supports both dev and installed)
FLIGHT_LINT=""
if [[ -x "$SCRIPT_DIR/../flight-lint/bin/flight-lint" ]]; then
    FLIGHT_LINT="$SCRIPT_DIR/../flight-lint/bin/flight-lint"
elif command -v flight-lint &>/dev/null; then
    FLIGHT_LINT="flight-lint"
fi

# Check if any .rules.json files have AST rules
has_ast_rules() {
    local rules_dir="$SCRIPT_DIR/domains"
    if [[ -d "$rules_dir" ]]; then
        grep -l '"type": "ast"' "$rules_dir"/*.rules.json 2>/dev/null | head -1
    fi
}

if [[ -n "$FLIGHT_LINT" ]]; then
    AST_RULES_FILE=$(has_ast_rules)
    if [[ -n "$AST_RULES_FILE" ]]; then
        echo ""
        echo -e "${BLUE}▶ Running AST validation (flight-lint)...${NC}"

        # Run flight-lint with auto-discovery
        LINT_OUTPUT=$("$FLIGHT_LINT" --auto --severity SHOULD 2>&1) || LINT_EXIT=$?
        LINT_EXIT=${LINT_EXIT:-0}

        # Parse flight-lint output for error/warning counts
        # Format: "✗ N error(s)" and "⚠ N warning(s)"
        AST_ERRORS=$(echo "$LINT_OUTPUT" | grep -oE '✗ [0-9]+ error' | grep -oE '[0-9]+' | head -1 || echo "0")
        AST_WARNINGS=$(echo "$LINT_OUTPUT" | grep -oE '⚠ [0-9]+ warning' | grep -oE '[0-9]+' | head -1 || echo "0")
        AST_ERRORS=${AST_ERRORS:-0}
        AST_WARNINGS=${AST_WARNINGS:-0}

        # Exit code 2 = config error (missing parser, etc) - treat as warning not failure
        if [[ "$LINT_EXIT" -eq 2 ]]; then
            echo -e "${YELLOW}⚠ AST validation: CONFIG ERROR${NC}"
            echo "$LINT_OUTPUT" | grep -E "^Error:" | head -5
            echo -e "${YELLOW}  Some AST rules may have been skipped${NC}"
        elif [[ "$LINT_EXIT" -ne 0 ]] || [[ "$AST_ERRORS" -gt 0 ]]; then
            echo -e "${RED}✗ AST validation: FAIL (Errors: $AST_ERRORS, Warnings: $AST_WARNINGS)${NC}"
            echo "$LINT_OUTPUT" | grep -E "^\s+[0-9]+:[0-9]+\s+(NEVER|MUST)" | head -20
            TOTAL_FAIL=$((TOTAL_FAIL + AST_ERRORS))
            FAILED_DOMAINS+=("ast-lint")
        elif [[ "$AST_WARNINGS" -gt 0 ]]; then
            echo -e "${GREEN}✓ AST validation: PASS (Errors: 0, Warnings: ${YELLOW}$AST_WARNINGS${NC}${GREEN})${NC}"
            TOTAL_WARN=$((TOTAL_WARN + AST_WARNINGS))
        else
            echo -e "${GREEN}✓ AST validation: PASS${NC}"
        fi
    fi
elif [[ -n "$(has_ast_rules)" ]]; then
    echo ""
    echo -e "${YELLOW}⚠ AST rules detected but flight-lint not found${NC}"
    echo -e "${YELLOW}  Build flight-lint: cd flight-lint && npm install && npm run build${NC}"
    echo -e "${YELLOW}  AST rules will be skipped until flight-lint is available${NC}"
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
