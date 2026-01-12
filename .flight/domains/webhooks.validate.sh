#!/bin/bash
# webhooks.validate.sh - Webhook design validation
# Checks webhook handlers for security and reliability patterns
set -euo pipefail

# Default: common webhook handler patterns
DEFAULT_PATTERNS="**/webhook*.js **/webhook*.ts **/hooks/**/*.js **/hooks/**/*.ts **/*Webhook*.java **/webhooks.py **/webhook_handler*.py"
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
printf '%s\n' "  Webhook Domain Validation"
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
    yellow "No webhook files found matching default patterns"
    printf '%s\n' "  Patterns: webhook*.js, hooks/**/*.ts, *Webhook*.java, etc."
    printf '\n'
    green "  RESULT: SKIP (no webhook files)"
    exit 0
fi

printf 'Webhook files: %d\n\n' "${#FILES[@]}"

printf '%s\n' "## NEVER Rules (Security)"

# N1: Plain HTTP webhook URLs
check "N1: No plain HTTP webhook URLs" \
    bash -c 'grep -Ein "webhook.*http://[^l]|http://.*webhook" "$@" | grep -v "localhost\|127\.0\.0\.1"' _ "${FILES[@]}"

# N2: Missing signature verification (webhook handler without signature check)
warn "N2: Signature verification present" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "webhook|hook" "$f" 2>/dev/null; then
                if ! grep -qEi "signature|hmac|verify|x-.*-signature|createHmac|hash_hmac" "$f" 2>/dev/null; then
                    echo "$f: webhook handler without signature verification"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# N3: Secrets in webhook payloads
check "N3: No secrets in webhook payloads" \
    grep -Ein "webhook.*password|webhook.*secret|webhook.*api_key|payload.*password|payload.*ssn|payload.*credit.?card" "${FILES[@]}"

# N4: Synchronous processing (process then respond pattern)
warn "N4: Async processing (enqueue before responding)" \
    bash -c '
        for f in "$@"; do
            # Look for patterns where heavy processing happens before response
            if grep -qEi "await.*process|await.*handle|await.*save.*res\.(send|status|json)" "$f" 2>/dev/null; then
                if ! grep -qEi "queue|enqueue|publish|dispatch|bull|sqs|rabbitmq|kafka" "$f" 2>/dev/null; then
                    echo "$f: possible sync processing before response"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# N5: No idempotency handling
warn "N5: Idempotency handling present" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "webhook|hook" "$f" 2>/dev/null; then
                if ! grep -qEi "idempoten|delivery.?id|webhook.?id|x-.*-id|dedup|already.?processed" "$f" 2>/dev/null; then
                    echo "$f: no idempotency handling detected"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# N6: String comparison for signatures (timing attack)
check "N6: No unsafe signature comparison (use timingSafeEqual)" \
    grep -Ein "signature\s*(===?|!==?)\s*(expected|computed|hash)|signature\.equals\(" "${FILES[@]}"

# N7: Infinite retry without backoff
check "N7: No infinite retry without backoff" \
    grep -Ein "while.*true.*send|while.*retry.*webhook|for\s*\(;;\).*webhook" "${FILES[@]}"

# N8: SSRF - accepting internal/private IPs without validation
warn "N8: URL/IP validation for SSRF prevention" \
    bash -c '
        for f in "$@"; do
            # Check if file handles webhook URLs/registration
            if grep -qEi "webhook.*url|url.*webhook|register.*hook|endpoint" "$f" 2>/dev/null; then
                if ! grep -qEi "isPrivate|privateIP|private.*range|internal.*ip|isValidUrl|validateUrl|blockList|allowList|dns\.resolve|dns\.lookup" "$f" 2>/dev/null; then
                    echo "$f: webhook URL handling without IP validation"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# N9: Non-HTTPS schemes in webhook URLs
check "N9: No non-HTTPS URL schemes" \
    grep -Ein "webhook.*file://|webhook.*ftp://|webhook.*gopher://|url.*file://|endpoint.*http://[^l]" "${FILES[@]}"

printf '\n%s\n' "## MUST Rules (Reliability)"

# M1: Event type in payload or handling
warn "M1: Event type handling present" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "webhook|hook" "$f" 2>/dev/null; then
                if ! grep -qEi "event.?type|event_type|eventType|\.type|\.event|x-.*-event" "$f" 2>/dev/null; then
                    echo "$f: no event type handling detected"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# M2: Timestamp handling
warn "M2: Timestamp handling present" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "webhook|hook" "$f" 2>/dev/null; then
                if ! grep -qEi "timestamp|created.?at|x-.*-timestamp|time" "$f" 2>/dev/null; then
                    echo "$f: no timestamp handling detected"
                fi
            fi
        done
    ' _ "${FILES[@]}"

# M3: HMAC/signature generation (for providers)
warn "M3: HMAC signature implementation" \
    bash -c 'grep -qEi "createHmac|hash_hmac|hmac\.new|HMACSHA|HmacUtils" "$@" || echo "No HMAC implementation detected"' _ "${FILES[@]}"

# M4: 2xx response handling
warn "M4: Proper response codes" \
    bash -c 'grep -qEi "status\(200\)|status\(202\)|sendStatus\(200\)|\.ok\(|res\.send\(" "$@" || echo "No 2xx response handling detected"' _ "${FILES[@]}"

# M5: Retry/backoff logic (for providers)
warn "M5: Retry with backoff logic" \
    bash -c 'grep -qEi "backoff|retry|exponential|attempt|max.?retries" "$@" || echo "No retry/backoff logic detected"' _ "${FILES[@]}"

# M6: Dead letter queue
warn "M6: Dead letter queue handling" \
    bash -c 'grep -qEi "dead.?letter|dlq|failed.?queue|poison.?queue" "$@" || echo "No dead letter queue handling detected"' _ "${FILES[@]}"

# M7: URL validation for webhook registration (providers)
warn "M7: Webhook URL validation" \
    bash -c '
        for f in "$@"; do
            if grep -qEi "register.*webhook|webhook.*register|save.*webhook.*url|add.*endpoint" "$f" 2>/dev/null; then
                if ! grep -qEi "validateUrl|isValidUrl|url.*valid|dns\.resolve|lookup|parseUrl" "$f" 2>/dev/null; then
                    echo "$f: webhook registration without URL validation"
                fi
            fi
        done
    ' _ "${FILES[@]}"

printf '\n%s\n' "## SHOULD Rules (Best Practices)"

# S1: Payload size consideration
warn "S1: Consider payload size limits" \
    bash -c 'grep -qEi "payload.?size|max.?size|body.?limit|20.?kb|size.?limit" "$@" || echo "No payload size limits detected"' _ "${FILES[@]}"

# S2: Logging
warn "S2: Webhook logging present" \
    bash -c 'grep -qEi "log.*webhook|webhook.*log|logger|console\.(log|info|error).*webhook" "$@" || echo "No webhook-specific logging detected"' _ "${FILES[@]}"

# S3: Secret rotation support
warn "S3: Secret rotation support" \
    bash -c 'grep -qEi "rotate|multiple.?secret|old.?secret|new.?secret|secret.?version" "$@" || echo "No secret rotation support detected"' _ "${FILES[@]}"

# S4: Timing safe comparison function used
warn "S4: Timing-safe comparison used" \
    bash -c 'grep -qEi "timingSafeEqual|constant.?time|secure.?compare|MessageDigest\.isEqual|hmac\.compare" "$@" || echo "No timing-safe comparison detected"' _ "${FILES[@]}"

# S5: Queue integration
warn "S5: Queue integration for async processing" \
    bash -c 'grep -qEi "queue|bull|sqs|rabbitmq|kafka|redis.*publish|pub.?sub|enqueue" "$@" || echo "No queue integration detected"' _ "${FILES[@]}"

# S6: Schema validation for incoming webhooks
warn "S6: Schema validation for webhook payloads" \
    bash -c 'grep -qEi "joi|zod|yup|ajv|schema.*valid|validate.*schema|json.?schema" "$@" || echo "No schema validation detected"' _ "${FILES[@]}"

# S7: Verification challenge for webhook registration
warn "S7: Webhook registration verification" \
    bash -c 'grep -qEi "challenge|verification.*webhook|webhook.*verification|verify.*endpoint|test.*webhook" "$@" || echo "No registration verification detected"' _ "${FILES[@]}"

# S8: Egress proxy for webhook delivery (providers)
warn "S8: Egress proxy for webhook delivery" \
    bash -c 'grep -qEi "smokescreen|egress.*proxy|webhook.*proxy|proxy.*webhook|sentry" "$@" || echo "No egress proxy detected (optional but recommended)"' _ "${FILES[@]}"

printf '\n%s\n' "## Info"

HANDLER_COUNT=$( (grep -cEi "webhook|\.on\(['\"]hook" "${FILES[@]}" 2>/dev/null || true) | awk -F: '{s+=$NF}END{print s+0}')
printf 'ℹ️  Webhook handler patterns: %s\n' "$HANDLER_COUNT"

HAS_SIGNATURE=$( (grep -l "signature\|hmac\|createHmac" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with signature handling: %s\n' "$HAS_SIGNATURE"

HAS_QUEUE=$( (grep -l "queue\|bull\|sqs\|rabbitmq\|kafka" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with queue integration: %s\n' "$HAS_QUEUE"

HAS_RETRY=$( (grep -l "retry\|backoff\|attempt" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with retry logic: %s\n' "$HAS_RETRY"

EVENT_TYPES=$( (grep -ohEi "['\"][a-z]+\.(created|updated|deleted|completed|failed|pending)['\"]" "${FILES[@]}" 2>/dev/null || true) | sort -u | wc -l | tr -d ' ')
printf 'ℹ️  Distinct event type patterns: %s\n' "$EVENT_TYPES"

HAS_URL_VALIDATION=$( (grep -l "validateUrl\|isPrivate\|privateIP\|dns\.resolve" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with URL/IP validation: %s\n' "$HAS_URL_VALIDATION"

HAS_SCHEMA=$( (grep -l "joi\|zod\|yup\|ajv\|schema" "${FILES[@]}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  Files with schema validation: %s\n' "$HAS_SCHEMA"

printf '\n%s\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
printf '%s\n' "═══════════════════════════════════════════"

exit "$FAIL"
