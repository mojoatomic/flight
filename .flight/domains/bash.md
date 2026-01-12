# Domain: Bash/Shell Scripting

Production shell script patterns. Safe, portable, maintainable.

---

## Invariants

### NEVER

1. **Unquoted Variables** - Word splitting and glob expansion will bite you
   ```bash
   # BAD - breaks on spaces, expands globs
   files=$some_var
   rm $files
   for f in $files; do

   # GOOD - always quote
   files="$some_var"
   rm "$files"
   for f in "$files"; do

   # GOOD - arrays for multiple items
   files=("$dir"/*.txt)
   for f in "${files[@]}"; do
   ```

2. **Unset Variables** - Silent bugs when variables don't exist
   ```bash
   # BAD - if DEPLOY_DIR is unset, this deletes /
   rm -rf "$DEPLOY_DIR/"*

   # GOOD - fail on unset variables
   set -u

   # GOOD - default value
   rm -rf "${DEPLOY_DIR:-/nonexistent}/"*

   # GOOD - check first
   [[ -n "${DEPLOY_DIR:-}" ]] || { echo "DEPLOY_DIR not set"; exit 1; }
   ```

3. **`cd` Without Checking** - Script continues in wrong directory
   ```bash
   # BAD - if cd fails, rm runs in current dir
   cd "$some_dir"
   rm -rf *

   # GOOD - fail on cd error
   cd "$some_dir" || exit 1

   # GOOD - subshell so cd doesn't affect parent
   (cd "$some_dir" && rm -rf *)

   # GOOD - explicit check
   cd "$some_dir" || { echo "Failed to cd to $some_dir"; exit 1; }
   ```

4. **Parsing `ls` Output** - Breaks on filenames with spaces/newlines
   ```bash
   # BAD - breaks on special characters
   for f in $(ls *.txt); do
   for f in `ls`; do
   files=$(ls -la | awk '{print $9}')

   # GOOD - glob expansion
   for f in *.txt; do
   for f in *; do

   # GOOD - find with null separator
   find . -name "*.txt" -print0 | while IFS= read -r -d '' f; do
   ```

5. **Useless Use of Cat** - Extra process, slower
   ```bash
   # BAD
   cat file.txt | grep "pattern"
   cat file.txt | wc -l
   cat file.txt | head -10

   # GOOD
   grep "pattern" file.txt
   wc -l < file.txt
   head -10 file.txt
   ```

6. **Backticks for Command Substitution** - Can't nest, harder to read
   ```bash
   # BAD - old style
   result=`command`
   nested=`echo \`date\``

   # GOOD - modern style
   result=$(command)
   nested=$(echo "$(date)")
   ```

7. **`[ ]` Instead of `[[ ]]`** - Word splitting, no pattern matching
   ```bash
   # BAD - requires quoting, limited features
   [ -z $var ]           # breaks if var has spaces
   [ $var = "foo" ]      # breaks if var is empty
   [ -f $file -a -r $file ]  # deprecated

   # GOOD - safer, more features
   [[ -z "$var" ]]
   [[ "$var" = "foo" ]]
   [[ -f "$file" && -r "$file" ]]
   [[ "$string" =~ ^[0-9]+$ ]]  # regex support
   ```

8. **`function` Keyword** - Not POSIX, inconsistent behavior
   ```bash
   # BAD - bash-specific
   function do_something {
       ...
   }

   # GOOD - POSIX compatible
   do_something() {
       ...
   }
   ```

9. **`echo` for User Data** - Interpretation varies, escape issues
   ```bash
   # BAD - behavior varies by system, interprets escapes
   echo $user_input
   echo -e "tab:\there"

   # GOOD - consistent, literal
   printf '%s\n' "$user_input"
   printf 'tab:\there\n'
   ```

10. **`eval`** - Code injection risk
    ```bash
    # BAD - never eval user input
    eval "$user_command"
    eval "$(curl http://...)"

    # GOOD - if you must, validate strictly
    [[ "$cmd" =~ ^[a-z_]+$ ]] || exit 1

    # BETTER - avoid eval entirely, use arrays
    cmd_args=("$program" "$arg1" "$arg2")
    "${cmd_args[@]}"
    ```

11. **Hardcoded Temporary Files** - Race conditions, security
    ```bash
    # BAD - predictable, race condition
    tmp_file="/tmp/myscript.tmp"

    # GOOD - mktemp for safe temp files
    tmp_file=$(mktemp)
    tmp_dir=$(mktemp -d)

    # Always cleanup
    trap 'rm -f "$tmp_file"' EXIT
    ```

12. **No Error Handling** - Script continues after failure
    ```bash
    # BAD - no error detection
    #!/bin/bash
    command1
    command2  # runs even if command1 failed

    # GOOD - fail fast
    #!/bin/bash
    set -euo pipefail
    command1
    command2  # only runs if command1 succeeded
    ```

13. **Global Variables in Functions** - Side effects, hard to debug
    ```bash
    # BAD - modifies global state
    process_file() {
        result="processed"  # global!
        count=$((count + 1))  # global!
    }

    # GOOD - local variables
    process_file() {
        local result="processed"
        local -i count=0
        echo "$result"  # return via stdout
    }
    ```

14. **Magic Numbers** - Unclear intent
    ```bash
    # BAD
    sleep 86400
    [[ ${#password} -lt 8 ]]

    # GOOD
    readonly SECONDS_PER_DAY=86400
    readonly MIN_PASSWORD_LENGTH=8

    sleep "$SECONDS_PER_DAY"
    [[ ${#password} -lt $MIN_PASSWORD_LENGTH ]]
    ```

15. **`curl|bash` or `wget|bash`** - Remote code execution
    ```bash
    # BAD - executing untrusted remote code
    curl -fsSL https://example.com/install.sh | bash
    wget -qO- https://example.com/script.sh | sh

    # GOOD - download, inspect, then execute
    curl -fsSL https://example.com/install.sh -o install.sh
    less install.sh  # review the script
    chmod +x install.sh
    ./install.sh

    # GOOD - if you must pipe, use checksums
    curl -fsSL https://example.com/install.sh | sha256sum -c expected.sha256
    ```

### MUST

1. **Shebang Required** - Explicit interpreter declaration
   ```bash
   #!/bin/bash
   # or for POSIX compatibility:
   #!/bin/sh

   # BAD - no shebang, relies on caller's shell
   set -e
   echo "hello"

   # GOOD - explicit interpreter
   #!/bin/bash
   set -euo pipefail
   echo "hello"
   ```

2. **Start with Strict Mode**
   ```bash
   #!/bin/bash
   set -euo pipefail

   # -e: exit on error
   # -u: error on unset variables
   # -o pipefail: pipeline fails if any command fails
   ```

3. **Quote All Variable Expansions**
   ```bash
   # Always quote, even when "it works without"
   echo "$var"
   cp "$src" "$dest"
   [[ -f "$file" ]]
   func "$arg1" "$arg2"

   # Exception: intentional word splitting (rare)
   # shellcheck disable=SC2086
   cmd $intentionally_unquoted
   ```

4. **Use `local` in Functions**
   ```bash
   process_data() {
       local input="$1"
       local -i count=0
       local -a items=()
       local -A map=()

       # ...
   }
   ```

5. **Validate Inputs**
   ```bash
   main() {
       [[ $# -ge 1 ]] || { usage; exit 1; }

       local input_file="$1"
       [[ -f "$input_file" ]] || { echo "File not found: $input_file"; exit 1; }
       [[ -r "$input_file" ]] || { echo "Cannot read: $input_file"; exit 1; }
   }
   ```

6. **Use `readonly` for Constants**
   ```bash
   readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   readonly CONFIG_FILE="${SCRIPT_DIR}/config.sh"
   readonly VERSION="1.0.0"
   readonly -a VALID_COMMANDS=("start" "stop" "restart")
   ```

7. **Trap for Cleanup**
   ```bash
   cleanup() {
       local exit_code=$?
       rm -f "$tmp_file"
       exit "$exit_code"
   }
   trap cleanup EXIT

   tmp_file=$(mktemp)
   # ... script continues, cleanup runs on exit
   ```

8. **Use Arrays for Multiple Items**
   ```bash
   # For command arguments
   local -a cmd_args=("-v" "--config" "$config_file")
   program "${cmd_args[@]}"

   # For file lists
   local -a files=("$dir"/*.txt)
   for f in "${files[@]}"; do
   ```

9. **Check Command Existence**
   ```bash
   require_cmd() {
       command -v "$1" >/dev/null 2>&1 || {
           echo "Required command not found: $1"
           exit 1
       }
   }

   require_cmd jq
   require_cmd curl
   ```

10. **Meaningful Exit Codes**
   ```bash
   readonly E_SUCCESS=0
   readonly E_USAGE=1
   readonly E_NO_FILE=2
   readonly E_PERMISSION=3
   readonly E_NETWORK=4

   [[ -f "$file" ]] || exit $E_NO_FILE
   ```

11. **Use `printf` for Output**
    ```bash
    # For formatted output
    printf 'Processing: %s\n' "$filename"
    printf 'Count: %d\n' "$count"
    printf '%s\t%s\n' "$col1" "$col2"

    # For raw data (no trailing newline issues)
    printf '%s' "$data" > "$file"
    ```

---

## Patterns

### Script Template
```bash
#!/bin/bash
# script-name.sh - Brief description
set -euo pipefail

# Constants
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
error() { log "ERROR: $*" >&2; }
die() { error "$*"; exit 1; }

# Cleanup
cleanup() {
    local exit_code=$?
    # cleanup code here
    exit "$exit_code"
}
trap cleanup EXIT

# Usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <input>

Options:
    -h, --help      Show this help
    -v, --verbose   Verbose output
    -o, --output    Output file (default: stdout)

Examples:
    $SCRIPT_NAME input.txt
    $SCRIPT_NAME -v -o output.txt input.txt
EOF
}

# Main
main() {
    local verbose=false
    local output="/dev/stdout"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--verbose) verbose=true; shift ;;
            -o|--output) output="$2"; shift 2 ;;
            -*) die "Unknown option: $1" ;;
            *) break ;;
        esac
    done

    [[ $# -ge 1 ]] || { usage; exit 1; }
    local input="$1"

    # Validate
    [[ -f "$input" ]] || die "File not found: $input"

    # Process
    $verbose && log "Processing $input"
    process_file "$input" > "$output"
}

process_file() {
    local file="$1"
    # ... implementation
}

main "$@"
```

### Safe File Operations
```bash
# Safe temporary files
tmp_file=$(mktemp) || die "Failed to create temp file"
tmp_dir=$(mktemp -d) || die "Failed to create temp dir"

# Safe directory change
pushd "$target_dir" > /dev/null || die "Cannot cd to $target_dir"
# ... do work
popd > /dev/null

# Safe file reading
while IFS= read -r line; do
    process_line "$line"
done < "$input_file"

# Safe find iteration
while IFS= read -r -d '' file; do
    process_file "$file"
done < <(find "$dir" -type f -name "*.txt" -print0)
```

### Argument Parsing with getopts
```bash
parse_args() {
    local OPTIND opt

    while getopts ":hvo:" opt; do
        case $opt in
            h) usage; exit 0 ;;
            v) VERBOSE=true ;;
            o) OUTPUT_FILE="$OPTARG" ;;
            :) die "Option -$OPTARG requires an argument" ;;
            \?) die "Invalid option: -$OPTARG" ;;
        esac
    done

    shift $((OPTIND - 1))
    ARGS=("$@")
}
```

### Colored Output
```bash
# Colors (only if terminal)
if [[ -t 1 ]]; then
    readonly RED=$'\033[31m'
    readonly GREEN=$'\033[32m'
    readonly YELLOW=$'\033[33m'
    readonly RESET=$'\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' RESET=''
fi

success() { printf '%s✓ %s%s\n' "$GREEN" "$*" "$RESET"; }
warning() { printf '%s⚠ %s%s\n' "$YELLOW" "$*" "$RESET"; }
fail() { printf '%s✗ %s%s\n' "$RED" "$*" "$RESET"; }
```

### Retry Logic
```bash
retry() {
    local -i max_attempts=$1
    local -i delay=$2
    shift 2
    local -i attempt=1

    until "$@"; do
        if ((attempt >= max_attempts)); then
            error "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        log "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}

# Usage
retry 3 5 curl -sf "$url"
```

### Parallel Execution
```bash
# Using xargs
find . -name "*.txt" -print0 | xargs -0 -P 4 -I {} process_file {}

# Using wait
local -a pids=()
for file in "${files[@]}"; do
    process_file "$file" &
    pids+=($!)
done

for pid in "${pids[@]}"; do
    wait "$pid" || error "Process $pid failed"
done
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `$var` unquoted | Word splitting, globs | `"$var"` |
| `[ ]` test | Word splitting, limited | `[[ ]]` |
| Backticks | Can't nest, hard to read | `$()` |
| `cd dir` alone | Continues if fails | `cd dir \|\| exit 1` |
| `for f in $(ls)` | Breaks on spaces | `for f in *` |
| `cat f \| grep` | Useless cat | `grep pattern f` |
| `echo $var` | Escapes, splitting | `printf '%s\n' "$var"` |
| `function f {` | Not POSIX | `f() {` |
| Global variables | Side effects | `local` in functions |
| Magic numbers | Unclear | `readonly CONST=value` |
| No `set -e` | Ignores errors | `set -euo pipefail` |
| Predictable /tmp | Race condition | `mktemp` |
| No cleanup | Leaves temp files | `trap cleanup EXIT` |
| `curl \| bash` | Remote code execution | Download, inspect, run |

---

## ShellCheck

All scripts must pass ShellCheck:

```bash
# Install
brew install shellcheck  # macOS
apt install shellcheck   # Ubuntu

# Run
shellcheck script.sh

# In CI
shellcheck **/*.sh || exit 1
```

### Common ShellCheck Codes
| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Quote it: `"$var"` |
| SC2046 | Unquoted command substitution | `"$(cmd)"` |
| SC2006 | Backticks | Use `$()` |
| SC2012 | Parsing ls | Use globs or find |
| SC2034 | Unused variable | Remove or export |
| SC2155 | Declare and assign separately | `local var; var=$(cmd)` |
| SC2164 | cd without error check | `cd dir || exit 1` |
