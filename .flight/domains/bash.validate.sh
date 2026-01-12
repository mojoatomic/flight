#!/bin/bash
# bash.validate.sh - Validate shell scripts against domain rules
set -uo pipefail

# Input files (will be made readonly after expansion)
FILES="${@:-*.sh **/*.sh}"

# Counters (cannot be readonly - need to increment)
# shellcheck disable=SC2034
PASS=0
FAIL=0
WARN=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        printf '%s\n' "$result" | head -10 | sed 's/^/   /'
        ((FAIL++))
    fi
}

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++))
    else
        yellow "⚠️  $name"
        printf '%s\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++))
    fi
}

printf '%s\n' "═══════════════════════════════════════════"
printf '%s\n' "  Bash/Shell Domain Validation"
printf '%s\n' "═══════════════════════════════════════════"
printf '\n'

# Expand globs
EXPANDED_FILES=$(ls $FILES 2>/dev/null || true)
if [[ -z "$EXPANDED_FILES" ]]; then
    red "No files found matching: $FILES"
    exit 1
fi
FILES="$EXPANDED_FILES"
readonly FILES

FILE_COUNT=$(printf '%s\n' "$FILES" | wc -w | tr -d ' ')
printf 'Files: %s\n\n' "$FILE_COUNT"

printf '%s\n' "## NEVER Rules"

# N1: Unquoted variables in dangerous contexts
check "N1: No unquoted variables in commands (rm, cp, mv, cd)" \
    grep -En '\b(rm|cp|mv|cd|cat|chmod|chown)\s+[^"'\''|&;>]*\$[a-zA-Z_]' $FILES

# N2: Parsing ls output
check "N2: No parsing ls output (for f in \$(ls))" \
    grep -En 'for\s+\w+\s+in\s+\$\(ls|\`ls' $FILES

# N3: Using backticks instead of $()
check "N3: No backticks (use \$() instead)" \
    grep -En '\`[^\`]+\`' $FILES

# N4: Using [ ] instead of [[ ]] in bash scripts
check "N4: No single brackets [ ] (use [[ ]] in bash)" \
    bash -c "
    for f in $FILES; do
        if head -1 \"\$f\" | grep -q 'bash'; then
            grep -En '^\s*\[\s+|\s+\[\s+[^[]' \"\$f\" | grep -v '\[\[' | head -5
        fi
    done
    "

# N5: Using 'function' keyword
check "N5: No 'function' keyword (use name() syntax)" \
    grep -En '^\s*function\s+\w+' $FILES

# N6: echo with variables (use printf)
warn "N6: Prefer printf over echo for variables" \
    grep -En 'echo\s+[^"'\'']*\$[a-zA-Z_]|echo\s+"\$' $FILES | grep -v 'echo "\$' | head -10

# N7: cd without error handling
check "N7: No bare 'cd' without || exit/|| return" \
    bash -c "
    for f in $FILES; do
        grep -En '^\s*cd\s+' \"\$f\" | grep -v '\|\||&&\|exit\|return\|;' | head -5
    done
    "

# N8: Useless use of cat
check "N8: No useless cat (cat file | cmd)" \
    grep -En 'cat\s+[^|]+\|\s*(grep|awk|sed|head|tail|wc|sort|uniq)' $FILES

# N9: Using eval (exclude grep patterns checking for eval)
check "N9: No eval (code injection risk)" \
    grep -En '^\s*eval\s|\seval\s' $FILES | grep -v 'grep.*eval'

# N10: Hardcoded /tmp files
check "N10: No hardcoded /tmp files (use mktemp)" \
    grep -En '"/tmp/[^$]|'\''\/tmp\/[^$]' $FILES | grep -v 'mktemp'

printf '\n%s\n' "## MUST Rules"

# M1: Scripts should have shebang
check "M1: Scripts must have shebang (#!/bin/bash or #!/usr/bin/env bash)" \
    bash -c "
    for f in $FILES; do
        if ! head -1 \"\$f\" | grep -qE '^#!.*(bash|sh)'; then
            printf '%s: missing or invalid shebang\n' \"\$f\"
        fi
    done
    "

# M2: Scripts should use set -e or set -euo pipefail
warn "M2: Scripts should use 'set -e' or 'set -euo pipefail'" \
    bash -c "
    for f in $FILES; do
        if ! grep -q 'set -e\|set -.*e' \"\$f\"; then
            printf '%s: missing set -e\n' \"\$f\"
        fi
    done
    "

# M3: Scripts should use set -u (error on unset variables)
warn "M3: Scripts should use 'set -u' (fail on unset vars)" \
    bash -c "
    for f in $FILES; do
        if ! grep -q 'set -.*u\|set -u' \"\$f\"; then
            printf '%s: missing set -u\n' \"\$f\"
        fi
    done
    "

# M4: Functions should use local variables
warn "M4: Functions should use 'local' for variables" \
    bash -c "
    for f in $FILES; do
        awk '
        /^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{/,/^\}/ {
            if (/^\s+[a-zA-Z_][a-zA-Z0-9_]*=/ && !/local\s|readonly\s|declare\s|export\s/) {
                print FILENAME\":\"NR\": \"$0
            }
        }
        ' \"\$f\"
    done
    " | head -10

# M5: Should have cleanup trap for temp files
warn "M5: Scripts using mktemp should have cleanup trap" \
    bash -c "
    for f in $FILES; do
        if grep -q 'mktemp' \"\$f\"; then
            if ! grep -q 'trap.*EXIT\|trap.*cleanup' \"\$f\"; then
                printf '%s: uses mktemp but no cleanup trap\n' \"\$f\"
            fi
        fi
    done
    "

# M6: Constants should use readonly
warn "M6: Constants (UPPER_CASE) should use 'readonly'" \
    bash -c "
    for f in $FILES; do
        grep -En '^[A-Z_]+=' \"\$f\" | grep -v 'readonly\|declare -r\|export' | head -3
    done
    "

printf '\n%s\n' "## Style Checks"

# S1: Check for long lines
warn "S1: Lines should be under 100 characters" \
    bash -c "
    for f in $FILES; do
        awk 'length > 100 { print FILENAME\":\"NR\": line length \"length }' \"\$f\" | head -3
    done
    "

# S2: Check for TODO/FIXME comments (exclude validator pattern-checks)
warn "S2: Review TODO/FIXME comments" \
    grep -Ein 'TODO|FIXME|XXX|HACK' $FILES | grep -v 'grep.*TODO\|grep.*FIXME' | head -5

printf '\n%s\n' "## ShellCheck"

# Run ShellCheck if available
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck_output=$(shellcheck -f gcc $FILES 2>/dev/null || true)
    if [[ -z "$shellcheck_output" ]]; then
        green "✅ ShellCheck: All files pass"
        ((PASS++))
    else
        error_count=$(printf '%s\n' "$shellcheck_output" | grep -c ':' || echo 0)
        if [[ "$error_count" -gt 0 ]]; then
            red "❌ ShellCheck: $error_count issues found"
            printf '%s\n' "$shellcheck_output" | head -10 | sed 's/^/   /'
            ((FAIL++))
        fi
    fi
else
    yellow "⚠️  ShellCheck not installed (brew install shellcheck)"
    ((WARN++))
fi

printf '\n%s\n' "## Info"

# Function count
FUNC_COUNT=$(grep -cE '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
printf 'ℹ️  Functions defined: %s\n' "${FUNC_COUNT:-0}"

# Readonly count
READONLY_COUNT=$(grep -c 'readonly ' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
printf 'ℹ️  Readonly declarations: %s\n' "${READONLY_COUNT:-0}"

# Local count
LOCAL_COUNT=$(grep -c 'local ' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
printf 'ℹ️  Local declarations: %s\n' "${LOCAL_COUNT:-0}"

# Trap count
TRAP_COUNT=$(grep -c 'trap ' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
printf 'ℹ️  Trap statements: %s\n' "${TRAP_COUNT:-0}"

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
