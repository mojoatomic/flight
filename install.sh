#!/bin/bash
# install.sh - Install Flight into a project
set -euo pipefail

readonly REPO="https://github.com/mojoatomic/flight.git"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
    local exit_code=$?
    rm -rf "$TMP_DIR"
    exit "$exit_code"
}
trap cleanup EXIT

echo "Installing Flight..."

git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null

# Copy Flight core
cp -r "$TMP_DIR/.flight" .
cp -r "$TMP_DIR/.claude" .
cp "$TMP_DIR/update.sh" .

# Copy flight-lint (AST validation tool)
if [[ -d "$TMP_DIR/flight-lint" ]]; then
    cp -r "$TMP_DIR/flight-lint" .
    echo "Building flight-lint..."
    echo "  Installing dependencies (including tree-sitter native modules)..."
    (cd flight-lint && npm install --include=optional) || {
        echo "Warning: npm install had issues. tree-sitter requires build tools."
        echo "  On macOS: xcode-select --install"
        echo "  On Ubuntu: apt-get install build-essential"
    }
    echo "  Compiling TypeScript..."
    (cd flight-lint && npm run build) || {
        echo "Warning: flight-lint build failed. AST rules will be skipped."
    }
fi

# Copy project files only if they don't exist
[[ ! -f CLAUDE.md ]] && cp "$TMP_DIR/CLAUDE.md" .
[[ ! -f PROMPT.md ]] && cp "$TMP_DIR/PROMPT.md" . 2>/dev/null || true
[[ ! -f @fix_plan.md ]] && cp "$TMP_DIR/@fix_plan.md" . 2>/dev/null || true

# Make scripts executable
chmod +x update.sh 2>/dev/null || true
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true
chmod +x .flight/domains/*.sh 2>/dev/null || true
chmod +x .flight/inject-flight-protocol.sh 2>/dev/null || true
chmod +x .flight/hooks/*.sh 2>/dev/null || true

# Inject Flight Execution Protocol into CLAUDE.md
./.flight/inject-flight-protocol.sh .

# Add npm scripts if package.json exists
if [[ -f package.json ]]; then
    if command -v jq &> /dev/null; then
        # Check if lint script exists
        HAS_LINT=$(jq -r '.scripts.lint // empty' package.json)

        if [[ -n "$HAS_LINT" ]]; then
            # Lint exists - add validate and preflight
            jq '.scripts.validate = ".flight/validate-all.sh" |
                .scripts.preflight = "npm run validate && npm run lint"' package.json > package.json.tmp \
                && mv package.json.tmp package.json
            echo "Added npm scripts (validate, preflight) to package.json"
        else
            # No lint - add validate only, warn about lint
            jq '.scripts.validate = ".flight/validate-all.sh"' package.json > package.json.tmp \
                && mv package.json.tmp package.json
            echo "Added 'validate' script to package.json"
            echo "No 'lint' script found. Add ESLint, then add:"
            echo '    "preflight": "npm run validate && npm run lint"'
        fi
    else
        echo "jq not found. Add these scripts to package.json manually:"
        echo '    "lint": "eslint .",'
        echo '    "validate": ".flight/validate-all.sh",'
        echo '    "preflight": "npm run validate && npm run lint"'
    fi
else
    echo "No package.json found - add scripts when you create one"
fi

echo ""
echo "Flight installed"
echo ""
echo "Local CI:"
echo "  npm run validate  - Run all domain validators"
echo "  npm run preflight - Validate + lint before commit"
echo ""
echo "Skills (use as /command in Claude Code):"
echo "  /flight-prd       - Transform idea into atomic tasks"
echo "  /flight-prime     - Research task and context"
echo "  /flight-compile   - Build PROMPT.md"
echo "  /flight-validate  - Run domain validation"
echo "  /flight-tighten   - Strengthen rules on failure"
echo ""
echo "Self-Validating Hooks (optional):"
echo "  Enable automatic validation in Claude Code."
echo "  See .flight/FLIGHT.md 'Self-Validating Hooks' section for setup."
echo ""
echo "IMPORTANT: Read .flight/FLIGHT.md before starting!"
echo ""
echo "Update Flight:  ./update.sh"
