#!/bin/bash
set -e

REPO="https://github.com/mojoatomic/flight.git"
TMP="/tmp/flight-update-$$"

echo "Updating Flight..."

git clone --depth 1 "$REPO" "$TMP" 2>/dev/null

# Ensure target directories exist
mkdir -p .claude/commands .flight/domains

# Update commands (always safe to overwrite)
cp -r "$TMP/.claude/commands/"* .claude/commands/ 2>/dev/null || true

# Update core domains (overwrite stock ones, preserve custom)
for domain in api bash code-hygiene embedded-c-p10 javascript nextjs python react react-line-formulas rp2040-pico scaffold sms-twilio sql testing typescript webhooks; do
    [ -f "$TMP/.flight/domains/${domain}.md" ] && cp "$TMP/.flight/domains/${domain}.md" .flight/domains/
    [ -f "$TMP/.flight/domains/${domain}.validate.sh" ] && cp "$TMP/.flight/domains/${domain}.validate.sh" .flight/domains/
done

# Update validate-all.sh
[ -f "$TMP/.flight/validate-all.sh" ] && cp "$TMP/.flight/validate-all.sh" .flight/validate-all.sh

# Make scripts executable
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true

rm -rf "$TMP"

echo "✅ Flight updated"
echo ""
echo "Updated:"
echo "  - .claude/commands/*"
echo "  - .flight/domains/ (core domains only)"
echo "  - .flight/validate-all.sh"
echo ""
echo "Preserved:"
echo "  - CLAUDE.md"
echo "  - PROMPT.md"
echo "  - Custom domains"
