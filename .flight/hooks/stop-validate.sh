#!/usr/bin/env bash
# =============================================================================
# Stop Hook - Enforcement gate for task completion
# =============================================================================
#
# This hook runs when Claude Code attempts to complete a task. It:
# 1. Runs flight-lint to validate the codebase
# 2. BLOCKS completion if NEVER or MUST violations exist
# 3. ALLOWS completion with SHOULD violations (warnings only)
# 4. Injects violation details into context when blocking
#
# This creates the self-correction loop - the agent cannot complete until
# all critical violations are fixed.
#
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared library
if [[ -f "$SCRIPT_DIR/lib.sh" ]]; then
    source "$SCRIPT_DIR/lib.sh"
else
    # Fallback if lib.sh not found - approve to avoid blocking
    printf '{"decision":"approve","reason":"lib.sh not found, skipping validation"}\n'
    exit 0
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Check if flight-lint is available
    if ! check_flight_lint_available; then
        # Block with clear message - don't silently approve
        respond "block" \
            "flight-lint not found" \
            "Cannot validate: flight-lint binary not found at $FLIGHT_LINT_BIN\n\nTo build flight-lint:\n  cd flight-lint && npm install && npm run build\n\nOr skip validation by removing hooks from .claude/settings.json"
        return 0
    fi

    # Run flight-lint
    local lint_output
    lint_output="$(run_flight_lint 2>&1)" || true

    # Check for flight-lint errors
    if [[ "$lint_output" == "__FLIGHT_LINT_NOT_FOUND__" ]]; then
        respond "block" \
            "flight-lint not available" \
            "Cannot validate: flight-lint returned an error.\n\nRebuild with: cd flight-lint && npm run build"
        return 0
    fi

    # Count violations by severity
    local never_count must_count should_count total_count
    never_count="$(count_by_severity "$lint_output" "NEVER")"
    must_count="$(count_by_severity "$lint_output" "MUST")"
    should_count="$(count_by_severity "$lint_output" "SHOULD")"
    total_count="$(get_total_violations "$lint_output")"

    # Calculate critical violations (NEVER + MUST)
    local critical_count
    critical_count=$((never_count + must_count))

    # Decision logic
    if [[ "$critical_count" -gt 0 ]]; then
        # BLOCK - critical violations found
        local reason
        reason="Flight validation failed: $never_count NEVER, $must_count MUST violation(s)"

        # Build detailed context
        local context
        context="You MUST fix these violations before completing:\n\n"

        # Get violation details
        local violation_details
        violation_details="$(format_violations_summary "$lint_output" 10)"

        if [[ -n "$violation_details" ]]; then
            context="$context$violation_details\n\n"
        fi

        context="${context}These are non-negotiable constraints from the domain files."
        context="$context Fix them and try completing again."

        respond "block" "$reason" "$context"

    elif [[ "$should_count" -gt 0 ]]; then
        # APPROVE with warnings
        local context
        context="Flight validation passed with $should_count warning(s).\n\n"

        # Get warning details
        local warning_details
        warning_details="$(format_violations_summary "$lint_output" 5)"

        if [[ -n "$warning_details" ]]; then
            context="$context$warning_details\n\n"
        fi

        context="${context}Task completed. Consider addressing warnings in follow-up."

        respond "approve" "" "$context"

    else
        # APPROVE - clean
        respond "approve" "" "Flight validation passed. All domain constraints satisfied."
    fi
}

main "$@"
