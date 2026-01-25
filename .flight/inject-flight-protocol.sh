#!/usr/bin/env bash
#==============================================================================
# inject-flight-protocol.sh
#
# Injects Flight Execution Protocol into CLAUDE.md
# - Removes existing block (if any)
# - Injects protocol from protocol-block.md
# - Idempotent - safe to run multiple times
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_FILE="$SCRIPT_DIR/protocol-block.md"

info() {
    echo "[flight-protocol] $*" >&2
}

error() {
    echo "[flight-protocol] ERROR: $*" >&2
    exit 1
}

usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS] [TARGET_DIR]

Inject Flight Execution Protocol into CLAUDE.md

OPTIONS:
    -h, --help      Show this help message
    -r, --remove    Remove protocol block from CLAUDE.md

TARGET_DIR:
    Directory containing CLAUDE.md (default: current directory)
USAGE
}

remove_protocol_block() {
    local file="$1"
    local temp_file
    temp_file=$(mktemp)

    # Remove lines between START and END markers (inclusive)
    sed '/<!-- FLIGHT_PROTOCOL START -->/,/<!-- FLIGHT_PROTOCOL END -->/d' "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

inject_protocol_block() {
    local file="$1"
    local temp_file
    temp_file=$(mktemp)

    # Find first --- line number
    local inject_line
    inject_line=$(grep -n '^---[[:space:]]*$' "$file" | head -1 | cut -d: -f1)
    inject_line=${inject_line:-1}

    # Build new file: head + blank + protocol + tail
    head -n "$inject_line" "$file" > "$temp_file"
    echo "" >> "$temp_file"
    cat "$PROTOCOL_FILE" >> "$temp_file"
    tail -n +"$((inject_line + 1))" "$file" >> "$temp_file"

    mv "$temp_file" "$file"
}

create_claude_md() {
    local file="$1"
    cat > "$file" << 'HEADER'
# CLAUDE.md

## About This File

Project instructions for Claude Code.

---

HEADER
    cat "$PROTOCOL_FILE" >> "$file"
    cat >> "$file" << 'FOOTER'

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

main() {
    local remove_mode=false
    local target_dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -r|--remove) remove_mode=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *) target_dir="$1"; shift ;;
        esac
    done

    local claude_md="$target_dir/CLAUDE.md"

    # Check protocol file exists
    [[ -f "$PROTOCOL_FILE" ]] || error "Protocol file not found: $PROTOCOL_FILE"

    if [[ "$remove_mode" == "true" ]]; then
        [[ -f "$claude_md" ]] || { info "Nothing to remove - CLAUDE.md not found"; exit 0; }
        remove_protocol_block "$claude_md"
        info "OK - Removed protocol block from $claude_md"
        exit 0
    fi

    if [[ ! -f "$claude_md" ]]; then
        create_claude_md "$claude_md"
        info "OK - Created $claude_md with protocol"
    else
        remove_protocol_block "$claude_md"
        inject_protocol_block "$claude_md"
        info "OK - Updated protocol in $claude_md"
    fi
}

main "$@"
