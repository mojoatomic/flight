#!/usr/bin/env bash
#==============================================================================
# inject-flight-protocol.sh
#
# Injects Flight Execution Protocol into CLAUDE.md
# - Removes existing block (if any)
# - Injects current block
# - Idempotent - safe to run multiple times
#
# Versioning: update.sh is the versioning mechanism. Run update, get current.
#==============================================================================

set -euo pipefail

START_MARKER="<!-- FLIGHT_PROTOCOL START -->"
END_MARKER="<!-- FLIGHT_PROTOCOL END -->"

# Protocol content
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

PROTOCOL_BLOCK="${START_MARKER}
${PROTOCOL_CONTENT}
${END_MARKER}"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS] [TARGET_DIR]

Inject Flight Execution Protocol into CLAUDE.md

OPTIONS:
    -h, --help      Show this help message
    -r, --remove    Remove protocol block from CLAUDE.md

TARGET_DIR:
    Directory containing CLAUDE.md (default: current directory)

EXAMPLES:
    $(basename "$0")                    # Inject in current directory
    $(basename "$0") /path/to/project   # Inject in specific project
    $(basename "$0") --remove           # Remove protocol block
USAGE
}

info() {
    echo "[flight-protocol] $*" >&2
}

error() {
    echo "[flight-protocol] ERROR: $*" >&2
    exit 1
}

remove_existing_block() {
    local claude_md="$1"
    local temp_file
    temp_file=$(mktemp)

    # Remove any existing protocol block
    awk '
        /<!-- FLIGHT_PROTOCOL.*START -->/ { skip=1; next }
        /<!-- FLIGHT_PROTOCOL.*END -->/ { skip=0; next }
        !skip { print }
    ' "$claude_md" > "$temp_file"

    mv "$temp_file" "$claude_md"
}

inject_protocol() {
    local claude_md="$1"
    local temp_file
    temp_file=$(mktemp)

    # Find first --- (end of about section or frontmatter)
    local injection_line
    injection_line=$(awk '
        /^---[[:space:]]*$/ && !found { found=1; print NR; exit }
        END { if (!found) print 1 }
    ' "$claude_md")

    injection_line=${injection_line:-1}

    # Inject protocol block using head/tail (portable, avoids awk getline issues on macOS)
    {
        head -n "$injection_line" "$claude_md"
        echo ""
        echo "$PROTOCOL_BLOCK"
        tail -n +"$((injection_line + 1))" "$claude_md"
    } > "$temp_file"

    mv "$temp_file" "$claude_md"
}

create_claude_md_with_protocol() {
    local claude_md="$1"

    cat > "$claude_md" << 'NEWFILE'
# CLAUDE.md

## About This File

Project instructions for Claude Code.

---

NEWFILE

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
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    local remove_mode=false
    local target_dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--remove)
                remove_mode=true
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

    # Remove mode
    if [[ "$remove_mode" == "true" ]]; then
        if [[ ! -f "$claude_md" ]]; then
            info "Nothing to remove - CLAUDE.md not found"
            exit 0
        fi
        remove_existing_block "$claude_md"
        info "OK - Removed protocol block from $claude_md"
        exit 0
    fi

    # Inject mode: remove existing, inject current
    if [[ ! -f "$claude_md" ]]; then
        create_claude_md_with_protocol "$claude_md"
        info "OK - Created $claude_md with protocol"
    else
        remove_existing_block "$claude_md"
        inject_protocol "$claude_md"
        info "OK - Updated protocol in $claude_md"
    fi
}

main "$@"
