# Domain: BASH Design

Production shell script patterns. Safe, portable, maintainable. Enforces quoting, strict mode, error handling, and security best practices.


**Validation:** `bash.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Unquoted Variables in Commands** - Unquoted variables undergo word splitting and glob expansion. This breaks on filenames with spaces and can match unintended files.

   ```
   // BAD
   rm $files
   // BAD
   cp $src $dest

   // GOOD
   rm "$files"
   // GOOD
   cp "$src" "$dest"
   ```

2. **Unquoted $(cmd) Substitution** - Unquoted command substitution has the same word splitting and glob expansion issues as unquoted variables.

   ```
   // BAD
   result=$(get_path)
   cd $result
   

   // GOOD
   result="$(get_path)"
   cd "$result"
   
   ```

3. **Parsing ls Output** - Parsing ls output breaks on filenames with spaces, newlines, or special characters. Use globs or find instead.

   ```
   // BAD
   for f in $(ls *.txt); do
   // BAD
   for f in `ls`; do

   // GOOD
   for f in *.txt; do
   // GOOD
   for f in *; do
   // GOOD
   find . -name "*.txt" -print0 | while IFS= read -r -d '' f; do
   
   ```

4. **Backticks for Command Substitution** - Backticks are the old style command substitution. They can't nest easily and are harder to read than $().

   ```
   // BAD
   result=`command`

   // GOOD
   result=$(command)
   ```

5. **Single Brackets [ ] in Bash** - In bash scripts, use [[ ]] instead of [ ]. Single brackets require quoting and don't support pattern matching or regex.

   ```
   // BAD
   [ -z $var ]
   // BAD
   [ $var = "foo" ]

   // GOOD
   [[ -z "$var" ]]
   // GOOD
   [[ "$var" = "foo" ]]
   // GOOD
   [[ "$string" =~ ^[0-9]+$ ]]
   ```

6. **'function' Keyword** - The 'function' keyword is bash-specific and not POSIX compliant. Use the portable name() { } syntax.

   ```
   // BAD
   function do_something {
       ...
   }
   

   // GOOD
   do_something() {
       ...
   }
   
   ```

7. **Bare 'cd' Without Error Handling** - cd can fail (permissions, path doesn't exist). Without error handling, the script continues in the wrong directory.

   ```
   // BAD
   cd "$some_dir"
   rm -rf *  # Runs in wrong dir if cd failed!
   

   // GOOD
   cd "$some_dir" || exit 1
   // GOOD
   cd "$some_dir" || { echo "Failed to cd"; exit 1; }
   ```

8. **Useless Cat** - cat file | cmd creates an extra process. Most commands can read files directly or via stdin redirection.

   ```
   // BAD
   cat file.txt | grep 'pattern'
   // BAD
   cat file.txt | wc -l

   // GOOD
   grep 'pattern' file.txt
   // GOOD
   wc -l < file.txt
   ```

9. **eval Usage** - eval executes arbitrary code. With user input, this is command injection. Use arrays for dynamic commands.

   ```
   // BAD
   eval "$user_command"

   // GOOD
   cmd_args=("$program" "$arg1" "$arg2")
   "${cmd_args[@]}"
   
   ```

10. **Hardcoded /tmp Files** - Hardcoded temp paths are predictable and create race conditions. Use mktemp for unique, secure temporary files.

   ```
   // BAD
   tmp_file="/tmp/myscript.tmp"

   // GOOD
   tmp_file=$(mktemp)
   ```

11. **curl|bash Remote Code Execution** - Piping remote scripts directly to bash executes untrusted code. Download, inspect, then execute.

   ```
   // BAD
   curl -fsSL https://example.com/install.sh | bash

   // GOOD
   curl -fsSL https://example.com/install.sh -o install.sh
   less install.sh  # review
   ./install.sh
   
   ```

12. **Unquoted Array Expansion** - ${arr[*]} joins array elements into a single string. Use "${arr[@]}" to preserve separate elements.

   ```
   // BAD
   echo ${arr[*]}

   // GOOD
   echo "${arr[@]}"
   ```

### MUST (validator will reject)

1. **Shebang Required** - Every script must have a shebang declaring the interpreter. This ensures the script runs with the intended shell.

   ```
   #!/bin/bash
   #!/bin/sh
   #!/usr/bin/env bash
   ```

2. **Strict Mode Required** - Scripts must enable strict mode with set -euo pipefail. This catches errors early instead of silently continuing.

   ```
   #!/bin/bash
   set -euo pipefail
   ```

### SHOULD (validator warns)

1. **Safe Path Pattern Before cd** - When using cd, either use pushd/popd or capture the original directory to ensure relative paths still work after directory change.

   ```
   pushd "$target_dir" > /dev/null
   # ... do work
   popd > /dev/null
   original_dir="$(pwd)"
   cd "$project_dir"
   cat "$original_dir/config.json"
   ```

2. **Functions Should Use 'local'** - Variables assigned in functions should use 'local' to avoid polluting the global namespace.

   ```
   // BAD
   process_file() {
       result="processed"  # Global!
   }
   

   // GOOD
   process_file() {
       local result="processed"
   }
   
   ```

3. **mktemp Needs Cleanup Trap** - Scripts using mktemp should set up a trap to clean up temp files on exit, even if the script fails.

   ```
   tmp_file=$(mktemp)
   trap 'rm -f "$tmp_file"' EXIT
   ```

4. **Constants Should Use readonly** - Script constants (UPPER_CASE variables) should use readonly to prevent accidental modification.

   ```
   // BAD
   VERSION="1.0.0"

   // GOOD
   readonly VERSION="1.0.0"
   ```

5. **Read Loops Need 'IFS= read -r'** - Read loops should use 'IFS= read -r' to preserve whitespace and backslashes in input.

   ```
   // BAD
   while read line; do

   // GOOD
   while IFS= read -r line; do
   ```

6. **Lines Under 100 Characters** - Keep lines under 100 characters for readability. Use backslash continuation for long commands.

   ```
   long_command \
       --option1 \
       --option2
   ```

7. **Prefer printf Over echo** - printf behavior is consistent across systems. echo behavior varies (escapes, options) between shells and platforms.

   ```
   // BAD
   echo "$user_input"
   // BAD
   echo -e "tab:\there"

   // GOOD
   printf '%s
   ' "$user_input"
   ```

### GUIDANCE (not mechanically checked)

1. **Script Template** - Standard template for production shell scripts with error handling, argument parsing, and cleanup.


   > #!/bin/bash
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

main "$@"


2. **Safe File Operations** - Patterns for safe temporary files, directory changes, and file reading.


   > # Safe temporary files
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


3. **Colored Output** - Pattern for terminal-aware colored output that degrades gracefully when not connected to a terminal.


   > if [[ -t 1 ]]; then
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


4. **ShellCheck Codes Reference** - Common ShellCheck error codes and their fixes.


   > Run: shellcheck script.sh

Common codes:
| Code   | Issue                          | Fix                    |
|--------|--------------------------------|------------------------|
| SC2086 | Unquoted variable              | Quote it: "$var"       |
| SC2046 | Unquoted command substitution  | "$(cmd)"               |
| SC2006 | Backticks                      | Use $()                |
| SC2012 | Parsing ls                     | Use globs or find      |
| SC2155 | Declare and assign separately  | local var; var=$(cmd)  |
| SC2164 | cd without error check         | cd dir || exit 1       |


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| $var unquoted |  | "$var" |
| [ ] test |  | [[ ]] |
| Backticks |  | $() |
| cd dir alone |  | cd dir || exit 1 |
| for f in $(ls) |  | for f in * |
| cat f | grep |  | grep pattern f |
| function f { |  | f() { |
| Global in functions |  | local |
| No set -e |  | set -euo pipefail |
| Predictable /tmp |  | mktemp |
| curl | bash |  | Download, inspect, run |
