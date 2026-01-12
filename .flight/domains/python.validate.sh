#!/bin/bash
# python.validate.sh - Validate Python against domain rules
set -uo pipefail

FILES="${@:-*.py **/*.py}"
PASS=0
FAIL=0
WARN=0

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [ -z "$result" ]; then
        green "✅ $name"
        ((PASS++))
    else
        red "❌ $name"
        echo "$result" | head -10 | sed 's/^/   /'
        ((FAIL++))
    fi
}

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [ -z "$result" ]; then
        green "✅ $name"
        ((PASS++))
    else
        yellow "⚠️  $name"
        echo "$result" | head -5 | sed 's/^/   /'
        ((WARN++))
    fi
}

echo "═══════════════════════════════════════════"
echo "  Python Domain Validation"
echo "═══════════════════════════════════════════"
echo ""

# Expand globs
EXPANDED_FILES=$(ls $FILES 2>/dev/null || true)
if [ -z "$EXPANDED_FILES" ]; then
    red "No files found matching: $FILES"
    exit 1
fi
FILES="$EXPANDED_FILES"

echo "Files: $(echo "$FILES" | wc -w | tr -d ' ')"
echo ""

echo "## NEVER Rules"

# N1: Bare except
check "N1: No bare 'except:'" \
    grep -En "^\s*except\s*:" $FILES

# N2: except Exception with pass
check "N2: No 'except Exception: pass' (silent failures)" \
    bash -c "
    for f in $FILES; do
        awk '/except\s+(Exception|BaseException)/ { getline; if (/^\s*pass\s*$/) print FILENAME\":\"NR-1\": except with pass\" }' \"\$f\"
    done
    "

# N3: Mutable default arguments
check "N3: No mutable default arguments (=[], ={}, =set())" \
    grep -En "def .+\(.*=\s*(\[\]|\{\}|set\(\))" $FILES

# N4: from x import *
check "N4: No 'from x import *'" \
    grep -En "^from .+ import \*" $FILES

# N5: String concatenation in loops (+=) - simplified check
warn "N5: Review string += patterns (may indicate loop concatenation)" \
    grep -En "\+=\s*['\"]|\+=.*str\(" $FILES

# N6: type() for type checking
check "N6: No 'type(x) ==' (use isinstance)" \
    grep -En "type\(.+\)\s*==|==\s*type\(" $FILES

# N7: Magic numbers (numbers > 1 not in constant assignment)
warn "N7: Review magic numbers in logic (use named constants)" \
    grep -En "if .+ [<>=]+ [0-9]{2,}|while .+ [<>=]+ [0-9]{2,}|sleep\([0-9]{2,}\)" $FILES

# N8: Generic variable names (module-level only, not inside functions)
check "N8: No generic variable names at module level (data, temp, result, info, obj)" \
    grep -En "^(data|temp|result|info|obj)\s*=" $FILES

# N9: print() for logging (not in __main__ block)
check "N9: No print() outside __main__ (use logging)" \
    bash -c "
    for f in $FILES; do
        # Find prints not in if __name__ == '__main__' block
        awk '
        /__name__.*__main__/ { in_main=1 }
        /^[^ ]/ && in_main { in_main=0 }
        /print\(/ && !in_main && !/# noqa/ { print FILENAME\":\"NR\": \"\$0 }
        ' \"\$f\"
    done
    " | head -10

# N10: Hardcoded absolute paths
check "N10: No hardcoded absolute paths" \
    grep -En "['\"]/(home|usr|var|etc|tmp)/|['\"][A-Z]:\\\\" $FILES

# N11: No type hints on def
warn "N11: Public functions should have type hints" \
    bash -c "
    for f in $FILES; do
        grep -n '^def [a-z]' \"\$f\" | grep -v '\->' | grep -v '__' | head -3
    done
    "

# N12: Deeply nested conditionals
check "N12: No deeply nested conditionals (>3 levels)" \
    bash -c "
    for f in $FILES; do
        awk '
        /^\s+if / { 
            spaces = length(\$0) - length(gensub(/^\s+/, \"\", \"g\", \$0))
            if (spaces > 16) {
                print FILENAME\":\"NR\": deeply nested (\"int(spaces/4)\" levels)\"
            }
        }
        ' \"\$f\"
    done
    " | head -5

echo ""
echo "## MUST Rules (warnings)"

# M1: Has if __name__ == "__main__" for scripts
warn "M1: Scripts should have 'if __name__ == \"__main__\":'" \
    bash -c "
    for f in $FILES; do
        if grep -q '^def main' \"\$f\"; then
            if ! grep -q '__name__.*__main__' \"\$f\"; then
                echo \"\$f: has main() but no __name__ guard\"
            fi
        fi
    done
    "

# M2: Uses pathlib
warn "M2: Consider pathlib for file operations" \
    bash -c "
    for f in $FILES; do
        if grep -q 'os.path' \"\$f\"; then
            if ! grep -q 'pathlib' \"\$f\"; then
                echo \"\$f: uses os.path, consider pathlib\"
            fi
        fi
    done
    "

# M3: Uses logging module
warn "M3: Should use logging module" \
    bash -c "
    for f in $FILES; do
        if [ \$(wc -l < \"\$f\") -gt 50 ]; then
            if ! grep -q 'import logging\|from logging' \"\$f\"; then
                echo \"\$f: large file without logging\"
            fi
        fi
    done
    "

# M4: Docstrings on public functions
warn "M4: Public functions should have docstrings" \
    bash -c "
    for f in $FILES; do
        awk '
        /^def [a-z][a-z_]+\(/ { 
            fname=\$0; getline; 
            if (\$0 !~ /\"\"\"/ && \$0 !~ /'\'''\'''\''/) {
                print FILENAME\":\"NR-1\": \"fname\" - no docstring\"
            }
        }
        ' \"\$f\" | head -3
    done
    "

echo ""
echo "## Info"

# Function count
FUNC_COUNT=$(grep -c "^def " $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Functions defined: ${FUNC_COUNT:-0}"

# Class count
CLASS_COUNT=$(grep -c "^class " $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Classes defined: ${CLASS_COUNT:-0}"

# Type hints usage
TYPED_FUNCS=$(grep -c "def.*->.*:" $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Functions with return type: ${TYPED_FUNCS:-0}"

# Dataclasses
DATACLASS_COUNT=$(grep -c "@dataclass" $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Dataclasses: ${DATACLASS_COUNT:-0}"

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

exit $FAIL
