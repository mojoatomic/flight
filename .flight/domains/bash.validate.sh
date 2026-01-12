#!/bin/bash
# bash.validate.sh - World-class shell script validation
set -uo pipefail

FILES="${@:-*.sh **/*.sh}"
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

EXPANDED_FILES=$(ls $FILES 2>/dev/null || true)
if [[ -z "$EXPANDED_FILES" ]]; then
    red "No files found matching: $FILES"
    exit 1
fi
FILES="$EXPANDED_FILES"

FILE_COUNT=$(printf '%s\n' "$FILES" | wc -w | tr -d ' ')
printf 'Files: %s\n\n' "$FILE_COUNT"

printf '%s\n' "## NEVER Rules"

check "N1: No unquoted variables in commands" \
    bash -c "for f in $FILES; do grep -En '\b(rm|cp|mv|cd|cat|chmod|chown)\s+[^\"'\''|&;>]*\\\$[a-zA-Z_]' \"\$f\" 2>/dev/null | grep -v '# shellcheck'; done"

check "N2: No unquoted \$(cmd) substitution" \
    bash -c "for f in $FILES; do grep -En '[^\"=]\\\$\([^)]+\)[^\"]' \"\$f\" 2>/dev/null | grep -v '# shellcheck' | head -5; done"

check "N3: No parsing ls output" \
    grep -En 'for\s+\w+\s+in\s+\$\(ls|\`ls|ls\s+\|' $FILES

check "N4: No backticks (use \$())" \
    grep -En '\`[^\`]+\`' $FILES

check "N5: No single brackets [ ] in bash" \
    bash -c "for f in $FILES; do if head -1 \"\$f\" | grep -q 'bash'; then grep -En '^\s*\[\s+|\s+\[\s+[^[]' \"\$f\" | grep -v '\[\[' | head -5; fi; done"

check "N6: No 'function' keyword" \
    grep -En '^\s*function\s+\w+' $FILES

check "N7: No bare 'cd' without error handling" \
    bash -c "for f in $FILES; do grep -En '^\s*cd\s+' \"\$f\" | grep -v '\|\||&&\|exit\|return\|;\|#' | head -5; done"

check "N8: No useless cat" \
    grep -En 'cat\s+[^|]+\|\s*(grep|awk|sed|head|tail|wc|sort|uniq|cut)' $FILES

check "N9: No eval" \
    bash -c "for f in $FILES; do grep -En '^\s*eval\s|\seval\s' \"\$f\" | grep -v 'grep.*eval\|check.*eval\|#' | head -5; done"

check "N10: No hardcoded /tmp files" \
    bash -c "for f in $FILES; do grep -En '\"/tmp/[^\$]' \"\$f\" | grep -v 'mktemp\|#' | head -5; done"

check "N11: No curl|bash (remote code execution)" \
    grep -En 'curl.*\|\s*(ba)?sh|wget.*\|\s*(ba)?sh' $FILES

check "N12: No unquoted array expansion" \
    bash -c "for f in $FILES; do grep -En '\\\$\{[a-zA-Z_]+\[\*\]\}' \"\$f\" | head -3; done"

printf '\n%s\n' "## MUST Rules"

check "M1: Shebang required" \
    bash -c "for f in $FILES; do if ! head -1 \"\$f\" | grep -qE '^#!.*(bash|sh)'; then printf '%s: missing shebang\n' \"\$f\"; fi; done"

check "M2: Full strict mode (set -euo pipefail)" \
    bash -c "
    for f in $FILES; do
        if ! grep -q 'set -euo pipefail' \"\$f\"; then
            if ! (grep -q 'set.*-e' \"\$f\" && grep -q 'set.*-u' \"\$f\" && grep -q 'pipefail' \"\$f\"); then
                printf '%s: missing strict mode\n' \"\$f\"
            fi
        fi
    done
    "

warn "M3: Functions should use 'local'" \
    bash -c "
    for f in $FILES; do
        awk '/^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{/,/^\}/ {
            if (/^\s+[a-zA-Z_][a-zA-Z0-9_]*=/ && !/local\s|readonly\s|declare\s|export\s/) {
                print FILENAME\":\"NR\": \"\$0
            }
        }' \"\$f\"
    done
    " | head -10

warn "M4: mktemp needs cleanup trap" \
    bash -c "for f in $FILES; do if grep -q 'mktemp' \"\$f\" && ! grep -q 'trap.*EXIT' \"\$f\"; then printf '%s: mktemp without trap\n' \"\$f\"; fi; done"

warn "M5: Constants should use readonly" \
    bash -c "for f in $FILES; do grep -En '^[A-Z_]+=' \"\$f\" | grep -v 'readonly\|declare -r\|export\|local' | head -3; done"

warn "M6: Read loops need 'IFS= read -r'" \
    bash -c "for f in $FILES; do grep -En 'while\s+read\s' \"\$f\" | grep -v 'IFS=\|read -r' | head -3; done"

printf '\n%s\n' "## Style"

warn "S1: Lines under 100 chars" \
    bash -c "for f in $FILES; do awk 'length > 100 { print FILENAME\":\"NR\": \"length\" chars\" }' \"\$f\" | head -3; done"

warn "S2: Prefer printf over echo" \
    bash -c "for f in $FILES; do grep -En 'echo\s+\"\\\$|echo\s+-e' \"\$f\" | head -3; done"

printf '\n%s\n' "## ShellCheck"

if command -v shellcheck >/dev/null 2>&1; then
    sc_out=$(shellcheck -f gcc $FILES 2>/dev/null || true)
    if [[ -z "$sc_out" ]]; then
        green "✅ ShellCheck: All pass"
        ((PASS++))
    else
        err_count=$(printf '%s\n' "$sc_out" | grep -c 'error:' || echo 0)
        warn_count=$(printf '%s\n' "$sc_out" | grep -c 'warning:' || echo 0)
        if [[ "$err_count" -gt 0 ]]; then
            red "❌ ShellCheck: $err_count errors, $warn_count warnings"
            printf '%s\n' "$sc_out" | head -5 | sed 's/^/   /'
            ((FAIL++))
        else
            yellow "⚠️  ShellCheck: $warn_count warnings"
            ((WARN++))
        fi
    fi
else
    yellow "⚠️  ShellCheck not installed"
    ((WARN++))
fi

printf '\n%s\n' "## Info"
printf 'ℹ️  Functions: %s\n' "$(grep -cE '^[a-zA-Z_]+\(\)' $FILES 2>/dev/null | awk -F: '{s+=$2}END{print s}')"
printf 'ℹ️  Readonly: %s\n' "$(grep -c 'readonly ' $FILES 2>/dev/null | awk -F: '{s+=$2}END{print s}')"
printf 'ℹ️  Local: %s\n' "$(grep -c 'local ' $FILES 2>/dev/null | awk -F: '{s+=$2}END{print s}')"
printf 'ℹ️  Traps: %s\n' "$(grep -c 'trap ' $FILES 2>/dev/null | awk -F: '{s+=$2}END{print s}')"

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
[[ $FAIL -eq 0 ]] && green "  RESULT: PASS" || red "  RESULT: FAIL"
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
