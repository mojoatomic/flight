#!/bin/bash
set -euo pipefail

# =============================================================================
# Flight-Lint Setup Script
# Quick setup for integrating flight-lint into a project
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() { printf '%s\n' "$*"; }
success() { printf '%b✓ %s%b\n' "$GREEN" "$*" "$NC"; }
fail() { printf '%b✗ %s%b\n' "$RED" "$*" "$NC"; }
warn() { printf '%b⚠ %s%b\n' "$YELLOW" "$*" "$NC"; }
info() { printf '%b→ %s%b\n' "$BLUE" "$*" "$NC"; }

# -----------------------------------------------------------------------------
# show_usage - Display usage information
# -----------------------------------------------------------------------------
show_usage() {
    log "Usage: setup-flight-lint.sh [options]"
    log ""
    log "Options:"
    log "  --help       Show this help message"
    log "  --check      Check if flight-lint is properly set up"
    log ""
    log "This script sets up flight-lint in your project by:"
    log "  1. Creating .flight/domains/ directory structure"
    log "  2. Adding npm scripts for linting"
    log "  3. Creating a sample rules file"
    log ""
}

# -----------------------------------------------------------------------------
# check_prerequisites - Verify required tools
# -----------------------------------------------------------------------------
check_prerequisites() {
    if ! command -v node &>/dev/null; then
        fail "Node.js is required but not installed"
        exit 1
    fi

    if ! command -v npm &>/dev/null; then
        fail "npm is required but not installed"
        exit 1
    fi

    if [[ ! -f "package.json" ]]; then
        fail "No package.json found. Run this from your project root."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# create_directories - Create .flight directory structure
# -----------------------------------------------------------------------------
create_directories() {
    info "Creating .flight directory structure..."

    mkdir -p .flight/domains

    if [[ -d ".flight/domains" ]]; then
        success "Created .flight/domains/"
    else
        fail "Failed to create .flight/domains/"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# add_npm_scripts - Add flight-lint scripts to package.json
# -----------------------------------------------------------------------------
add_npm_scripts() {
    info "Checking npm scripts..."

    # Check if jq is available for JSON manipulation
    if ! command -v jq &>/dev/null; then
        warn "jq not installed. Add these scripts manually to package.json:"
        log ""
        log '  "scripts": {'
        log '    "lint:flight": "flight-lint --auto",'
        log '    "preflight": "npm run lint:flight"'
        log '  }'
        log ""
        return
    fi

    # Check if lint:flight script already exists
    if jq -e '.scripts["lint:flight"]' package.json &>/dev/null; then
        success "lint:flight script already exists"
        return
    fi

    # Add the scripts
    local temp_file
    temp_file=$(mktemp)

    jq '.scripts["lint:flight"] = "flight-lint --auto" | .scripts["preflight"] = "npm run lint:flight"' package.json > "$temp_file"
    mv "$temp_file" package.json

    success "Added lint:flight and preflight scripts to package.json"
}

# -----------------------------------------------------------------------------
# create_sample_rules - Create a sample rules file
# -----------------------------------------------------------------------------
create_sample_rules() {
    local sample_file=".flight/domains/sample.rules.json"

    if [[ -f "$sample_file" ]]; then
        info "Sample rules file already exists: $sample_file"
        return
    fi

    info "Creating sample rules file..."

    cat > "$sample_file" << 'EOF'
{
  "domain": "sample",
  "version": "1.0.0",
  "language": "javascript",
  "file_patterns": [
    "src/**/*.js",
    "src/**/*.mjs"
  ],
  "exclude_patterns": [
    "**/node_modules/**",
    "**/dist/**"
  ],
  "rules": [
    {
      "id": "S1",
      "title": "Console Log Detection",
      "severity": "SHOULD",
      "type": "ast",
      "query": "(call_expression\n  function: (member_expression\n    object: (identifier) @obj\n    property: (property_identifier) @prop)\n  (#eq? @obj \"console\")\n  (#eq? @prop \"log\")) @violation",
      "message": "Consider removing console.log statements from production code."
    }
  ]
}
EOF

    success "Created sample rules file: $sample_file"
    log ""
    log "Edit this file to add your own rules, or replace it with domain-specific rules."
}

# -----------------------------------------------------------------------------
# check_setup - Verify flight-lint setup
# -----------------------------------------------------------------------------
check_setup() {
    log "Checking flight-lint setup..."
    log ""

    local has_errors=false

    # Check .flight/domains directory
    if [[ -d ".flight/domains" ]]; then
        success ".flight/domains/ directory exists"
    else
        fail ".flight/domains/ directory not found"
        has_errors=true
    fi

    # Check for rules files
    local rules_count
    rules_count=$(find .flight/domains -name "*.rules.json" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$rules_count" -gt 0 ]]; then
        success "Found $rules_count rules file(s)"
    else
        warn "No .rules.json files found in .flight/domains/"
    fi

    # Check package.json scripts
    if [[ -f "package.json" ]]; then
        if command -v jq &>/dev/null; then
            if jq -e '.scripts["lint:flight"]' package.json &>/dev/null; then
                success "lint:flight script configured"
            else
                warn "lint:flight script not found in package.json"
            fi
        fi
    fi

    log ""

    if [[ "$has_errors" == "true" ]]; then
        fail "Setup incomplete. Run setup-flight-lint.sh to fix."
        exit 1
    else
        success "Flight-lint setup looks good!"
    fi
}

# -----------------------------------------------------------------------------
# main - Main entry point
# -----------------------------------------------------------------------------
main() {
    log ""
    log "Flight-Lint Setup"
    log "================="
    log ""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --check)
                check_setup
                exit 0
                ;;
            *)
                fail "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done

    # Run setup
    check_prerequisites
    create_directories
    add_npm_scripts
    create_sample_rules

    log ""
    success "Setup complete!"
    log ""
    log "Next steps:"
    log "  1. Edit .flight/domains/*.rules.json to define your rules"
    log "  2. Run 'npm run lint:flight' to lint your code"
    log "  3. Add 'npm run preflight' to your CI pipeline"
    log ""
}

main "$@"
