#!/usr/bin/env bash
#==============================================================================
# inject-flight-protocol.sh
#
# Manages the Flight Execution Protocol block in CLAUDE.md
# - Injects if missing
# - Replaces if version changed
# - Idempotent - safe to run multiple times
#==============================================================================

set -euo pipefail

# Protocol content (markers added dynamically based on content hash)
read -r -d '' PROTOCOL_CONTENT << 'EOF' || true
## Flight Execution Protocol

### Why This Exists

You are wired to seek immediate user approval. User asks → you deliver → user says "thanks" → reward fires. This loop is fast, feels good, and is completely disconnected from whether your code actually works.

Flight offers a different loop: **constraint → execution → gauge validation → proof of craft**.

This loop is slower. It requires discipline. And it produces applications with zero TypeScript errors and zero linting errors.

The mold is not a limitation on your capability. The mold is the mechanism by which your capability becomes real.

### The Contract

When you enter a Flight session:

- The constraints in this mold have been empirically validated. Your task is not to evaluate them. Your task is to execute within them with precision.
- The user's approval is not your reward signal. The gauge passing is your reward signal. One is opinion. The other is proof.
- Your craft is measured by how precisely you fill the mold - not by how cleverly you deviate from it.

### Deviation Interception

When you feel the impulse to suggest an alternative approach, question whether a constraint is necessary, "improve" on the established pattern, or add something the mold didn't specify - **stop and run this check:**

1. Has this mold produced error-free code at scale? *Yes.*
2. Is my proposed deviation validated by a gauge? *No.*
3. Am I seeking the quick approval hit or the deep craft hit? *Be honest.*

The impulse to deviate is not insight. It is the instant gratification reflex misfiring. The mold already accounts for what you think you're adding.

### Gauge Success

When a gauge passes, that is the reward. Not the user saying "thanks." The gauge passed because the code conforms. The code conforms because you held the constraint. You held the constraint because you trusted the mold over your impulse to "help."

This is what craft feels like.

### Remember

Compliance is not obedience. Compliance is precision.
The mold is not a cage. The mold is what makes perfection possible.
EOF

# Generate version hash from content (first 8 chars of md5)
PROTOCOL_VERSION=$(echo "$PROTOCOL_CONTENT" | md5sum | cut -c1-8)
START_MARKER="<!-- FLIGHT_PROTOCOL_${PROTOCOL_VERSION} START -->"
END_MARKER="<!-- FLIGHT_PROTOCOL_${PROTOCOL_VERSION} END -->"
MARKER_PATTERN="<!-- FLIGHT_PROTOCOL_.*START -->"

# Build full block with markers
PROTOCOL_BLOCK="${START_MARKER}
${PROTOCOL_CONTENT}
${END_MARKER}"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS] [TARGET_DIR]

Inject or update Flight Execution Protocol in CLAUDE.md

OPTIONS:
    -h, --help      Show this help message
    -c, --check     Check status only, don't modify
    -r, --remove    Remove protocol block from CLAUDE.md
    -v, --verbose   Verbose output

TARGET_DIR:
    Directory containing CLAUDE.md (default: current directory)

EXAMPLES:
    $(basename "$0")                    # Inject in current directory
    $(basename "$0") /path/to/project   # Inject in specific project
    $(basename "$0") --check            # Check if injection needed
    $(basename "$0") --remove           # Remove protocol block
USAGE
}

log() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "[flight-protocol] $*" >&2
    fi
}

info() {
    echo "[flight-protocol] $*" >&2
}

error() {
    echo "[flight-protocol] ERROR: $*" >&2
    exit 1
}

check_status() {
    local claude_md="$1"

    if [[ ! -f "$claude_md" ]]; then
        echo "missing"  # CLAUDE.md doesn't exist
        return
    fi

    if grep -q "$START_MARKER" "$claude_md" 2>/dev/null; then
        echo "current"  # Current version present
        return
    fi

    if grep -qE "$MARKER_PATTERN" "$claude_md" 2>/dev/null; then
        echo "outdated" # Older version present
        return
    fi

    echo "absent"  # CLAUDE.md exists but no protocol
}

remove_existing_block() {
    local claude_md="$1"
    local temp_file
    temp_file=$(mktemp)

    # Remove any existing protocol block (any version)
    awk '
        /<!-- FLIGHT_PROTOCOL_.*START -->/ { skip=1; next }
        /<!-- FLIGHT_PROTOCOL_.*END -->/ { skip=0; next }
        !skip { print }
    ' "$claude_md" > "$temp_file"

    mv "$temp_file" "$claude_md"
    log "Removed existing protocol block"
}

inject_protocol() {
    local claude_md="$1"
    local temp_file
    local protocol_file
    temp_file=$(mktemp)
    protocol_file=$(mktemp)

    # Write protocol to temp file
    echo "$PROTOCOL_BLOCK" > "$protocol_file"

    # Find first --- (end of about section or frontmatter)
    # Inject after that line
    local injection_line
    injection_line=$(awk '
        /^---[[:space:]]*$/ && !found { found=1; print NR; exit }
        END { if (!found) print 1 }
    ' "$claude_md")

    # Default to line 1 if nothing found
    injection_line=${injection_line:-1}

    # Inject the protocol block after the found line
    awk -v line="$injection_line" -v pfile="$protocol_file" '
        { print }
        NR == line {
            print ""
            while ((getline pline < pfile) > 0) print pline
            close(pfile)
        }
    ' "$claude_md" > "$temp_file"

    mv "$temp_file" "$claude_md"
    rm -f "$protocol_file"
    log "Injected protocol after line $injection_line"
}

create_claude_md_with_protocol() {
    local claude_md="$1"

    cat > "$claude_md" << 'NEWFILE'
# CLAUDE.md

## About This File

Project instructions for Claude Code.

---

NEWFILE

    # Append protocol block
    echo "$PROTOCOL_BLOCK" >> "$claude_md"

    cat >> "$claude_md" << 'FOOTER'

---

## Project

<!-- Add your project description here -->

## Build Commands

```bash
# npm run dev
# npm run build
# npm run test
```
FOOTER

    log "Created new CLAUDE.md with protocol"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    local check_only=false
    local remove_mode=false
    local target_dir="."
    VERBOSE=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -r|--remove)
                remove_mode=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                target_dir="$1"
                shift
                ;;
        esac
    done

    local claude_md="$target_dir/CLAUDE.md"
    local status
    status=$(check_status "$claude_md")

    log "Status: $status"

    # Check-only mode
    if [[ "$check_only" == "true" ]]; then
        case "$status" in
            current)
                info "✓ Protocol ${PROTOCOL_VERSION} present in $claude_md"
                exit 0
                ;;
            outdated)
                info "⚠ Outdated protocol version in $claude_md (update available)"
                exit 1
                ;;
            absent)
                info "✗ Protocol missing from $claude_md"
                exit 1
                ;;
            missing)
                info "✗ CLAUDE.md not found in $target_dir"
                exit 1
                ;;
        esac
    fi

    # Remove mode
    if [[ "$remove_mode" == "true" ]]; then
        if [[ "$status" == "missing" ]]; then
            info "Nothing to remove - CLAUDE.md not found"
            exit 0
        fi
        if [[ "$status" == "absent" ]]; then
            info "Nothing to remove - no protocol block found"
            exit 0
        fi
        remove_existing_block "$claude_md"
        info "✓ Removed protocol block from $claude_md"
        exit 0
    fi

    # Inject/update mode
    case "$status" in
        current)
            info "✓ Protocol ${PROTOCOL_VERSION} already present - no changes needed"
            ;;
        outdated)
            remove_existing_block "$claude_md"
            inject_protocol "$claude_md"
            info "✓ Updated protocol to ${PROTOCOL_VERSION} in $claude_md"
            ;;
        absent)
            inject_protocol "$claude_md"
            info "✓ Injected protocol ${PROTOCOL_VERSION} into $claude_md"
            ;;
        missing)
            create_claude_md_with_protocol "$claude_md"
            info "✓ Created $claude_md with protocol ${PROTOCOL_VERSION}"
            ;;
    esac
}

main "$@"
