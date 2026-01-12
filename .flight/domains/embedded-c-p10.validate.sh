#!/bin/bash
set -uo pipefail

FILES="${@:-*.c}"
PASS=0
FAIL=0

red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }

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
        echo "$result" | head -5 | sed 's/^/   /'
        ((FAIL++))
    fi
}

echo "═══════════════════════════════════════════"
echo "  P10 Validation: $FILES"
echo "═══════════════════════════════════════════"
echo ""
echo "## NEVER Rules"
check "N1: No goto" grep -n "goto " $FILES
check "N2: No setjmp/longjmp" grep -n "setjmp\|longjmp" $FILES
check "N3: No malloc/free" grep -En "\b(malloc|free|calloc|realloc)\b" $FILES
check "N4: No #ifdef" grep -n "^#ifdef\|^#if " $FILES
check "N5: No **ptr" grep -n "[^/]\*\*[a-zA-Z]" $FILES
check "N6: No ->->" grep -n "->.*->" $FILES
check "N7: No while(1)" grep -En "while\s*\(1\)|while\s*\(true\)|for\s*\(;;\)" $FILES

echo ""
echo "## MUST Rules"
check "M1: Compile -Wall -Wextra -Werror" gcc -Wall -Wextra -Werror -pedantic -std=c11 -fsyntax-only $FILES

# M2: Function length check
check "M2: Functions ≤60 lines" awk '
/^(status_t|static|void|int|uint[0-9]+_t|bool) [a-z_]+\(/ { 
    start=NR; fname=$0; in_func=1 
}
/^}$/ && in_func { 
    len=NR-start
    if (len > 60) { 
        gsub(/\(.*/, "", fname)
        gsub(/^.* /, "", fname)
        print fname": "len" lines"
    }
    in_func=0 
}' $FILES

# M3: Assertion density check
check "M3: ≥2 asserts/function" awk '
/^(status_t|static|void|int|uint[0-9]+_t|bool) [a-z_]+\(/ { 
    fname=$0; asserts=0; in_func=1 
}
/ASSERT\(|assert\(/ && in_func { asserts++ }
/^}$/ && in_func { 
    if (asserts < 2) { 
        gsub(/\(.*/, "", fname)
        gsub(/^.* /, "", fname)
        print fname": "asserts" asserts"
    }
    in_func=0 
}' $FILES

# M4: Return value check  
check "M4: printf returns cast to (void)" bash -c "grep -n 'printf\|fprintf' $FILES 2>/dev/null | grep -v '(void)' | grep -v '= ' || true"

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

exit $FAIL
