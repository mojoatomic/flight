#!/bin/bash
# nextjs.validate.sh - Validate Next.js App Router patterns
set -uo pipefail

# Default to app directory structure
FILES="${@:-app/**/*.tsx app/**/*.ts app/*.tsx app/*.ts}"
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
echo "  Next.js Domain Validation"
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

# N1: use client on page.tsx (should push boundary down)
check "N1: No 'use client' in page.tsx files" \
    bash -c "
    for f in \$(echo '$FILES' | tr ' ' '\n' | grep 'page\.tsx\$'); do
        if head -5 \"\$f\" | grep -q \"'use client'\|\\\"use client\\\"\"; then
            echo \"\$f: page.tsx should be server component\"
        fi
    done
    "

# N2: useState/useEffect in files without 'use client'
check "N2: No React hooks in server components" \
    bash -c "
    for f in $FILES; do
        if ! grep -q \"'use client'\|\\\"use client\\\"\" \"\$f\"; then
            if grep -qE 'useState|useEffect|useRef|useCallback|useMemo|useReducer' \"\$f\"; then
                echo \"\$f: has hooks but no 'use client'\"
            fi
        fi
    done
    "

# N3: useEffect with fetch for initial data (should use server component)
check "N3: No useEffect fetch for initial page data" \
    grep -lE "useEffect.*fetch\(|useEffect.*axios|useEffect.*useSWR" $FILES 2>/dev/null | head -5

# N4: Direct env access in client components
check "N4: No process.env in client components (except NEXT_PUBLIC_)" \
    bash -c "
    for f in $FILES; do
        if grep -q \"'use client'\|\\\"use client\\\"\" \"\$f\"; then
            if grep -E 'process\.env\.' \"\$f\" | grep -v 'NEXT_PUBLIC_'; then
                echo \"\$f: uses non-public env in client\"
            fi
        fi
    done
    "

# N5: any type in route handlers
check "N5: No 'any' type in route handlers" \
    bash -c "
    for f in \$(echo '$FILES' | tr ' ' '\n' | grep 'route\.ts\$'); do
        if grep -n ': any' \"\$f\"; then
            echo \"\$f\"
        fi
    done
    "

# N6: Hardcoded routes (look for string paths in Link/router.push)
check "N6: No hardcoded multi-segment routes" \
    grep -En "href=['\"][^'\"]+/[^'\"]+/[^'\"]+['\"]|push\(['\"][^'\"]+/[^'\"]+/[^'\"]+['\"]\)" $FILES

# N7: Missing notFound() for dynamic routes
warn "N7: Dynamic routes should use notFound() for missing resources" \
    bash -c "
    for f in \$(echo '$FILES' | tr ' ' '\n' | grep '\[.*\].*page\.tsx\$'); do
        if ! grep -q 'notFound' \"\$f\"; then
            echo \"\$f: dynamic route without notFound()\"
        fi
    done
    "

# N8: console.log in app directory
check "N8: No console.log in app directory" \
    grep -rn "console\.log" $FILES 2>/dev/null | grep -v node_modules | head -5

# N9: Sequential awaits that could be parallel
warn "N9: Consider Promise.all for independent fetches" \
    bash -c "
    for f in $FILES; do
        # Look for multiple await statements in sequence
        count=\$(grep -c 'await ' \"\$f\" 2>/dev/null || echo 0)
        if [ \"\$count\" -gt 3 ]; then
            if ! grep -q 'Promise.all' \"\$f\"; then
                echo \"\$f: \$count awaits without Promise.all\"
            fi
        fi
    done
    "

# N10: Fat route handlers (>50 lines)
check "N10: Route handlers should be thin (<50 lines)" \
    bash -c "
    for f in \$(echo '$FILES' | tr ' ' '\n' | grep 'route\.ts\$'); do
        lines=\$(wc -l < \"\$f\")
        if [ \"\$lines\" -gt 50 ]; then
            echo \"\$f: \$lines lines (max 50)\"
        fi
    done
    "

echo ""
echo "## Structure Checks"

# S1: Check for loading.tsx in app subdirectories
warn "S1: Directories with page.tsx should have loading.tsx" \
    bash -c "
    find app -name 'page.tsx' 2>/dev/null | while read page; do
        dir=\$(dirname \"\$page\")
        if [ ! -f \"\$dir/loading.tsx\" ]; then
            echo \"\$dir: missing loading.tsx\"
        fi
    done | head -5
    "

# S2: Check for error.tsx in app subdirectories
warn "S2: Directories with page.tsx should have error.tsx" \
    bash -c "
    find app -name 'page.tsx' 2>/dev/null | while read page; do
        dir=\$(dirname \"\$page\")
        if [ ! -f \"\$dir/error.tsx\" ]; then
            echo \"\$dir: missing error.tsx\"
        fi
    done | head -5
    "

# S3: Server-only marker on sensitive files
warn "S3: Database/auth files should import 'server-only'" \
    bash -c "
    for f in lib/db.ts lib/auth.ts lib/database.ts; do
        if [ -f \"\$f\" ]; then
            if ! grep -q \"import 'server-only'\" \"\$f\"; then
                echo \"\$f: should import 'server-only'\"
            fi
        fi
    done
    "

echo ""
echo "## Info"

# Server vs client components
SERVER_COUNT=$(grep -rL "'use client'\|\"use client\"" $FILES 2>/dev/null | wc -l | tr -d ' ')
CLIENT_COUNT=$(grep -rl "'use client'\|\"use client\"" $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Server components: $SERVER_COUNT"
echo "ℹ️  Client components: $CLIENT_COUNT"

# Route handlers
ROUTE_COUNT=$(echo "$FILES" | tr ' ' '\n' | grep -c 'route\.ts$' || echo 0)
echo "ℹ️  Route handlers: $ROUTE_COUNT"

# Server actions
ACTION_COUNT=$(grep -rl "'use server'" $FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Server action files: $ACTION_COUNT"

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
