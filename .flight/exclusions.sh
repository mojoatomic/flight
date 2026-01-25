#!/usr/bin/env bash
# =============================================================================
# Flight Exclusions - Centralized file exclusion system
# =============================================================================
#
# Source this file in validators to exclude build artifacts from file scans.
#
# Usage:
#   source .flight/exclusions.sh
#   FILES=($(flight_get_files "**/*.ts" "**/*.tsx"))
#
# =============================================================================

# Standard directories to exclude from validation
# Projects can extend this array before calling flight_get_files()
FLIGHT_EXCLUDE_DIRS=(
    # Package managers
    "node_modules"
    "vendor"
    ".venv"
    "venv"

    # Build outputs
    "dist"
    "build"
    "target"
    "obj"
    ".next"
    ".turbo"
    "out"
    ".output"
    ".nuxt"
    ".svelte-kit"

    # VCS
    ".git"

    # IDE
    ".idea"
    ".vscode"

    # Test/Coverage
    "coverage"
    ".pytest_cache"
    ".nyc_output"
    ".coverage"
    "__pycache__"
    ".tox"
    ".nox"

    # Test fixtures (intentionally contain violations for testing)
    "fixtures"
    "validator-fixtures"

    # Test directories (framework tests, not user code)
    "tests"
    "test"
    "__tests__"
    "e2e"

    # Cache directories
    ".cache"
    ".parcel-cache"
    ".webpack"
    ".rollup.cache"

    # Infrastructure
    ".terraform"
    ".serverless"

    # Framework directories (never scan framework config/tooling)
    ".flight"
    ".flight/tests"
    ".claude"

    # Flight tooling (linter should not lint itself)
    "flight-lint"

    # Dev scripts and tooling (internal, not product code)
    "scripts"
    "tooling"
    "tools"

    # Documentation (may contain code examples, not product code)
    "docs"
)

# Files to exclude from validation (auto-generated or upstream-managed)
# These are filename patterns matched with bash [[ == ]] glob matching
FLIGHT_EXCLUDE_FILES=(
    # Auto-generated (edits would be lost)
    "supabase.ts"
    "database.types.ts"
    "*.generated.ts"
    "graphql.ts"

    # Upstream-managed (Flight framework files)
    "update.sh"

    # Config files (not source code - tooling configuration)
    "*.config.js"
    "*.config.ts"
    "*.config.mjs"
    "*.config.cjs"
    "eslint.config.*"
    "prettier.config.*"
    "vitest.config.*"
    "vite.config.*"
    "jest.config.*"
    "webpack.config.*"
    "rollup.config.*"
    "tailwind.config.*"
    "postcss.config.*"
    "next.config.*"
    "nuxt.config.*"
    "svelte.config.*"
    "astro.config.*"
    "tsconfig.json"
    "tsconfig.*.json"
    "jsconfig.json"

    # Package manifests (not source code)
    "package.json"
    "package-lock.json"
    "pnpm-lock.yaml"
    "yarn.lock"
    "bun.lockb"
    "Cargo.toml"
    "Cargo.lock"
    "go.mod"
    "go.sum"
    "requirements.txt"
    "pyproject.toml"
    "poetry.lock"
    "Gemfile"
    "Gemfile.lock"
    "composer.json"
    "composer.lock"
)

# -----------------------------------------------------------------------------
# flight_load_flightignore - Load project-specific exclusions from .flightignore
# -----------------------------------------------------------------------------
# Reads .flightignore file (if exists) and adds patterns to exclusion arrays.
# Supports gitignore-style patterns:
#   - Lines starting with # are comments
#   - Blank lines are ignored
#   - Patterns ending with / are directory patterns
#   - All other patterns are file patterns
#
# Usage: Call once at start of validation
#   flight_load_flightignore
# -----------------------------------------------------------------------------
flight_load_flightignore() {
    local search_dir="${FLIGHT_SEARCH_DIR:-.}"
    local ignore_file="$search_dir/.flightignore"

    # Return early if no .flightignore file exists
    [[ ! -f "$ignore_file" ]] && return 0

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue

        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue

        # Patterns ending with / are directory patterns
        if [[ "$line" == */ ]]; then
            # Remove trailing slash for directory name
            FLIGHT_EXCLUDE_DIRS+=("${line%/}")
        else
            # File pattern
            FLIGHT_EXCLUDE_FILES+=("$line")
        fi
    done < "$ignore_file"
}

# Auto-load .flightignore when this script is sourced
flight_load_flightignore

# -----------------------------------------------------------------------------
# Test file patterns for categorization
# -----------------------------------------------------------------------------
# These patterns identify test files that should be validated by the testing
# domain rather than source-code domains. Used by flight_is_test_file().
# -----------------------------------------------------------------------------
FLIGHT_TEST_FILE_PATTERNS=(
    # JavaScript/TypeScript test files
    "*.test.js"
    "*.test.ts"
    "*.test.jsx"
    "*.test.tsx"
    "*.spec.js"
    "*.spec.ts"
    "*.spec.jsx"
    "*.spec.tsx"

    # Python test files
    "test_*.py"
    "*_test.py"

    # Go test files
    "*_test.go"

    # Java test files
    "*Test.java"
    "*Tests.java"

    # Rust test files (embedded in source, but also separate files)
    "*_test.rs"
)

# Test directories - files inside these are always test files
FLIGHT_TEST_DIRS=(
    "tests"
    "test"
    "__tests__"
    "e2e"
    "spec"
    "integration-tests"
    "unit-tests"
)

# -----------------------------------------------------------------------------
# flight_is_test_file - Check if a path is a test file
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - File path to check
# Returns:
#   0 (true) if path is a test file
#   1 (false) if path is not a test file
#
# Usage:
#   if flight_is_test_file "$file"; then
#       echo "Skipping test file: $file"
#       continue
#   fi
# -----------------------------------------------------------------------------
flight_is_test_file() {
    local filepath="$1"
    local dir
    local pattern
    local filename

    # Check if file is in a test directory
    for dir in "${FLIGHT_TEST_DIRS[@]}"; do
        if [[ "$filepath" == *"/$dir/"* ]] || [[ "$filepath" == "$dir/"* ]]; then
            return 0
        fi
    done

    # Check file patterns
    filename=$(basename "$filepath")
    for pattern in "${FLIGHT_TEST_FILE_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# flight_is_excluded - Check if a path should be excluded
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - File path to check
# Returns:
#   0 (true) if path should be excluded
#   1 (false) if path should be included
# -----------------------------------------------------------------------------
flight_is_excluded() {
    local filepath="$1"
    local dir
    local pattern
    local filename

    # Check directory exclusions
    for dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
        # Check if path contains the excluded directory as a component
        # Matches: node_modules/foo, ./node_modules/bar, src/node_modules/baz
        if [[ "$filepath" == *"/$dir/"* ]] || [[ "$filepath" == "$dir/"* ]] || [[ "$filepath" == *"/$dir" ]]; then
            return 0
        fi
    done

    # Check file exclusions (auto-generated files)
    filename=$(basename "$filepath")
    for pattern in "${FLIGHT_EXCLUDE_FILES[@]}"; do
        # Use glob matching for patterns like *.generated.ts
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# flight_build_find_excludes - Build find command exclusion arguments
# -----------------------------------------------------------------------------
# Returns exclusion arguments for find command via stdout
# -----------------------------------------------------------------------------
flight_build_find_excludes() {
    local dir
    local first=true

    echo -n "("
    for dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo -n " -o"
        fi
        echo -n " -name \"$dir\""
    done
    echo -n " ) -prune -o"
}

# -----------------------------------------------------------------------------
# flight_get_files - Get files matching patterns, excluding standard dirs
# -----------------------------------------------------------------------------
# Arguments:
#   $@ - Glob patterns (e.g., "*.ts" "*.tsx")
#        Patterns should NOT include **/ prefix - it's added automatically
# Output:
#   Files matching patterns, one per line (suitable for mapfile or while read)
# Example:
#   FILES=($(flight_get_files "*.ts" "*.tsx"))
#   mapfile -t FILES < <(flight_get_files "*.ts" "*.tsx")
# -----------------------------------------------------------------------------
flight_get_files() {
    local patterns=("$@")
    local search_dir="${FLIGHT_SEARCH_DIR:-.}"

    # Build the find command dynamically
    # We use find instead of globstar because:
    # 1. find handles exclusions more reliably
    # 2. globstar can be slow on large trees
    # 3. find works consistently across bash versions

    local find_cmd="find \"$search_dir\" "

    # Add exclusions - prune directories we don't want to descend into
    find_cmd+="\\( "
    local first=true
    for dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            find_cmd+="-o "
        fi
        # Use -path for entries containing /, -name for simple directory names
        if [[ "$dir" == */* ]]; then
            find_cmd+="-type d -path \"*/$dir\" "
        else
            find_cmd+="-type d -name \"$dir\" "
        fi
    done
    find_cmd+="\\) -prune -o "

    # Add file type filter
    find_cmd+="-type f "

    # Add pattern matching
    if [[ ${#patterns[@]} -gt 0 ]]; then
        find_cmd+="\\( "
        first=true
        for pattern in "${patterns[@]}"; do
            # Strip **/ prefix if present - find searches recursively by default
            pattern="${pattern#\*\*/}"
            if [[ "$first" == true ]]; then
                first=false
            else
                find_cmd+="-o "
            fi
            find_cmd+="-name \"$pattern\" "
        done
        find_cmd+="\\) "
    fi

    find_cmd+="-print"

    # Execute and output results
    # Use subshell to isolate potential errors from set -e
    # Filter through flight_filter_excluded to remove auto-generated files
    # Redirect stdin from /dev/null to prevent hanging in piped contexts (curl | bash)
    (eval "$find_cmd" < /dev/null 2>/dev/null || true) | flight_filter_excluded | sort
}

# -----------------------------------------------------------------------------
# flight_get_files_for_patterns - Convert glob patterns to file list
# -----------------------------------------------------------------------------
# Uses find for pattern matching (works on bash 3.2+, no globstar needed)
#
# Arguments:
#   $@ - Full glob patterns including path (e.g., "src/**/*.ts")
# Output:
#   Files matching patterns, one per line, with exclusions applied
# -----------------------------------------------------------------------------
flight_get_files_for_patterns() {
    local patterns=("$@")
    local search_dir="${FLIGHT_SEARCH_DIR:-.}"

    for pattern in "${patterns[@]}"; do
        # Extract directory prefix and filename pattern from glob
        # e.g., "src/**/*.ts" -> search in "src", match "*.ts"
        local dir_part=""
        local name_part=""

        if [[ "$pattern" == *"/"* ]]; then
            # Has path component - extract it
            # Remove **/ and everything after to get base dir
            dir_part="${pattern%%\*\**}"
            dir_part="${dir_part%/}"
            # Get the filename pattern (last component)
            name_part="${pattern##*/}"
        else
            dir_part="$search_dir"
            name_part="$pattern"
        fi

        # Default to current dir if empty
        [[ -z "$dir_part" ]] && dir_part="$search_dir"

        # Skip if directory doesn't exist
        [[ ! -d "$dir_part" ]] && continue

        # Build find exclusions
        local find_excludes=""
        for excl_dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
            find_excludes="$find_excludes -not -path \"*/$excl_dir/*\""
        done

        # Run find - redirect stdin from /dev/null to prevent hanging in piped contexts
        eval "find \"$dir_part\" -type f -name \"$name_part\" $find_excludes < /dev/null 2>/dev/null"
    done | flight_filter_excluded | sort -u
}

# -----------------------------------------------------------------------------
# flight_build_find_not_paths - Build find -not -path arguments dynamically
# -----------------------------------------------------------------------------
# Returns exclusion arguments for find command via stdout
# Usage: eval "find . -type f -name '*.ts' $(flight_build_find_not_paths)"
# -----------------------------------------------------------------------------
flight_build_find_not_paths() {
    local dir
    for dir in "${FLIGHT_EXCLUDE_DIRS[@]}"; do
        printf ' -not -path "*/%s/*"' "$dir"
    done
}

# -----------------------------------------------------------------------------
# flight_filter_excluded - Filter a list of files, removing excluded paths
# -----------------------------------------------------------------------------
# Input:
#   Files via stdin, one per line
# Output:
#   Files not in excluded directories, one per line
# Example:
#   find . -name "*.ts" | flight_filter_excluded
# -----------------------------------------------------------------------------
flight_filter_excluded() {
    local file
    while IFS= read -r file; do
        if ! flight_is_excluded "$file"; then
            echo "$file"
        fi
    done
}
