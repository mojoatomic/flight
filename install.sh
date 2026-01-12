#!/bin/bash
set -e

REPO="https://github.com/mojoatomic/flight.git"
TMP="/tmp/flight-$$"

echo "Installing Flight..."

git clone --depth 1 "$REPO" "$TMP" 2>/dev/null

cp -r "$TMP/.flight" .
cp -r "$TMP/.claude" .
[ ! -f CLAUDE.md ] && cp "$TMP/CLAUDE.md" .
[ ! -f PROMPT.md ] && cp "$TMP/PROMPT.md" . 2>/dev/null || true
[ ! -f @fix_plan.md ] && cp "$TMP/@fix_plan.md" . 2>/dev/null || true

rm -rf "$TMP"

echo "✅ Flight installed"
echo ""
echo "Commands:"
echo "  /flight-prime     - Research task and context"
echo "  /flight-compile   - Build PROMPT.md"
echo "  /flight-validate  - Run domain validation"
echo "  /flight-tighten   - Strengthen rules on failure"
