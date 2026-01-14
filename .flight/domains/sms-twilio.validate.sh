#!/usr/bin/env bash
# sms-twilio_validate.sh - SMS consent and Twilio integration validation
set -o pipefail

PASS=0
FAIL=0
WARN=0

if [[ -t 1 ]]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

set -u

# Strip comment-only lines from file (JS/TS/Python)
# Removes: // comments, # comments, /* */ block comment markers
strip_comments() {
    local file="$1"
    grep -v '^\s*//' "$file" 2>/dev/null | \
        grep -v '^\s*#' | \
        grep -v '^\s*\*' | \
        grep -v '^\s*/\*' | \
        grep -v '^\s*\*/'
}

# Check if pattern exists in code (not comments)
code_has_pattern() {
    local file="$1"
    local pattern="$2"
    strip_comments "$file" | grep -qEi "$pattern"
}

check() {
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        printf '%s✅ %s%s\n' "$GREEN" "$name" "$RESET"
        ((PASS++)) || true
    else
        printf '%s❌ %s%s\n' "$RED" "$name" "$RESET"
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
        printf '%s✅ %s%s\n' "$GREEN" "$name" "$RESET"
        ((PASS++)) || true
    else
        printf '%s⚠️  %s%s\n' "$YELLOW" "$name" "$RESET"
        printf '%s\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++)) || true
    fi
}

printf '%s\n' "${BOLD}══════════════════════════════════════════${RESET}"
printf '%s\n' "${BOLD}  SMS/Twilio Validation${RESET}"
printf '%s\n' "${BOLD}══════════════════════════════════════════${RESET}"
printf '\n'

if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    shopt -s nullglob globstar
    FILES=(**/sms*.js **/sms*.ts **/*twilio*.js **/*twilio*.ts **/consent*.js **/consent*.ts **/sms*.py **/twilio*.py)
    shopt -u nullglob globstar
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    printf '%s⚠️  No SMS/Twilio files found%s\n' "$YELLOW" "$RESET"
    printf '%s✅ RESULT: SKIP%s\n' "$GREEN" "$RESET"
    exit 0
fi

printf 'Files: %d\n\n' "${#FILES[@]}"

# =============================================================================
# Consent State Machine (REQUIRED)
# =============================================================================
printf '%s\n' "## Consent State Machine"

check "Consent states defined (OPTED_IN, OPTED_OUT, PENDING, UNKNOWN)" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "OPTED_IN|OPTED_OUT"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No consent states found"
    ' _ "${FILES[@]}"

check "INVARIANT: Never send to OPTED_OUT or UNKNOWN" \
    grep -Ein "OPTED_OUT.*send|UNKNOWN.*send|send.*OPTED_OUT|send.*UNKNOWN" "${FILES[@]}"

check "Consent check before sending" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "sendSMS|send.*message|twilio.*messages.*create"; then
            if ! strip_comments "$f" | grep -qEi "consent|opted.?in|OPTED_IN|getConsent"; then
                printf "%s: sends without consent check\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

# =============================================================================
# Opt-Out Handling (REQUIRED)
# =============================================================================
printf '\n%s\n' "## Opt-Out Handling"

check "STOP keyword triggers state change" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "STOP"; then
            if ! strip_comments "$f" | grep -qEi "OPTED_OUT|updateConsent|setState|optOut"; then
                printf "%s: STOP found but no state change\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

warn "START/UNSTOP keywords handled for re-subscribe" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "START|UNSTOP"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No START/UNSTOP handling"
    ' _ "${FILES[@]}"

warn "HELP keyword response implemented" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "HELP.*response|help.?message|HELP.*reply"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No HELP response"
    ' _ "${FILES[@]}"

# =============================================================================
# Error Code Handling (REQUIRED)
# =============================================================================
printf '\n%s\n' "## Twilio Error Codes"

check "INVARIANT: 21610 (unsubscribed) marks OPTED_OUT, no retry" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "twilio|sendSMS|messages.*create"; then
            if ! strip_comments "$f" | grep -qEi "21610"; then
                printf "%s: no 21610 handling\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

check "INVARIANT: 30004 (blocked) marks OPTED_OUT, no retry" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "twilio|sendSMS|messages.*create"; then
            if ! strip_comments "$f" | grep -qEi "30004"; then
                printf "%s: no 30004 handling\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

check "No retry on opt-out errors" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        result=$(strip_comments "$f" | grep -Ein "21610.*retry|30004.*retry|retry.*21610|retry.*30004" 2>/dev/null) || true
        if [[ -n "$result" ]]; then
            printf "%s:%s\n" "$f" "$result"
        fi
    done
    ' _ "${FILES[@]}"

check "INVARIANT: 30005/30006 marks number INVALID" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "twilio|sendSMS|messages.*create"; then
            if ! strip_comments "$f" | grep -qEi "30005|30006|invalid.*number|landline|INVALID"; then
                printf "%s: no 30005/30006 handling\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

warn "Temporary errors (30003, 30017) retry with backoff" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "30003|30017|backoff|exponential|retry.*delay"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No retry backoff"
    ' _ "${FILES[@]}"

warn "Rate limit errors (30022, 30023, 30027) handled" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "30022|30023|30027|rate.?limit|daily.?cap"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No rate limit handling"
    ' _ "${FILES[@]}"

# =============================================================================
# Required Messages (INVARIANT)
# =============================================================================
printf '\n%s\n' "## Required Messages"

check "First message includes opt-out instructions" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "first.?message|welcome|initial|confirm.*message"; then
            if ! strip_comments "$f" | grep -qEi "STOP|opt.?out|unsubscribe"; then
                printf "%s: first message may lack opt-out\n" "$f"
            fi
        fi
    done
    ' _ "${FILES[@]}"

warn "Business name included in messages" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "business.?name|brand|company.*:"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No business name in messages"
    ' _ "${FILES[@]}"

warn "Opt-out confirmation message defined" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "unsubscribed|opt.?out.*confirm|OPT_OUT_CONFIRMED"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No opt-out confirmation"
    ' _ "${FILES[@]}"

# =============================================================================
# Security (INVARIANT)
# =============================================================================
printf '\n%s\n' "## Security"

check "No hardcoded phone numbers" \
    grep -Ein '"\+1[0-9]{10}"|'\''\+1[0-9]{10}'\''' "${FILES[@]}"

check "No hardcoded Twilio credentials" \
    grep -Ein "ACCOUNT_SID\s*=\s*['\"]AC|AUTH_TOKEN\s*=\s*['\"][a-f0-9]{32}" "${FILES[@]}"

# =============================================================================
# Compliance (SHOULD)
# =============================================================================
printf '\n%s\n' "## Compliance"

warn "Double opt-in flow implemented" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "double.?opt|PENDING.*OPTED_IN|confirm.*yes|reply.*yes"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No double opt-in"
    ' _ "${FILES[@]}"

warn "Message logging for audit" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "log.*message|audit|sms_log|message.*log"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No message logging"
    ' _ "${FILES[@]}"

warn "Consent timestamps tracked" \
    bash -c '
    strip_comments() {
        grep -v "^\s*//" "$1" 2>/dev/null | grep -v "^\s*#" | grep -v "^\s*\*"
    }
    found=0
    for f in "$@"; do
        if strip_comments "$f" | grep -qEi "opted_in_at|opted_out_at|consent.*time|timestamp"; then
            found=1
            break
        fi
    done
    [[ $found -eq 0 ]] && echo "No consent timestamps"
    ' _ "${FILES[@]}"

# =============================================================================
# Summary
# =============================================================================
printf '\n%s\n' "${BOLD}══════════════════════════════════════════${RESET}"
printf '  PASS: %d  FAIL: %d  WARN: %d\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    printf '%s  RESULT: PASS%s\n' "$GREEN" "$RESET"
else
    printf '%s  RESULT: FAIL%s\n' "$RED" "$RESET"
fi
printf '%s\n' "${BOLD}══════════════════════════════════════════${RESET}"

exit "$FAIL"
