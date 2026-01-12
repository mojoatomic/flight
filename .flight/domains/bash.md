# Domain: Bash/Shell Scripting

Production shell script patterns. Safe, portable, maintainable.

**Validation:** `bash.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Unquoted Variables in Commands** - Word splitting and glob expansion
   ```bash
   # BAD - breaks on spaces, expands globs
   rm $files
   cp $src $dest

   # GOOD - always quote
   rm "$files"
   cp "$src" "$dest"
   ```

2. **Unquoted `$(cmd)` Substitution** - Same word splitting issues
   ```bash
   # BAD
   result=$(get_path)
   cd $result

   # GOOD
   result="$(get_path)"
   cd "$result"
   ```

3. **Parsing `ls` Output** - Breaks on filenames with spaces/newlines
   ```bash
   # BAD - breaks on special characters
   for f in $(ls *.txt); do
   for f in `ls`; do

   # GOOD - glob expansion
   for f in *.txt; do
   for f in *; do

   # GOOD - find with null separator
   find . -name "*.txt" -print0 | while IFS= read -r -d '' f; do
   ```

4. **Backticks for Command Substitution** - Can't nest, harder to read
   ```bash
   # BAD - old style
   result=`command`

   # GOOD - modern style
   result=$(command)
   ```

5. **`[ ]` Instead of `[[ ]]` in Bash** - Word splitting, no pattern matching
   ```bash
   # BAD - requires quoting, limited features
   [ -z $var ]
   [ $var = "foo" ]

   # GOOD - safer, more features
   [[ -z "$var" ]]
   [[ "$var" = "foo" ]]
   [[ "$string" =~ ^[0-9]+$ ]]  # regex support
   ```

6. **`function` Keyword** - Not POSIX, inconsistent behavior
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

7. **`cd` Without Error Handling** - Script continues in wrong directory
   ```bash
   # BAD - if cd fails, rm runs in current dir
   cd "$some_dir"
   rm -rf *

   # GOOD - fail on cd error
   cd "$some_dir" || exit 1

   # GOOD - explicit check
   cd "$some_dir" || { echo "Failed to cd to $some_dir"; exit 1; }
   ```

8. **Useless Use of Cat** - Extra process, slower
   ```bash
   # BAD
   cat file.txt | grep "pattern"
   cat file.txt | wc -l

   # GOOD
   grep "pattern" file.txt
   wc -l < file.txt
   ```

9. **`eval`** - Code injection risk
   ```bash
   # BAD - never eval user input
   eval "$user_command"

   # GOOD - use arrays instead
   cmd_args=("$program" "$arg1" "$arg2")
   "${cmd_args[@]}"
   ```

10. **Hardcoded `/tmp` Files** - Race conditions, security
    ```bash
    # BAD - predictable, race condition
    tmp_file="/tmp/myscript.tmp"

    # GOOD - mktemp for safe temp files
    tmp_file=$(mktemp)
    ```

11. **`curl|bash` or `wget|bash`** - Remote code execution
    ```bash
    # BAD - executing untrusted remote code
    curl -fsSL https://example.com/install.sh | bash

    # GOOD - download, inspect, then execute
    curl -fsSL https://example.com/install.sh -o install.sh
    less install.sh  # review the script
    ./install.sh
    ```

12. **Unquoted Array Expansion** - Use `[@]` not `[*]`
    ```bash
    # BAD - joins into single string
    echo ${arr[*]}

    # GOOD - preserves elements
    echo "${arr[@]}"
    ```

### MUST (validator will reject)

1. **Shebang Required** - Explicit interpreter declaration
   ```bash
   #!/bin/bash
   # or for POSIX compatibility:
   #!/bin/sh
   ```

2. **Strict Mode** - Fail fast on errors
   ```bash
   #!/bin/bash
   set -euo pipefail

   # -e: exit on error
   # -u: error on unset variables
   # -o pipefail: pipeline fails if any command fails
   ```

### SHOULD (validator warns)

1. **Use `local` in Functions** - Avoid global state pollution
   ```bash
   process_data() {
       local input="$1"
       local -i count=0
       # ...
   }
   ```

2. **Trap for Cleanup with mktemp** - Don't leave temp files
   ```bash
   tmp_file=$(mktemp)
   trap 'rm -f "$tmp_file"' EXIT
   ```

3. **Use `readonly` for Constants** - Prevent accidental modification
   ```bash
   readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   readonly VERSION="1.0.0"
   ```

4. **`IFS= read -r` in Read Loops** - Preserve whitespace and backslashes
   ```bash
   while IFS= read -r line; do
       process_line "$line"
   done < "$input_file"
   ```

5. **Lines Under 100 Characters** - Readability
   ```bash
   # Break long lines with backslash
   long_command \
       --option1 \
       --option2
   ```

6. **Prefer `printf` Over `echo`** - Consistent behavior across systems
   ```bash
   # BAD - behavior varies, interprets escapes
   echo $user_input
   echo -e "tab:\there"

   # GOOD - consistent, literal
   printf '%s\n' "$user_input"
   ```

### GUIDANCE (not mechanically checked)

These are best practices that improve code quality but cannot be reliably detected with grep patterns.

1. **Quote All Variable Expansions** - Even when "it works without"
   ```bash
   echo "$var"
   cp "$src" "$dest"
   [[ -f "$file" ]]
   ```

2. **Validate Inputs** - Check arguments and file existence
   ```bash
   main() {
       [[ $# -ge 1 ]] || { usage; exit 1; }
       local input_file="$1"
       [[ -f "$input_file" ]] || { echo "File not found: $input_file"; exit 1; }
   }
   ```

3. **Use Arrays for Multiple Items** - Not space-separated strings
   ```bash
   local -a cmd_args=("-v" "--config" "$config_file")
   program "${cmd_args[@]}"
   ```

4. **Check Command Existence** - Before using external tools
   ```bash
   command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
   ```

5. **Meaningful Exit Codes** - Not just 0 and 1
   ```bash
   readonly E_SUCCESS=0
   readonly E_USAGE=1
   readonly E_NO_FILE=2
   ```

6. **Avoid Global Variables in Functions** - Use local and return via stdout
   ```bash
   # BAD
   process_file() {
       result="processed"  # global!
   }

   # GOOD
   process_file() {
       local result="processed"
       echo "$result"
   }
   ```

7. **Avoid Magic Numbers** - Use named constants
   ```bash
   readonly SECONDS_PER_DAY=86400
   sleep "$SECONDS_PER_DAY"
   ```

---

## Patterns

### Script Template
```bash
#!/bin/bash
# script-name.sh - Brief description
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
error() { log "ERROR: $*" >&2; }
die() { error "$*"; exit 1; }

cleanup() {
    local exit_code=$?
    # cleanup code here
    exit "$exit_code"
}
trap cleanup EXIT

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <input>

Options:
    -h, --help      Show this help
    -v, --verbose   Verbose output
EOF
}

main() {
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--verbose) verbose=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *) break ;;
        esac
    done

    [[ $# -ge 1 ]] || { usage; exit 1; }
    local input="$1"

    [[ -f "$input" ]] || die "File not found: $input"

    $verbose && log "Processing $input"
    process_file "$input"
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
trap 'rm -f "$tmp_file"' EXIT

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

### Colored Output
```bash
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

All scripts should pass ShellCheck (errors are blocking, warnings are advisory):

```bash
# Install
brew install shellcheck  # macOS
apt install shellcheck   # Ubuntu

# Run
shellcheck script.sh
```

### Common ShellCheck Codes
| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Quote it: `"$var"` |
| SC2046 | Unquoted command substitution | `"$(cmd)"` |
| SC2006 | Backticks | Use `$()` |
| SC2012 | Parsing ls | Use globs or find |
| SC2155 | Declare and assign separately | `local var; var=$(cmd)` |
| SC2164 | cd without error check | `cd dir || exit 1` |
