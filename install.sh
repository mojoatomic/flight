#!/bin/bash
set -e

REPO="https://github.com/mojoatomic/flight.git"
TMP="/tmp/flight-$$"

echo "Installing Flight..."

git clone --depth 1 "$REPO" "$TMP" 2>/dev/null

cp -r "$TMP/.flight" .
cp -r "$TMP/.claude" .
cp "$TMP/update.sh" .
[ ! -f CLAUDE.md ] && cp "$TMP/CLAUDE.md" .
[ ! -f PROMPT.md ] && cp "$TMP/PROMPT.md" . 2>/dev/null || true
[ ! -f @fix_plan.md ] && cp "$TMP/@fix_plan.md" . 2>/dev/null || true

rm -rf "$TMP"

# Make scripts executable
chmod +x update.sh 2>/dev/null || true
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true

# Add npm scripts if package.json exists
if [ -f package.json ]; then
    if command -v jq &> /dev/null; then
        # Use jq to merge scripts
        jq '.scripts.validate = ".flight/validate-all.sh" |
            .scripts.preflight = "npm run validate && npm run lint"' package.json > package.json.tmp \
            && mv package.json.tmp package.json
        echo "✅ Added npm scripts to package.json"
    else
        echo "⚠️  Add these scripts to package.json manually:"
        echo '    "validate": ".flight/validate-all.sh",'
        echo '    "preflight": "npm run validate && npm run lint"'
    fi
else
    echo "ℹ️  No package.json found - add scripts when you create one"
fi

echo ""
echo "✅ Flight installed"
echo ""
echo "Local CI:"
echo "  npm run validate  - Run all domain validators"
echo "  npm run preflight - Validate + lint before commit"
echo ""
echo "Commands:"
echo "  /flight-prime     - Research task and context"
echo "  /flight-compile   - Build PROMPT.md"
echo "  /flight-validate  - Run domain validation"
echo "  /flight-tighten   - Strengthen rules on failure"
echo ""
echo "Update Flight:  ./update.sh"
echo "Read docs:      .flight/FLIGHT.md"
