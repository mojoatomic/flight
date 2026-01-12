#!/bin/bash
# sql.validate.sh - Validate SQL and database code against domain rules
set -uo pipefail

# Check both .sql files and source files that might contain SQL
SQL_FILES="${@:-*.sql **/*.sql}"
SRC_FILES="*.js *.ts *.tsx *.py **/*.js **/*.ts **/*.tsx **/*.py"
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
echo "  SQL Domain Validation"
echo "═══════════════════════════════════════════"
echo ""

# Expand globs
EXPANDED_SQL=$(ls $SQL_FILES 2>/dev/null || true)
EXPANDED_SRC=$(ls $SRC_FILES 2>/dev/null || true)
ALL_FILES="$EXPANDED_SQL $EXPANDED_SRC"
ALL_FILES=$(echo "$ALL_FILES" | xargs -n1 | sort -u | xargs)

if [ -z "$ALL_FILES" ] || [ "$ALL_FILES" = " " ]; then
    red "No files found"
    exit 1
fi

SQL_COUNT=$(echo "$EXPANDED_SQL" | wc -w | tr -d ' ')
SRC_COUNT=$(echo "$EXPANDED_SRC" | wc -w | tr -d ' ')
echo "SQL files: $SQL_COUNT"
echo "Source files: $SRC_COUNT"
echo ""

echo "## NEVER Rules"

# N1: SELECT * (in SQL files and source)
check "N1: No SELECT * (use explicit columns)" \
    grep -Ein "SELECT\s+\*\s+FROM" $ALL_FILES

# N2: String interpolation in queries (JS/TS/Python)
check "N2: No string interpolation in SQL (SQL injection risk)" \
    bash -c "
    for f in $EXPANDED_SRC; do
        # Template literals with SQL keywords
        grep -En '\`[^\`]*SELECT.*\\\$\{|\`[^\`]*INSERT.*\\\$\{|\`[^\`]*UPDATE.*\\\$\{|\`[^\`]*DELETE.*\\\$\{' \"\$f\" 2>/dev/null
        # String concat with SQL
        grep -En \"SELECT.*\\\"\\s*\\+|INSERT.*\\\"\\s*\\+|UPDATE.*\\\"\\s*\\+|DELETE.*\\\"\\s*\\+\" \"\$f\" 2>/dev/null
        # Python f-strings with SQL
        grep -En 'f\"[^\"]*SELECT.*\{|f\"[^\"]*INSERT.*\{|f\"[^\"]*UPDATE.*\{' \"\$f\" 2>/dev/null
    done
    " | head -10

# N3: UPDATE/DELETE without WHERE
check "N3: No UPDATE/DELETE without WHERE clause" \
    bash -c "
    for f in $ALL_FILES; do
        # Simple check: DELETE FROM table; without WHERE
        grep -Ein 'DELETE\s+FROM\s+\w+\s*;' \"\$f\" 2>/dev/null
        # UPDATE without WHERE on same line (basic check)
        grep -Ein 'UPDATE\s+\w+\s+SET\s+.*;\s*$' \"\$f\" 2>/dev/null | grep -iv 'WHERE'
    done
    " | head -5

# N4: LIKE with leading wildcard
check "N4: No LIKE '%...' (leading wildcard can't use index)" \
    grep -Ein "LIKE\s+['\"]%[^'\"]+['\"]" $ALL_FILES

# N5: Functions on indexed columns in WHERE
check "N5: No functions on columns in WHERE (kills index)" \
    grep -Ein "WHERE.*(YEAR|MONTH|DAY|LOWER|UPPER|TRIM)\s*\(" $ALL_FILES

# N6: OFFSET for pagination (in large values)
check "N6: No large OFFSET values (use cursor pagination)" \
    grep -Ein "OFFSET\s+[0-9]{4,}|OFFSET\s+\\\$" $ALL_FILES

# N7: Plain text password storage
check "N7: No plain 'password' column (use password_hash)" \
    bash -c "
    for f in $EXPANDED_SQL; do
        grep -Ein 'password\s+(varchar|text|char)' \"\$f\" 2>/dev/null | grep -iv 'password_hash\|password_digest\|hashed_password'
    done
    "

# N8: Boolean columns without NOT NULL DEFAULT
warn "N8: Boolean columns should have NOT NULL DEFAULT" \
    bash -c "
    for f in $EXPANDED_SQL; do
        grep -Ein '\s+boolean\s*[,)]' \"\$f\" 2>/dev/null | grep -iv 'NOT NULL'
    done
    "

# N9: Missing RLS on tables with user_id
warn "N9: Tables with user_id should have RLS enabled" \
    bash -c "
    for f in $EXPANDED_SQL; do
        if grep -qi 'user_id.*REFERENCES\|user_id\s+uuid' \"\$f\"; then
            if ! grep -qi 'ENABLE ROW LEVEL SECURITY' \"\$f\"; then
                echo \"\$f: has user_id but no RLS\"
            fi
        fi
    done
    "

# N10: timestamp without timezone
check "N10: No 'timestamp' without timezone (use timestamptz)" \
    bash -c "
    for f in $EXPANDED_SQL; do
        grep -Ein '\stimestamp\s' \"\$f\" 2>/dev/null | grep -iv 'timestamptz\|timestamp with time zone'
    done
    "

# N11: float for money
check "N11: No float/real for money (use decimal)" \
    bash -c "
    for f in $EXPANDED_SQL; do
        grep -Ein '(price|cost|total|amount|balance|fee|rate)\s+(float|real|double)' \"\$f\" 2>/dev/null
    done
    "

# N12: Missing index on foreign key
warn "N12: Foreign keys should have indexes" \
    bash -c "
    for f in $EXPANDED_SQL; do
        # Find REFERENCES, check if CREATE INDEX exists for same column
        grep -Eo '[a-z_]+\s+uuid\s+REFERENCES' \"\$f\" 2>/dev/null | while read -r line; do
            col=\$(echo \"\$line\" | awk '{print \$1}')
            if ! grep -qi \"INDEX.*\$col\" \"\$f\"; then
                echo \"\$f: \$col has FK but no index\"
            fi
        done
    done
    " | head -5

echo ""
echo "## Source Code Checks"

# S1: N+1 query pattern (query in loop)
warn "S1: Potential N+1 queries (query inside loop)" \
    bash -c "
    for f in $EXPANDED_SRC; do
        # Simple check: await query/select/execute appearing after for/while on nearby lines
        awk '/for\s*\(|while\s*\(|for .* in/{inloop=5} inloop>0{inloop--; if(/await.*(query|select|execute|from\()/) print FILENAME\":\"NR\": \"$0}' \"\$f\"
    done
    " | head -5

# S2: Missing transaction for multiple writes
warn "S2: Multiple writes should use transactions" \
    bash -c "
    for f in $EXPANDED_SRC; do
        # Multiple INSERT/UPDATE in same function without BEGIN/transaction
        inserts=\$(grep -c 'INSERT INTO\|UPDATE.*SET' \"\$f\" 2>/dev/null || echo 0)
        if [ \"\$inserts\" -gt 2 ]; then
            if ! grep -qi 'BEGIN\|transaction\|\.transaction' \"\$f\"; then
                echo \"\$f: \$inserts writes without transaction\"
            fi
        fi
    done
    "

# S3: Supabase without explicit column select
warn "S3: Supabase .select() should specify columns" \
    grep -En "\.select\(\s*\)" $EXPANDED_SRC 2>/dev/null | head -5

echo ""
echo "## Info"

# Table count
TABLE_COUNT=$(grep -ci "CREATE TABLE" $EXPANDED_SQL 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Tables defined: ${TABLE_COUNT:-0}"

# Index count
INDEX_COUNT=$(grep -ci "CREATE INDEX" $EXPANDED_SQL 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Indexes defined: ${INDEX_COUNT:-0}"

# RLS policies
RLS_COUNT=$(grep -ci "CREATE POLICY" $EXPANDED_SQL 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  RLS policies: ${RLS_COUNT:-0}"

# Parameterized query usage
PARAM_COUNT=$(grep -oE '\$[0-9]+|\?\s*,' $ALL_FILES 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Parameterized placeholders: ${PARAM_COUNT:-0}"

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
