#!/bin/bash
# rp2040-pico.validate.sh - Validate RP2040 Pico dual-core patterns
set -uo pipefail

FILES="${@:-src/**/*.c src/**/*.h src/*.c src/*.h}"
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
echo "  RP2040 Pico Domain Validation"
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

# N1: No malloc/free - static allocation only
check "N1: No malloc/free (static allocation only)" \
    grep -En "\bmalloc\s*\(|\bfree\s*\(|\bcalloc\s*\(|\brealloc\s*\(" $FILES

# N2: No blocking calls in Core 0 (safety core) files
warn "N2: Review blocking calls in safety/core0 files" \
    bash -c "
    for f in $FILES; do
        if echo \"\$f\" | grep -qiE 'main\.c|safety|core0'; then
            grep -En 'sleep_ms|_blocking\(|while\s*\(\s*true|for\s*\(\s*;\s*;\s*\)' \"\$f\" 2>/dev/null | head -5
        fi
    done
    "

# N3: No printf/puts in interrupt handlers
check "N3: No printf in interrupt handlers" \
    bash -c "
    for f in $FILES; do
        # Look for printf/puts near _callback or _isr or _handler functions
        awk '/void.*(_callback|_isr|_handler|_irq)\s*\(/,/^\}/ { if (/printf|puts|print/) print FILENAME\":\"NR\": \"$0 }' \"\$f\"
    done
    "

# N4: No floating point in safety-critical paths
warn "N4: Review float/double in safety files" \
    bash -c "
    for f in $FILES; do
        if echo \"\$f\" | grep -qiE 'safety|emergency|watchdog|core0'; then
            grep -En '\bfloat\b|\bdouble\b' \"\$f\" 2>/dev/null
        fi
    done
    "

# N5: No recursive functions (function calling itself)
check "N5: No recursive functions" \
    bash -c "
    for f in $FILES; do
        # Extract function names and check if they call themselves
        awk '/^[a-zA-Z_][a-zA-Z0-9_]*\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(/ {
            match(\$0, /([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, arr)
            if (arr[1] != \"\") fname = arr[1]
        }
        fname && \$0 ~ fname\"\\s*\\(\" && !/^[a-zA-Z_]/ {
            print FILENAME\":\"NR\": possible recursion in \"fname
        }' \"\$f\" 2>/dev/null
    done
    " | head -5

# N6: No direct register access (use SDK)
check "N6: No direct register access (use hardware_* APIs)" \
    grep -En '\*\s*\(volatile\s+uint32_t\s*\*\)|0x[0-9a-fA-F]+\s*=' $FILES | grep -v '#define'

# N7: No unbounded loops without exit condition
warn "N7: Review unbounded while(true) loops" \
    grep -En 'while\s*\(\s*1\s*\)|while\s*\(\s*true\s*\)|for\s*\(\s*;\s*;\s*\)' $FILES

echo ""
echo "## MUST Rules"

# M1: Core 0 must have watchdog
check "M1: Core 0 (main.c) must use watchdog" \
    bash -c "
    for f in $FILES; do
        if echo \"\$f\" | grep -q 'main\.c'; then
            if ! grep -q 'watchdog_enable\|watchdog_update' \"\$f\"; then
                echo \"\$f: missing watchdog\"
            fi
        fi
    done
    "

# M2: Multicore launch must have handshake
warn "M2: Multicore launch should have handshake" \
    bash -c "
    for f in $FILES; do
        if grep -q 'multicore_launch_core1' \"\$f\"; then
            if ! grep -q 'multicore_fifo_pop\|multicore_fifo_push' \"\$f\"; then
                echo \"\$f: multicore launch without FIFO handshake\"
            fi
        fi
    done
    "

# M3: Shared state must use spinlocks
warn "M3: Shared volatile state should use spinlocks" \
    bash -c "
    for f in $FILES; do
        if grep -q 'volatile.*g_\|static.*volatile' \"\$f\"; then
            if ! grep -q 'spin_lock\|spinlock' \"\$f\"; then
                echo \"\$f: has volatile globals but no spinlock\"
            fi
        fi
    done
    "

# M4: Buffer sizes defined with #define
check "M4: Arrays should have #define size constants" \
    bash -c "
    for f in $FILES; do
        # Find arrays with magic number sizes
        grep -En '\[[0-9]+\]' \"\$f\" 2>/dev/null | grep -v '#define\|//\|/\*' | head -5
    done
    "

# M5: Functions must have assertions for pointer params
warn "M5: Functions with pointer params should ASSERT non-null" \
    bash -c "
    for f in $FILES; do
        awk '
        /^[a-zA-Z_].*\*[a-zA-Z_]+\)/ {
            func_line = NR; has_ptr = 1
        }
        has_ptr && NR <= func_line + 5 && /ASSERT.*!=.*NULL|assert.*!=.*NULL/ {
            has_ptr = 0
        }
        has_ptr && NR > func_line + 5 && /^\{/ {
            print FILENAME\":\"func_line\": function with pointer param missing ASSERT\"
            has_ptr = 0
        }
        ' \"\$f\" 2>/dev/null
    done
    " | head -5

# M6: I2C/SPI operations should have timeouts
check "M6: I2C/SPI operations must use timeout versions" \
    bash -c "
    for f in $FILES; do
        grep -En 'i2c_write_blocking\(|i2c_read_blocking\(|spi_write_blocking\(|spi_read_blocking\(' \"\$f\" 2>/dev/null | \
        grep -v 'timeout' | head -5
    done
    "

# M7: Status return values must be checked
warn "M7: Function calls returning status_t should be checked" \
    bash -c "
    for f in $FILES; do
        # Find status_t function calls that aren't assigned or checked
        grep -En '^\s+[a-z_]+\s*\([^;]*\)\s*;' \"\$f\" 2>/dev/null | \
        grep -v 'if\s*(\|=\s*\|void\|return' | head -5
    done
    "

echo ""
echo "## Structure Checks"

# S1: Check for dual-core structure
warn "S1: Should have main.c (Core 0) and core1.c (Core 1)" \
    bash -c "
    if ! ls $FILES 2>/dev/null | grep -q 'main\.c'; then
        echo 'Missing main.c (Core 0 entry)'
    fi
    if ! ls $FILES 2>/dev/null | grep -qE 'core1\.c|core_1\.c'; then
        echo 'Missing core1.c (Core 1 entry)'
    fi
    "

# S2: Check for emergency handling
warn "S2: Should have emergency/safety handling" \
    bash -c "
    if ! grep -rl 'emergency\|EMERGENCY' $FILES 2>/dev/null | head -1 | grep -q '.'; then
        echo 'No emergency handling found'
    fi
    "

# S3: Check for heartbeat mechanism
warn "S3: Should have inter-core heartbeat" \
    bash -c "
    if ! grep -rl 'heartbeat\|HEARTBEAT' $FILES 2>/dev/null | head -1 | grep -q '.'; then
        echo 'No heartbeat mechanism found'
    fi
    "

echo ""
echo "## Info"

# Function count
FUNC_COUNT=$(grep -cE '^[a-zA-Z_][a-zA-Z0-9_]*\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Functions defined: ${FUNC_COUNT:-0}"

# Volatile globals
VOLATILE_COUNT=$(grep -c 'volatile' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Volatile declarations: ${VOLATILE_COUNT:-0}"

# Spinlock usage
SPINLOCK_COUNT=$(grep -c 'spin_lock' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Spinlock usages: ${SPINLOCK_COUNT:-0}"

# Assertion count
ASSERT_COUNT=$(grep -c 'ASSERT\|assert' $FILES 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
echo "ℹ️  Assertions: ${ASSERT_COUNT:-0}"

# Check for P10 compliance reference
if grep -rq 'embedded-c-p10' $FILES 2>/dev/null; then
    echo "ℹ️  P10 domain referenced: yes"
else
    echo "ℹ️  P10 domain referenced: no (consider also validating with embedded-c-p10.validate.sh)"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ $FAIL -eq 0 ]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
echo "═══════════════════════════════════════════"

# Note about combining with P10
echo ""
echo "NOTE: For full safety-critical validation, also run:"
echo "  .flight/domains/embedded-c-p10.validate.sh $@"
echo ""

exit $FAIL
