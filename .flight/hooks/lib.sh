#!/usr/bin/env bash
# =============================================================================
# Flight Hooks Library - Shared utilities for Claude Code hooks
# =============================================================================
#
# Source this file in hook scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Provides:
#   respond()              - Output JSON response to stdout
#   run_flight_lint()      - Run flight-lint and capture JSON output
#   count_by_severity()    - Count violations by severity level
#   get_total_violations() - Get total violation count
#   check_jq_available()   - Check if jq is installed
#
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
readonly HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FLIGHT_DIR="$(dirname "$HOOKS_DIR")"
readonly PROJECT_ROOT="$(dirname "$FLIGHT_DIR")"
readonly FLIGHT_LINT_BIN="$PROJECT_ROOT/flight-lint/bin/flight-lint"

# -----------------------------------------------------------------------------
# check_jq_available - Check if jq is installed
# -----------------------------------------------------------------------------
# Returns:
#   0 if jq is available, 1 otherwise
# -----------------------------------------------------------------------------
check_jq_available() {
    command -v jq &>/dev/null
}

# -----------------------------------------------------------------------------
# escape_json_string - Escape a string for JSON output
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - String to escape
# Output:
#   Escaped string safe for JSON
# -----------------------------------------------------------------------------
escape_json_string() {
    local input_string="$1"
    # Escape backslashes first, then quotes, then newlines
    input_string="${input_string//\\/\\\\}"
    input_string="${input_string//\"/\\\"}"
    input_string="${input_string//$'\n'/\\n}"
    input_string="${input_string//$'\t'/\\t}"
    printf '%s' "$input_string"
}

# -----------------------------------------------------------------------------
# respond - Output JSON response to stdout
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - decision: "approve", "block", or "skip"
#   $2 - reason: Optional human-readable explanation
#   $3 - additionalContext: Optional context injected into agent conversation
# Output:
#   Valid JSON to stdout
# -----------------------------------------------------------------------------
respond() {
    local decision="$1"
    local reason="${2:-}"
    local additional_context="${3:-}"

    # Escape strings for JSON
    local escaped_reason
    local escaped_context
    escaped_reason="$(escape_json_string "$reason")"
    escaped_context="$(escape_json_string "$additional_context")"

    # Build JSON response
    if [[ -n "$additional_context" ]] && [[ -n "$reason" ]]; then
        printf '{"decision":"%s","reason":"%s","additionalContext":"%s"}\n' \
            "$decision" "$escaped_reason" "$escaped_context"
    elif [[ -n "$reason" ]]; then
        printf '{"decision":"%s","reason":"%s"}\n' "$decision" "$escaped_reason"
    elif [[ -n "$additional_context" ]]; then
        printf '{"decision":"%s","additionalContext":"%s"}\n' \
            "$decision" "$escaped_context"
    else
        printf '{"decision":"%s"}\n' "$decision"
    fi
}

# -----------------------------------------------------------------------------
# run_flight_lint - Run flight-lint and capture JSON output
# -----------------------------------------------------------------------------
# Output:
#   JSON from flight-lint --auto --format json
# Returns:
#   Exit code from flight-lint (0 = no violations, non-zero = violations found)
# -----------------------------------------------------------------------------
run_flight_lint() {
    local lint_output=""
    local exit_code=0

    # Check if flight-lint exists
    if [[ ! -x "$FLIGHT_LINT_BIN" ]]; then
        printf '{"error":"flight-lint not found at %s"}\n' "$FLIGHT_LINT_BIN"
        return 1
    fi

    # Run flight-lint and capture output
    lint_output="$("$FLIGHT_LINT_BIN" --auto --format json 2>&1)" || exit_code=$?

    # Output the result
    printf '%s\n' "$lint_output"
    return "$exit_code"
}

# -----------------------------------------------------------------------------
# count_by_severity - Count violations by severity level
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - json_string: JSON output from flight-lint
#   $2 - severity: NEVER, MUST, SHOULD, or GUIDANCE
# Output:
#   Integer count of violations with that severity
# -----------------------------------------------------------------------------
count_by_severity() {
    local json_string="$1"
    local severity="$2"
    local violation_count=0

    if check_jq_available; then
        # Use jq for accurate parsing (slurp to handle NDJSON - one object per domain)
        violation_count="$(printf '%s' "$json_string" | \
            jq -s "[.[].results[] | select(.severity == \"$severity\")] | length" \
            2>/dev/null)" || violation_count=0
    else
        # Fallback: count occurrences of "severity":"LEVEL"
        violation_count="$(printf '%s' "$json_string" | \
            grep -c "\"severity\":\"$severity\"" 2>/dev/null)" || violation_count=0
    fi

    # Ensure we output a number
    if [[ ! "$violation_count" =~ ^[0-9]+$ ]]; then
        violation_count=0
    fi

    printf '%d' "$violation_count"
}

# -----------------------------------------------------------------------------
# get_total_violations - Get total violation count from flight-lint JSON
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - json_string: JSON output from flight-lint
# Output:
#   Integer total count of all violations
# -----------------------------------------------------------------------------
get_total_violations() {
    local json_string="$1"
    local total_count=0

    if check_jq_available; then
        # Use jq for accurate parsing (slurp to handle NDJSON - one object per domain)
        total_count="$(printf '%s' "$json_string" | \
            jq -s '[.[].results[]] | length' 2>/dev/null)" \
            || total_count=0
    else
        # Fallback: count occurrences of "severity" (each violation has one)
        total_count="$(printf '%s' "$json_string" | \
            grep -c '"severity"' 2>/dev/null)" || total_count=0
    fi

    # Ensure we output a number
    if [[ ! "$total_count" =~ ^[0-9]+$ ]]; then
        total_count=0
    fi

    printf '%d' "$total_count"
}

# -----------------------------------------------------------------------------
# format_violations_summary - Format violations for human-readable output
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - json_string: JSON output from flight-lint
#   $2 - max_items: Maximum number of violations to show (default: 5)
# Output:
#   Formatted string with violation details
# -----------------------------------------------------------------------------
format_violations_summary() {
    local json_string="$1"
    local max_items="${2:-5}"
    local summary=""

    if check_jq_available; then
        # Use jq to format violations
        summary="$(printf '%s' "$json_string" | jq -r \
            ".results[:$max_items][] | \"- [\(.severity)] \(.ruleId): \(.message) at \(.filePath):\(.line)\"" \
            2>/dev/null)" || summary=""
    else
        # Fallback: basic extraction (less precise)
        summary="$(printf '%s' "$json_string" | \
            grep -oE '"ruleId":"[^"]*"|"message":"[^"]*"|"severity":"[^"]*"' | \
            head -"$((max_items * 3))" | \
            paste - - - 2>/dev/null)" || summary=""
    fi

    printf '%s' "$summary"
}

# -----------------------------------------------------------------------------
# read_stdin_json - Read JSON from stdin
# -----------------------------------------------------------------------------
# Output:
#   JSON string from stdin
# -----------------------------------------------------------------------------
read_stdin_json() {
    local stdin_content=""
    stdin_content="$(cat)"
    printf '%s' "$stdin_content"
}

# -----------------------------------------------------------------------------
# get_tool_name - Extract tool_name from hook input JSON
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - json_string: JSON input from Claude Code hook
# Output:
#   Tool name (e.g., "Write", "Edit", "MultiEdit")
# -----------------------------------------------------------------------------
get_tool_name() {
    local json_string="$1"
    local tool_name=""

    if check_jq_available; then
        tool_name="$(printf '%s' "$json_string" | jq -r '.tool_name // ""' 2>/dev/null)"
    else
        # Fallback: extract with grep
        tool_name="$(printf '%s' "$json_string" | \
            grep -oE '"tool_name":"[^"]*"' | \
            sed 's/"tool_name":"//;s/"$//' 2>/dev/null)" || tool_name=""
    fi

    printf '%s' "$tool_name"
}
