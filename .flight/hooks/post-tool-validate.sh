#!/usr/bin/env bash
# =============================================================================
# PostToolUse Hook - Validate code after Write/Edit/MultiEdit
# =============================================================================
#
# This hook runs after Claude Code writes or edits files. It:
# 1. Checks if the tool was Write, Edit, or MultiEdit
# 2. Runs flight-lint to validate the codebase
# 3. Injects validation results into the agent's context
#
# This is FEEDBACK ONLY - always returns "approve". The Stop hook handles
# blocking on violations.
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
    # Fallback if lib.sh not found - output minimal approve response
    printf '{"decision":"approve"}\n'
    exit 0
fi

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Read input JSON from stdin
    local input_json
    input_json="$(read_stdin_json)"

    # Extract tool name
    local tool_name
    tool_name="$(get_tool_name "$input_json")"

    # Only validate for file modification tools
    case "$tool_name" in
        Write|Edit|MultiEdit)
            # Continue to validation
            ;;
        *)
            # Not a file modification tool - approve and exit
            respond "approve"
            exit 0
            ;;
    esac

    # Run all validation (flight-lint AST + code-hygiene grep)
    local lint_output
    lint_output="$(run_all_validation 2>&1)" || true

    # Count violations
    local total_violations
    total_violations="$(get_total_violations "$lint_output")"

    # Build response
    if [[ "$total_violations" -gt 0 ]]; then
        # Get violation counts by severity
        local never_count must_count should_count
        never_count="$(count_by_severity "$lint_output" "NEVER")"
        must_count="$(count_by_severity "$lint_output" "MUST")"
        should_count="$(count_by_severity "$lint_output" "SHOULD")"

        # Get violation details
        local violation_details
        violation_details="$(format_violations_summary "$lint_output" 5)"

        # Build summary message
        local summary
        summary="Flight Validation Results:"
        summary="$summary\n- $total_violations violation(s) found"

        if [[ "$never_count" -gt 0 ]]; then
            summary="$summary (NEVER: $never_count"
            if [[ "$must_count" -gt 0 ]]; then
                summary="$summary, MUST: $must_count"
            fi
            if [[ "$should_count" -gt 0 ]]; then
                summary="$summary, SHOULD: $should_count"
            fi
            summary="$summary)"
        fi

        if [[ -n "$violation_details" ]]; then
            summary="$summary\n\n$violation_details"
        fi

        summary="$summary\n\nConsider fixing these before completing."

        respond "approve" "" "$summary"
    else
        respond "approve" "" "Flight validation passed. No violations detected."
    fi
}

main "$@"
