#!/bin/bash
# api.validate.sh - API design validation
# Checks route definitions, response handlers, and API patterns
# Note: Using -e requires || true on commands that may return non-zero normally
set -euo pipefail

# Default: common API file patterns
DEFAULT_PATTERNS="**/routes*.js **/routes*.ts **/controller*.js **/controller*.ts **/api/**/*.js **/api/**/*.ts **/*Router*.java **/*Controller*.java **/views.py **/urls.py"
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
        ((PASS++)) || true
    else
        red "❌ $name"
        printf '%s\n' "$result" | head -10 | sed 's/^/   /'
        ((FAIL++)) || true
    fi
}

warn() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++)) || true
    else
        yellow "⚠️  $name"
        printf '%s\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++)) || true
    fi
}

printf '%s\n' "═══════════════════════════════════════════"
printf '%s\n' "  API Design Domain Validation"
printf '%s\n' "═══════════════════════════════════════════"
printf '\n'

# Handle arguments or use defaults
if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    shopt -s nullglob globstar
    FILES=($DEFAULT_PATTERNS)
    shopt -u nullglob globstar
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    yellow "No API files found matching default patterns"
    printf '%s\n' "  Patterns: routes*.js, controller*.ts, api/**/*.js, etc."
    printf '\n'
    green "  RESULT: SKIP (no API files)"
    exit 0
fi

printf 'API files: %d\n\n' "${#FILES[@]}"

# Filter to actual API endpoint files for API-specific checks (M3, S2, S4, S6, S7)
# These checks don't apply to service/utility files that happen to be in the file list
is_api_file() {
    local f="$1"
    # Path-based detection
    if [[ "$f" =~ (api/|routes/|endpoints/|handlers/|controllers/) ]]; then
        return 0
    fi
    # Content-based detection: HTTP method handlers
    # Note: case-sensitive to avoid matching response.json() from fetch calls
    if grep -qE "(app|router)\.(get|post|put|patch|delete)\(|NextResponse|Response\.json|@(Get|Post|Put|Delete|Patch)\(" "$f" 2>/dev/null; then
        return 0
    fi
    return 1
}

API_ENDPOINT_FILES=()
for f in "${FILES[@]}"; do
    if is_api_file "$f"; then
        API_ENDPOINT_FILES+=("$f")
    fi
done

if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    printf 'API endpoint files: %d\n\n' "${#API_ENDPOINT_FILES[@]}"
else
    printf 'API endpoint files: 0 (some checks will be skipped)\n\n'
fi

printf '%s\n' "## NEVER Rules"

# N1: Verbs in URI paths (create, delete, get, update, etc.)
# Catches: POST /createUser, GET /getUsers, router.get('/deleteItem')
# Requires verb + uppercase (camelCase) or verb + separator (snake/kebab)
# Excludes legitimate words like /updated, /getaway, /creator
# Respects flight:ok justification comments
# Note: Must NOT use -i flag as it makes [A-Z] match lowercase
check "N1: No verbs in URI paths" \
    bash -c 'grep -En "['\''\"]/?(create|delete|remove|update|get|fetch|add|edit|modify)([A-Z]|[_-][a-z])" "$@" | grep -v "flight:ok"' _ "${FILES[@]}"

# N2: 200 OK with error body patterns
# Matches error as a property name (error:, "error":, 'error':), not in variable names
check "N2: No 200 status with error responses" \
    grep -Ein "status\(200\).*['\"]?error['\"]?\s*:|\.ok\(.*['\"]?error['\"]?\s*:|status.*200.*success.*false" "${FILES[@]}"

# N3: Exposed auto-increment IDs in pagination
warn "N3: Potential exposed IDs in pagination (use opaque cursors)" \
    grep -Ein "after_id|before_id|since_id|last_id|start_id" "${FILES[@]}"

# N4: Sensitive data in query params (patterns suggesting auth in URL)
# Catches dot notation, bracket notation, and destructuring patterns
check "N4: No sensitive data in query strings" \
    grep -Ein "req\.(query|params)(\.(password|secret|api_key|token|auth)|\[['\"]?(password|secret|api_key|token|auth))|(\{[^}]*(password|secret|api_key|token|auth)[^}]*\})\s*=\s*req\.(query|params)" "${FILES[@]}"

# N5: Offset pagination with high limits
warn "N5: Potential offset pagination (prefer cursor for large datasets)" \
    grep -Ein "offset.*limit|page.*per_page|skip.*take" "${FILES[@]}"

# N6: 500 for client validation errors
check "N6: No 500 status for validation errors" \
    grep -Ein "catch.*\{[^}]*(status\(500\)|res\.status\s*=\s*500)|(ValidationError|validate|invalid).*500|500.*(validation|invalid)" "${FILES[@]}"

# N7: Missing request IDs in error responses (check for error responses without request_id/trace_id)
warn "N7: Error responses should include request/trace IDs" \
    bash -c '
        for f in "$@"; do
            # Look for error response patterns without request_id or trace_id nearby
            if grep -qEi "res\.(status\(4|status\(5|json\(.*error" "$f" 2>/dev/null; then
                if ! grep -qEi "request_id|trace_id|requestId|traceId|x-request-id" "$f" 2>/dev/null; then
                    echo "$f: error responses found but no request/trace ID handling"
                fi
            fi
        done
    ' _ "${FILES[@]}"

printf '\n%s\n' "## MUST Rules"

# M1: Check for plural resource names (basic heuristic)
# Catches singular nouns followed by / or end of path
warn "M1: Use plural nouns for collections" \
    grep -Ein "['\"]/(user|product|order|item|account|customer|payment)(/|['\"])" "${FILES[@]}"

# M2: Check for versioned API paths
warn "M2: API versioning present" \
    bash -c 'grep -qEi "/v[0-9]+/|version.*header|api-version" "$@" || echo "No API versioning detected"' _ "${FILES[@]}"

# M3: Error response structure (should have type/title/status pattern)
# Only applies to actual API endpoint files
if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    warn "M3: Consistent error response format (RFC 7807 pattern)" \
        bash -c 'grep -l "application/problem\+json\|type.*title.*status\|ProblemDetails" "$@" >/dev/null || echo "No RFC 7807 Problem Details pattern found"' _ "${API_ENDPOINT_FILES[@]}"
else
    green "✅ M3: Consistent error response format (skipped - no API endpoint files)"
    ((PASS++)) || true
fi

# M4: Rate limit headers
warn "M4: Rate limit headers present" \
    bash -c 'grep -qEi "x-ratelimit|rate.?limit|retry-after" "$@" || echo "No rate limiting headers detected"' _ "${FILES[@]}"

# M5: Location header on 201 Created
warn "M5: Location header on 201 responses" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "status\(201\)|\.created\(" "$f" 2>/dev/null; then
                if ! grep -qEi "location.*header|header.*location|\.header\(.location" "$f" 2>/dev/null; then
                    echo "$f: 201 responses found but no Location header"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# M6: Content-Type header on responses
warn "M6: Content-Type headers on responses" \
    bash -c 'grep -qEi "content-type|\.type\(|\.json\(" "$@" || echo "No explicit Content-Type handling detected"' _ "${FILES[@]}"

printf '\n%s\n' "## SHOULD Rules"

# S1: HTTP-only URLs (no HTTPS) - fixed pattern
warn "S1: Use HTTPS (no plain HTTP URLs)" \
    bash -c 'grep -Ein "http://[a-zA-Z]" "$@" | grep -v "localhost\|127\.0\.0\.1"' _ "${FILES[@]}"

# S2: ISO 8601 date handling
# Only applies to actual API endpoint files
if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    warn "S2: Use ISO 8601 dates (toISOString pattern present)" \
        bash -c 'grep -l "toISOString\|ISO.*8601\|datetime\|DateTimeFormatter" "$@" >/dev/null || echo "No ISO 8601 date handling detected"' _ "${API_ENDPOINT_FILES[@]}"
else
    green "✅ S2: Use ISO 8601 dates (skipped - no API endpoint files)"
    ((PASS++)) || true
fi

# S3: Consistent casing (detect mixed snake_case and camelCase in same file)
warn "S3: Consistent field naming (no mixed casing)" \
    bash -c '
        for f in "$@"; do
            if grep -qE "\"[a-z]+_[a-z]+\"" "$f" 2>/dev/null && grep -qE "\"[a-z]+[A-Z][a-z]+\"" "$f" 2>/dev/null; then
                echo "$f: mixed snake_case and camelCase"
            fi
        done
    ' _ "${FILES[@]}"

# S4: CORS headers for browser clients
# Only applies to actual API endpoint files
if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    warn "S4: CORS headers present (for browser clients)" \
        bash -c 'grep -qEi "access-control-allow|cors\(|cors\.enable" "$@" || echo "No CORS handling detected"' _ "${API_ENDPOINT_FILES[@]}"
else
    green "✅ S4: CORS headers present (skipped - no API endpoint files)"
    ((PASS++)) || true
fi

# S5: 202 Accepted for long-running operations
warn "S5: Consider 202 Accepted for async operations" \
    bash -c '
        has_async=false
        has_202=false
        for f in "$@"; do
            if grep -qEi "job|queue|worker|async.*process|background" "$f" 2>/dev/null; then
                has_async=true
            fi
            if grep -qEi "status\(202\)|\.accepted\(" "$f" 2>/dev/null; then
                has_202=true
            fi
        done
        if $has_async && ! $has_202; then
            echo "Async/background patterns found but no 202 Accepted responses"
        fi
    ' _ "${FILES[@]}"

# S6: Idempotency keys for POST operations
# Only applies to actual API endpoint files
if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    warn "S6: Idempotency keys for non-idempotent operations" \
        bash -c 'grep -qEi "idempotency|idempotent" "$@" || echo "No idempotency handling detected"' _ "${API_ENDPOINT_FILES[@]}"
else
    green "✅ S6: Idempotency keys (skipped - no API endpoint files)"
    ((PASS++)) || true
fi

# S7: OpenAPI/Swagger spec exists
# Only applies if there are actual API endpoint files
if [[ ${#API_ENDPOINT_FILES[@]} -gt 0 ]]; then
    warn "S7: OpenAPI specification present" \
        bash -c '
            if ! ls openapi.yaml openapi.json swagger.yaml swagger.json api-spec.yaml api-spec.json docs/openapi.* docs/swagger.* 2>/dev/null | head -1 | grep -q .; then
                echo "No OpenAPI/Swagger spec found (openapi.yaml, swagger.json, etc.)"
            fi
        '
else
    green "✅ S7: OpenAPI specification (skipped - no API endpoint files)"
    ((PASS++)) || true
fi

# S8: Hardcoded URLs (should use config/env)
# Excludes comments (lines starting with // # /* *) and common safe domains
warn "S8: No hardcoded API URLs (use config)" \
    bash -c 'grep -EHn "https?://[a-zA-Z0-9][a-zA-Z0-9.-]+\.(com|io|net|org|dev|app)" "$@" | grep -v "localhost\|127\.0\.0\.1\|example\.com" | grep -Ev ":[0-9]+:\s*(//|#|/\*|\*)"' _ "${FILES[@]}"

# S9: CORS wildcard with credentials (security risk)
check "S9: No CORS wildcard (*) with credentials" \
    bash -c '
        for f in "$@"; do
            # Check if file has both wildcard origin AND credentials enabled
            if grep -qEi "origin.*.\*.|Allow-Origin.*\*" "$f" 2>/dev/null; then
                if grep -qEi "credentials.*true|withCredentials" "$f" 2>/dev/null; then
                    echo "$f: CORS wildcard (*) used with credentials enabled"
                fi
            fi
        done
    ' _ "${FILES[@]}"

printf '\n%s\n' "## Info"

ENDPOINT_COUNT=$( (grep -cEi "(get|post|put|patch|delete)\s*\(" "${FILES[@]}" 2>/dev/null || true) | awk -F: '{s+=$NF}END{print s+0}')
printf 'ℹ️  Endpoint definitions: %s\n' "$ENDPOINT_COUNT"

STATUS_CODES=$( (grep -ohE "status\([0-9]{3}\)|\.status\s*=\s*[0-9]{3}" "${FILES[@]}" 2>/dev/null || true) | sort -u | wc -l | tr -d ' ')
printf 'ℹ️  Distinct status codes used: %s\n' "$STATUS_CODES"

HAS_PAGINATION=$( (grep -l "pagination\|cursor\|next_page\|page_token\|has_more" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with pagination: %s\n' "$HAS_PAGINATION"

HAS_AUTH=$( (grep -l "authorization\|authenticate\|bearer\|jwt\|api.?key" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with auth handling: %s\n' "$HAS_AUTH"

HAS_VALIDATION=$( (grep -l "validate\|schema\|joi\|yup\|zod\|class-validator" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with validation: %s\n' "$HAS_VALIDATION"

HAS_REQUEST_ID=$( (grep -li "request.?id\|trace.?id\|correlation.?id\|x-request-id" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with request ID handling: %s\n' "$HAS_REQUEST_ID"

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
