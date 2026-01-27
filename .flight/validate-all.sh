#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Flight Validator Runner
# Runs flight-lint for all validation (AST and grep rules from .rules.json)
#
# Usage:
#   .flight/validate-all.sh                    # Validate codebase
#   .flight/validate-all.sh --update-baseline  # Accept current warnings as baseline
#
# Baseline Ratchet:
#   Prevents warning count from increasing. New projects start at 0.
#   Use --update-baseline to accept a new warning count (e.g., after brownfield import).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/baseline.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Flag handling
# -----------------------------------------------------------------------------
UPDATE_BASELINE=false

for arg in "$@"; do
    case "$arg" in
        --update-baseline)
            UPDATE_BASELINE=true
            ;;
    esac
done

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

# -----------------------------------------------------------------------------
# Find flight-lint
# -----------------------------------------------------------------------------

FLIGHT_LINT=""
if [[ -x "$SCRIPT_DIR/../flight-lint/bin/flight-lint" ]]; then
    FLIGHT_LINT="$SCRIPT_DIR/../flight-lint/bin/flight-lint"
elif command -v flight-lint &>/dev/null; then
    FLIGHT_LINT="flight-lint"
fi

if [[ -z "$FLIGHT_LINT" ]]; then
    echo -e "${RED}Error: flight-lint not found${NC}"
    echo -e "${YELLOW}Build it: cd flight-lint && npm install && npm run build${NC}"
    exit 2
fi

# -----------------------------------------------------------------------------
# Run validation
# -----------------------------------------------------------------------------

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Flight Validation Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Running flight-lint...${NC}"
echo ""

# Run flight-lint with auto-discovery
LINT_OUTPUT=$("$FLIGHT_LINT" --auto --severity SHOULD 2>&1) || LINT_EXIT=$?
LINT_EXIT=${LINT_EXIT:-0}

# Show output
echo "$LINT_OUTPUT"
echo ""

# Parse flight-lint output for error/warning counts
# Format: "✗ N error(s)" and "⚠ N warning(s)"
TOTAL_FAIL=$( (echo "$LINT_OUTPUT" | grep -oE '✗ [0-9]+ error' | grep -oE '[0-9]+' | head -1) || echo "0")
TOTAL_WARN=$( (echo "$LINT_OUTPUT" | grep -oE '⚠ [0-9]+ warning' | grep -oE '[0-9]+' | head -1) || echo "0")
TOTAL_FAIL=${TOTAL_FAIL:-0}
TOTAL_WARN=${TOTAL_WARN:-0}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}       Validation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "  Errors:           ${RED}$TOTAL_FAIL${NC}"
echo -e "  Warnings:         ${YELLOW}$TOTAL_WARN${NC}"

# -----------------------------------------------------------------------------
# Baseline ratchet check
# -----------------------------------------------------------------------------

BASELINE=$(load_baseline)
echo -e "  Warning Baseline: ${BLUE}$BASELINE${NC}"
echo ""

# Handle --update-baseline flag
if [[ "$UPDATE_BASELINE" == true ]]; then
    save_baseline "$TOTAL_WARN"
    BASELINE="$TOTAL_WARN"
fi

# Check for errors (NEVER/MUST violations)
if [[ "$TOTAL_FAIL" -gt 0 ]]; then
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}  $TOTAL_FAIL error(s) found${NC}"
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

# Auto-ratchet down: if warnings decreased, tighten the baseline
if [[ "$TOTAL_WARN" -lt "$BASELINE" ]]; then
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
    echo -e "${GREEN}  Baseline auto-lowered: $BASELINE → $TOTAL_WARN (ratchet tightened)${NC}"
    save_baseline "$TOTAL_WARN"
elif [[ "$TOTAL_WARN" -gt 0 ]]; then
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC} (within baseline: $TOTAL_WARN ≤ $BASELINE)"
else
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED${NC}"
fi
echo ""
exit 0
