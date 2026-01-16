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

# Update examples, exercises, templates (learning resources)
[[ -d "$TMP_DIR/.flight/examples" ]] && cp -r "$TMP_DIR/.flight/examples" .flight/
[[ -d "$TMP_DIR/.flight/exercises" ]] && cp -r "$TMP_DIR/.flight/exercises" .flight/
[[ -d "$TMP_DIR/.flight/templates" ]] && cp -r "$TMP_DIR/.flight/templates" .flight/

# Make scripts executable
chmod +x .flight/validate-all.sh 2>/dev/null || true
chmod +x .flight/exclusions.sh 2>/dev/null || true
chmod +x .flight/domains/*.validate.sh 2>/dev/null || true
chmod +x .flight/domains/*.sh 2>/dev/null || true
chmod +x .flight/bin/* 2>/dev/null || true

echo "Flight updated"
echo ""
echo "Updated:"
echo "  - .claude/skills/* (all Flight skills)"
echo "  - .flight/FLIGHT.md (core methodology)"
echo "  - .flight/validate-all.sh, exclusions.sh"
echo "  - .flight/domains/* (all stock domains)"
echo "  - .flight/bin/* (tooling scripts)"
echo "  - .flight/examples/, exercises/, templates/"
echo ""
echo "Preserved:"
echo "  - CLAUDE.md (your project description)"
echo "  - PROMPT.md, PRIME.md (your working files)"
echo "  - Custom domains (any .md/.sh not in Flight repo)"
