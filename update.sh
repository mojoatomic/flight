#!/bin/bash
# update.sh - Update Flight to latest version
set -euo pipefail

readonly REPO="https://github.com/mojoatomic/flight.git"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
    local exit_code=$?
    rm -rf "$TMP_DIR"
    exit "$exit_code"
}
trap cleanup EXIT

echo "Updating Flight..."

git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null

# Ensure target directories exist
mkdir -p .claude/skills .flight/domains

# Update skills (always safe to overwrite)
if [[ -d "$TMP_DIR/.claude/skills" ]]; then
    cp -r "$TMP_DIR/.claude/skills/"* .claude/skills/ 2>/dev/null || true
fi

# Update settings.json (hooks configuration) from template
[[ -f "$TMP_DIR/.flight/templates/claude-settings.json" ]] && cp "$TMP_DIR/.flight/templates/claude-settings.json" .claude/settings.json

# Update FLIGHT.md (core methodology)
[[ -f "$TMP_DIR/.flight/FLIGHT.md" ]] && cp "$TMP_DIR/.flight/FLIGHT.md" .flight/FLIGHT.md

# Update validate-all.sh and exclusions.sh
[[ -f "$TMP_DIR/.flight/validate-all.sh" ]] && cp "$TMP_DIR/.flight/validate-all.sh" .flight/validate-all.sh
[[ -f "$TMP_DIR/.flight/exclusions.sh" ]] && cp "$TMP_DIR/.flight/exclusions.sh" .flight/exclusions.sh

# Update all domain files from source (preserves custom domains not in source)
for file in "$TMP_DIR/.flight/domains/"*.md "$TMP_DIR/.flight/domains/"*.sh "$TMP_DIR/.flight/domains/"*.flight; do
    [[ -f "$file" ]] && cp "$file" .flight/domains/
done

# Update bin scripts
if [[ -d "$TMP_DIR/.flight/bin" ]]; then
    mkdir -p .flight/bin
    cp -r "$TMP_DIR/.flight/bin/"* .flight/bin/ 2>/dev/null || true
fi

# Update flight-lint (AST validation tool)
if [[ -d "$TMP_DIR/flight-lint" ]]; then
    if [[ -d "flight-lint/node_modules" ]]; then
        # Preserve existing node_modules and dist
        mv flight-lint/node_modules /tmp/flight-lint-node_modules-$$ 2>/dev/null || true
        mv flight-lint/dist /tmp/flight-lint-dist-$$ 2>/dev/null || true
        rm -rf flight-lint
        cp -r "$TMP_DIR/flight-lint" .
        mv /tmp/flight-lint-node_modules-$$ flight-lint/node_modules 2>/dev/null || true
        mv /tmp/flight-lint-dist-$$ flight-lint/dist 2>/dev/null || true
    else
        rm -rf flight-lint
        cp -r "$TMP_DIR/flight-lint" .
    fi
    # Build if not already built or if source is newer
    if [[ ! -d "flight-lint/dist" ]] || [[ ! -d "flight-lint/node_modules" ]]; then
        echo "Building flight-lint..."
        echo "  Installing dependencies (including tree-sitter native modules)..."
        (cd flight-lint && CI=true npm install --include=optional) || {
            echo "Warning: npm install had issues. tree-sitter requires build tools."
            echo "  On macOS: xcode-select --install"
            echo "  On Ubuntu: apt-get install build-essential"
        }
        echo "  Compiling TypeScript..."
        (cd flight-lint && CI=true npm run build) || {
            echo "Warning: flight-lint build failed. AST rules will be skipped."
        }
    fi
fi

# Update examples, exercises, templates (learning resources)
[[ -d "$TMP_DIR/.flight/examples" ]] && cp -r "$TMP_DIR/.flight/examples" .flight/
[[ -d "$TMP_DIR/.flight/exercises" ]] && cp -r "$TMP_DIR/.flight/exercises" .flight/
[[ -d "$TMP_DIR/.flight/templates" ]] && cp -r "$TMP_DIR/.flight/templates" .flight/

# Update inject-flight-protocol.sh
[[ -f "$TMP_DIR/.flight/inject-flight-protocol.sh" ]] && cp "$TMP_DIR/.flight/inject-flight-protocol.sh" .flight/

# Update update.sh itself (so consumers always get latest version)
[[ -f "$TMP_DIR/update.sh" ]] && cp "$TMP_DIR/update.sh" ./update.sh && chmod +x ./update.sh

# Update hooks (self-validation hooks for Claude Code)
if [[ -d "$TMP_DIR/.flight/hooks" ]]; then
    mkdir -p .flight/hooks
    cp -r "$TMP_DIR/.flight/hooks/"* .flight/hooks/ 2>/dev/null || true
fi

# Make scripts executable
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/exclusions.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true
chmod +x .flight/domains/*.sh 2>/dev/null || true
chmod +x .flight/bin/* 2>/dev/null || true
chmod +x .flight/inject-flight-protocol.sh 2>/dev/null || true
chmod +x .flight/hooks/*.sh 2>/dev/null || true

# Inject/update Flight Execution Protocol in CLAUDE.md
./.flight/inject-flight-protocol.sh .

echo "Flight updated"
echo ""
echo "Updated:"
echo "  - update.sh (this script)"
echo "  - .claude/settings.json (hooks configuration)"
echo "  - .claude/skills/* (all Flight skills)"
echo "  - .flight/FLIGHT.md (core methodology)"
echo "  - .flight/validate-all.sh, exclusions.sh"
echo "  - .flight/domains/* (all stock domains)"
echo "  - .flight/hooks/* (self-validation hooks)"
echo "  - .flight/bin/* (tooling scripts)"
echo "  - .flight/examples/, exercises/, templates/"
echo "  - flight-lint/* (AST validation tool)"
echo "  - CLAUDE.md (Flight Execution Protocol injected/updated)"
echo ""
echo "Preserved:"
echo "  - CLAUDE.md (your project description - protocol section updated only)"
echo "  - PROMPT.md, PRIME.md (your working files)"
echo "  - .flight/known-landmines.md (your project's temporal data)"
echo "  - Custom domains (any .md/.sh not in Flight repo)"
echo ""
echo "If AST validation fails (missing tree-sitter packages), rebuild flight-lint:"
echo "  cd flight-lint && npm install && npm run build"
