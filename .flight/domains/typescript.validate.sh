#!/bin/bash
# typescript.validate.sh - Validate TypeScript against domain rules
set -uo pipefail

FILES="${@:-src/**/*.ts src/**/*.tsx src/*.ts src/*.tsx}"
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
echo "  TypeScript Domain Validation"
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

# N1: Unjustified any (any without comment on same or previous line)
check "N1: No unjustified 'any' (must have comment)" \
    bash -c "
    for f in $FILES; do
        awk '
        /: any/ || /as any/ || /<any>/ {
            # Check if previous line has justification
            if (prev !~ /TODO|FIXME|any.*because|legacy|migration|third.party|lib types/) {
                # Check if current line has justification in a comment
                if (\$0 !~ /\/\/.*any|\/\*.*any|\/\/.*TODO|\/\/.*FIXME|\/\/.*legacy|\/\/.*migration|\/\/.*third.party|\/\/.*lib types/) {
                    print FILENAME\":\"NR\": \"\$0
                }
            }
        }
        { prev = \$0 }
        ' \"\$f\"
    done
    "

# N2: @ts-ignore without explanation
check "N2: No @ts-ignore without explanation" \
    grep -En "@ts-ignore\s*$" $FILES

# N3: Non-null assertion abuse (multiple ! in one line)
check "N3: No chained non-null assertions (x!.y!.z!)" \
    grep -En "\w+!\.\w+!\." $FILES

# N4: Type assertion on unknown external data without validation
check "N4: No 'as Type' on JSON.parse or fetch response" \
    grep -En "JSON\.parse\([^)]+\)\s+as\s+|\.json\(\)\s+as\s+" $FILES

# N5: Loose object types
check "N5: No loose object types (: object, : {})" \
    grep -En ":\s*object\s*[;,)=\{]|:\s*\{\s*\}\s*[;,)=]" $FILES

# N6: String type for known values (should be union)
check "N6: No string type for status/type/kind fields (use union)" \
    grep -En "(status|type|kind|state|mode):\s*string\s*[;,)]" $FILES

# N7: Function without return type (exported functions)
check "N7: Exported functions must have return type" \
    bash -c "
    grep -En '^export (async )?function \w+\([^)]*\)\s*\{' $FILES | grep -v '):'
    "

# N8: Implicit any in callbacks - only flag high-confidence cases
# (JSON.parse and 'as any' are definitively untyped; typed arrays infer correctly)
check "N8: No implicit any in callbacks (JSON.parse, as any)" \
    bash -c "
    grep -En 'JSON\.parse\([^)]*\)\.(map|filter|reduce|forEach|find|some|every)\(' $FILES | grep -v 'flight:ok'
    grep -En 'as any\)\.(map|filter|reduce|forEach|find|some|every)\(' $FILES | grep -v 'flight:ok'
    " 2>/dev/null

# N9: console.log
check "N9: No console.log in source files" \
    grep -En "console\.(log|warn|error)" $FILES

# N10: Redundant boolean comparison
check "N10: No '=== true' or '=== false'" \
    grep -En "===\s*true|===\s*false|!==\s*true|!==\s*false" $FILES

echo ""
echo "## MUST Rules (warnings)"

# M1: tsconfig strict mode check
# Note: Vite projects put strict:true in tsconfig.app.json, not tsconfig.json
warn "M1: tsconfig should have strict: true enabled" \
    bash -c "
    STRICT_FOUND=false

    # Check tsconfig.json
    if [ -f tsconfig.json ]; then
        if grep -qE '\"strict\"[[:space:]]*:[[:space:]]*true' tsconfig.json 2>/dev/null; then
            STRICT_FOUND=true
        fi
    fi

    # Check tsconfig.app.json (Vite projects use this for app-specific config)
    if [ -f tsconfig.app.json ]; then
        if grep -qE '\"strict\"[[:space:]]*:[[:space:]]*true' tsconfig.app.json 2>/dev/null; then
            STRICT_FOUND=true
        fi
    fi

    # Only warn if at least one tsconfig exists but neither has strict:true
    if [ \"\$STRICT_FOUND\" = false ]; then
        if [ -f tsconfig.json ] || [ -f tsconfig.app.json ]; then
            echo 'No tsconfig file has strict: true enabled'
        fi
    fi
    "

# M2: Type guards for unknown
warn "M2: 'unknown' type should have type guard nearby" \
    bash -c "
    for f in $FILES; do
        if grep -q ': unknown' \"\$f\"; then
            if ! grep -q 'is [A-Z]' \"\$f\"; then
                echo \"\$f: uses 'unknown' but no type guard found\"
            fi
        fi
    done
    "

# M3: Prefer interface for objects
warn "M3: Object shapes should use interface (not type)" \
    bash -c "
    for f in $FILES; do
        # type X = { ... } is often better as interface
        grep -n 'type [A-Z][a-zA-Z]* = {' \"\$f\" | head -3
    done
    "

# M4: Use readonly for function params that shouldn't mutate
warn "M4: Array params should consider readonly" \
    bash -c "
    for f in $FILES; do
        grep -En 'function.*\([^)]*:\s*[A-Za-z]+\[\]' \"\$f\" | grep -v 'readonly' | head -3
    done
    "

echo ""
echo "## Info"

# Type definitions count
TYPE_COUNT=$(grep -cE "^(export )?(type|interface) " $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Types/Interfaces defined: ${TYPE_COUNT:-0}"

# Any count
ANY_COUNT=$(grep -oE ": any|as any|<any>" $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  'any' usage count: ${ANY_COUNT:-0}"

# Unknown count  
UNKNOWN_COUNT=$(grep -oE ": unknown" $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  'unknown' usage count: ${UNKNOWN_COUNT:-0}"

# Type guards
GUARD_COUNT=$(grep -cE "is [A-Z][a-zA-Z]+" $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Type guards: ${GUARD_COUNT:-0}"

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
