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
readonly CODE_HYGIENE_RULES="$FLIGHT_DIR/domains/code-hygiene.rules.json"

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
#   Or special marker if flight-lint not found: __FLIGHT_LINT_NOT_FOUND__
# Returns:
#   Exit code from flight-lint (0 = no violations, non-zero = violations found)
#   Returns 127 if flight-lint binary not found
# -----------------------------------------------------------------------------
run_flight_lint() {
    local lint_output=""
    local exit_code=0

    # Check if flight-lint exists
    if [[ ! -x "$FLIGHT_LINT_BIN" ]]; then
        printf '__FLIGHT_LINT_NOT_FOUND__\n'
        return 127
    fi

    # Run flight-lint and capture output
    lint_output="$("$FLIGHT_LINT_BIN" --auto --format json 2>&1)" || exit_code=$?

    # Output the result
    printf '%s\n' "$lint_output"
    return "$exit_code"
}

# -----------------------------------------------------------------------------
# check_flight_lint_available - Check if flight-lint binary exists
# -----------------------------------------------------------------------------
# Returns:
#   0 if flight-lint is available and executable, 1 otherwise
# -----------------------------------------------------------------------------
check_flight_lint_available() {
    [[ -x "$FLIGHT_LINT_BIN" ]]
}

# -----------------------------------------------------------------------------
# run_code_hygiene_grep - Run code-hygiene grep rules and output JSON
# -----------------------------------------------------------------------------
# Output:
#   NDJSON with violations from grep-based code-hygiene rules
# Returns:
#   0 if no violations, 1 if violations found
# -----------------------------------------------------------------------------
run_code_hygiene_grep() {
    if [[ ! -f "$CODE_HYGIENE_RULES" ]]; then
        printf '{"domain":"code-hygiene","fileCount":0,"results":[]}\n'
        return 0
    fi

    if ! check_jq_available; then
        # jq required for parsing rules
        printf '{"domain":"code-hygiene","fileCount":0,"results":[]}\n'
        return 0
    fi

    local results=""
    local file_count=0
    local has_violations=0

    # Find source files (simple approach - exclude common non-source dirs)
    local files
    files=$(find . \( \
        -path './node_modules' -o \
        -path './.git' -o \
        -path './dist' -o \
        -path './build' -o \
        -path './vendor' -o \
        -path './target' -o \
        -path './.flight' -o \
        -path './flight-lint' -o \
        -path './.venv' -o \
        -path './venv' -o \
        -path './__pycache__' -o \
        -path './tests' -o \
        -path './fixtures' \
        \) -prune -o \
        -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' \) \
        -print 2>/dev/null | head -500) || true

    file_count=$(printf '%s\n' "$files" | grep -c . || echo 0)

    # If no files, return empty
    if [[ -z "$files" ]] || [[ "$file_count" -eq 0 ]]; then
        printf '{"domain":"code-hygiene","fileCount":0,"results":[]}\n'
        return 0
    fi

    # Get grep rules
    local rules
    rules=$(jq -c '.rules[] | select(.type == "grep")' "$CODE_HYGIENE_RULES" 2>/dev/null)

    # Run each grep rule
    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue

        local rule_id pattern severity message ignore_when
        rule_id=$(printf '%s' "$rule" | jq -r '.id')
        pattern=$(printf '%s' "$rule" | jq -r '.pattern')
        severity=$(printf '%s' "$rule" | jq -r '.severity')
        message=$(printf '%s' "$rule" | jq -r '.message')
        ignore_when=$(printf '%s' "$rule" | jq -r '.ignore_when // [] | .[]' | paste -sd '|' -)

        # Run grep across all files at once (use -E for extended regex)
        local matches
        if [[ -n "$ignore_when" ]]; then
            matches=$(printf '%s\n' "$files" | xargs grep -EHn "$pattern" 2>/dev/null | grep -Ev "$ignore_when" || true)
        else
            matches=$(printf '%s\n' "$files" | xargs grep -EHn "$pattern" 2>/dev/null || true)
        fi

        # Parse matches and build JSON results
        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            has_violations=1

            # Format: ./file.ts:10:content
            local file_path line_num
            file_path="${match%%:*}"
            local rest="${match#*:}"
            line_num="${rest%%:*}"

            local escaped_message
            escaped_message=$(escape_json_string "$message")

            if [[ -n "$results" ]]; then
                results="$results,"
            fi
            results="$results{\"filePath\":\"$file_path\",\"line\":$line_num,\"column\":1,\"ruleId\":\"$rule_id\",\"severity\":\"$severity\",\"message\":\"$escaped_message\"}"
        done <<< "$matches"
    done <<< "$rules"

    # Output JSON
    printf '{"domain":"code-hygiene","fileCount":%d,"results":[%s]}\n' "$file_count" "$results"

    if [[ "$has_violations" -eq 1 ]]; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# run_all_validation - Run both flight-lint (AST) and code-hygiene grep rules
# -----------------------------------------------------------------------------
# Output:
#   Combined NDJSON from both sources
# Returns:
#   0 if no violations, non-zero if violations found
# -----------------------------------------------------------------------------
run_all_validation() {
    local combined_output=""
    local exit_code=0

    # Run flight-lint for AST rules (if available)
    if check_flight_lint_available; then
        local lint_output
        lint_output="$(run_flight_lint 2>&1)" || true
        if [[ "$lint_output" != "__FLIGHT_LINT_NOT_FOUND__" ]]; then
            combined_output="$lint_output"
        fi
    fi

    # Run code-hygiene grep rules
    local grep_output
    grep_output="$(run_code_hygiene_grep 2>&1)" || exit_code=1

    # Combine outputs
    if [[ -n "$combined_output" ]]; then
        combined_output="$combined_output"$'\n'"$grep_output"
    else
        combined_output="$grep_output"
    fi

    printf '%s\n' "$combined_output"
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
#   $1 - json_string: JSON output from flight-lint (NDJSON format)
#   $2 - max_items: Maximum number of violations to show (default: 5)
# Output:
#   Formatted string with violation details
# -----------------------------------------------------------------------------
format_violations_summary() {
    local json_string="$1"
    local max_items="${2:-5}"
    local summary=""

    if check_jq_available; then
        # Use jq to format violations (slurp to handle NDJSON - one object per domain)
        summary="$(printf '%s' "$json_string" | jq -rs \
            "[.[].results[]] | .[:$max_items][] | \"- [\(.severity)] \(.ruleId): \(.message) at \(.filePath):\(.line)\"" \
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

# -----------------------------------------------------------------------------
# has_tool_use - Check if stop hook input contains tool use
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - json_string: JSON input from Claude Code stop hook
# Returns:
#   0 if tool use is present, 1 if text-only response
# -----------------------------------------------------------------------------
has_tool_use() {
    local json_string="$1"

    if check_jq_available; then
        # Check if stop_hook_input.message contains tool_use content blocks
        local tool_use_count
        tool_use_count="$(printf '%s' "$json_string" | \
            jq '[.stop_hook_input.message[]? | select(.type == "tool_use")] | length' 2>/dev/null)" || tool_use_count=0
        [[ "$tool_use_count" -gt 0 ]]
    else
        # Fallback: check for tool_use string in input
        printf '%s' "$json_string" | grep -q '"type":"tool_use"'
    fi
}
