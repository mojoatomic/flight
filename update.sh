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

# Update FLIGHT.md (core methodology)
[ -f "$TMP/.flight/FLIGHT.md" ] && cp "$TMP/.flight/FLIGHT.md" .flight/FLIGHT.md

# Update validate-all.sh
[ -f "$TMP/.flight/validate-all.sh" ] && cp "$TMP/.flight/validate-all.sh" .flight/validate-all.sh

# Update all domain files from source (preserves custom domains not in source)
# This copies both .md and .validate.sh files - no hardcoded list needed
for file in "$TMP/.flight/domains/"*.md "$TMP/.flight/domains/"*.sh; do
    [ -f "$file" ] && cp "$file" .flight/domains/
done

# Update examples, exercises, templates (learning resources)
[ -d "$TMP/.flight/examples" ] && cp -r "$TMP/.flight/examples" .flight/
[ -d "$TMP/.flight/exercises" ] && cp -r "$TMP/.flight/exercises" .flight/
[ -d "$TMP/.flight/templates" ] && cp -r "$TMP/.flight/templates" .flight/

# Make scripts executable
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true
chmod +x .flight/domains/*.sh 2>/dev/null || true

rm -rf "$TMP"

echo "✅ Flight updated"
echo ""
echo "Updated:"
echo "  - .claude/commands/* (all slash commands)"
echo "  - .flight/FLIGHT.md (core methodology)"
echo "  - .flight/validate-all.sh"
echo "  - .flight/domains/* (all stock domains)"
echo "  - .flight/examples/, exercises/, templates/"
echo ""
echo "Preserved:"
echo "  - CLAUDE.md (your project description)"
echo "  - PROMPT.md, PRIME.md (your working files)"
echo "  - Custom domains (any .md/.sh not in Flight repo)"
