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
#   .flight/validate-all.sh --update-baseline  # Accept current warnings as baseline
#
# Baseline Ratchet:
#   Prevents warning count from increasing. New projects start at 0.
#   Use --update-baseline to accept a new warning count (e.g., after brownfield import).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/baseline.json"

# -----------------------------------------------------------------------------
# Flag handling
# -----------------------------------------------------------------------------
UPDATE_BASELINE=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --update-baseline)
            UPDATE_BASELINE=true
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Reset positional parameters to non-flag arguments
set -- "${ARGS[@]+"${ARGS[@]}"}"

# -----------------------------------------------------------------------------
# Baseline functions
# -----------------------------------------------------------------------------

load_baseline() {
    if [[ -f "$BASELINE_FILE" ]]; then
        jq -r '.warnings // 0' "$BASELINE_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

save_baseline() {
    local warnings="$1"
    local date
    date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$BASELINE_FILE" << EOF
{
  "warnings": $warnings,
  "updated": "$date",
  "note": "Baseline for warning ratchet. Validation fails if warnings exceed this count."
}
EOF
    echo "Baseline updated: $warnings warnings"
}

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
# Search path configuration
# -----------------------------------------------------------------------------

# Determine search paths (validators use FLIGHT_SEARCH_DIR from exclusions.sh)
if [[ $# -gt 0 ]]; then
    # Export for validators to use
    export FLIGHT_SEARCH_DIR="$1"
    echo -e "${BLUE}Scanning:${NC} $*"
else
    export FLIGHT_SEARCH_DIR="."
    echo -e "${BLUE}Scanning:${NC} current directory"
fi
echo ""

# -----------------------------------------------------------------------------
# Run a validator (self-discovers files via file_patterns from .flight)
# -----------------------------------------------------------------------------

run_validator() {
    local domain="$1"
    local validator="$DOMAINS_DIR/${domain}.validate.sh"

    # Skip if validator doesn't exist
    if [[ ! -x "$validator" ]]; then
        return 0
    fi

    echo -e "${BLUE}▶ Running $domain validator...${NC}"

    # Run validator - it self-discovers files via file_patterns from .flight
    local output
    local exit_code=0
    output=$("$validator" 2>&1) || exit_code=$?

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
        run_validator "$domain"
    done
else
    # Legacy mode: no flight.json found
    echo -e "${YELLOW}No flight.json found. Run /flight-scan to detect domains.${NC}"
    echo -e "${YELLOW}Falling back to code-hygiene only...${NC}"
    echo ""
    run_validator "code-hygiene"
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

# -----------------------------------------------------------------------------
# Baseline ratchet check
# -----------------------------------------------------------------------------

BASELINE=$(load_baseline)
echo -e "  Warning Baseline:    ${BLUE}$BASELINE${NC}"
echo ""

# Handle --update-baseline flag
if [[ "$UPDATE_BASELINE" == true ]]; then
    save_baseline "$TOTAL_WARN"
    BASELINE="$TOTAL_WARN"
fi

# Check for domain failures first (NEVER/MUST violations)
if [[ ${#FAILED_DOMAINS[@]} -gt 0 ]]; then
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}  Failed domains: ${FAILED_DOMAINS[*]}${NC}"
    echo ""
    exit 1
fi

# Check warning ratchet (warnings cannot exceed baseline)
if [[ "$TOTAL_WARN" -gt "$BASELINE" ]]; then
    NEW_WARNINGS=$((TOTAL_WARN - BASELINE))
    echo -e "${RED}✗ VALIDATION FAILED - Warning ratchet exceeded${NC}"
    echo -e "${RED}  Current warnings: $TOTAL_WARN (baseline: $BASELINE, +$NEW_WARNINGS new)${NC}"
    echo ""
    echo -e "${YELLOW}  For greenfield projects: Fix the warnings to maintain zero baseline.${NC}"
    echo -e "${YELLOW}  For brownfield imports: Run with --update-baseline to accept current count.${NC}"
    echo ""
    exit 1
fi

# All passed
if [[ "$TOTAL_WARN" -gt 0 ]]; then
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC} (within baseline: $TOTAL_WARN ≤ $BASELINE)"
else
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
fi
echo ""
exit 0
