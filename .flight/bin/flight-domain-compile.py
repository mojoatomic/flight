#!/usr/bin/env python3
"""
flight-domain-compile: Generate .md and .validate.sh from .flight YAML

Usage:
    flight-domain-compile api              # Compile api.flight
    flight-domain-compile --all            # Compile all .flight files
    flight-domain-compile --check api      # Dry-run, show changes
    flight-domain-compile --md-only api    # Generate .md only
    flight-domain-compile --sh-only api    # Generate .sh only

Single source of truth: .flight YAML generates both spec and validator.
"""

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Any, Optional


# Severity levels in order
SEVERITIES = ["NEVER", "MUST", "SHOULD", "GUIDANCE"]

# Schema versions
SCHEMA_V1 = 1  # Original format, no provenance
SCHEMA_V2 = 2  # Provenance metadata (domain + rule level)


@dataclass
class SourceReference:
    """A source reference with optional quote."""
    url: str
    accessed: Optional[str] = None
    quote: Optional[str] = None


@dataclass
class SupersededBy:
    """Tracks what replaced a deprecated pattern."""
    replacement: str
    version: str
    date: Optional[str] = None
    note: Optional[str] = None


@dataclass
class RuleProvenance:
    """Provenance metadata for a single rule."""
    last_verified: Optional[str] = None
    confidence: str = "high"  # high, medium, low
    re_verify_after: Optional[str] = None
    sources: list = field(default_factory=list)  # List of SourceReference
    superseded_by: Optional[SupersededBy] = None


@dataclass
class DomainProvenance:
    """Provenance metadata for the entire domain."""
    last_full_audit: Optional[str] = None
    audited_by: Optional[str] = None
    next_audit_due: Optional[str] = None
    sources_consulted: list = field(default_factory=list)
    coverage: dict = field(default_factory=dict)  # apis_covered, known_gaps


@dataclass
class Rule:
    """Represents a single rule from the .flight file."""
    id: str
    title: str
    severity: str
    mechanical: bool
    description: str = ""
    note: str = ""
    check: dict = field(default_factory=dict)
    examples: dict = field(default_factory=dict)
    api_files_only: bool = False
    provenance: Optional[RuleProvenance] = None


@dataclass
class DomainSpec:
    """Represents a parsed .flight domain specification."""
    domain: str
    version: str
    description: str
    file_patterns: list
    api_file_detection: dict
    rules: dict  # {id: Rule}
    schema_version: int = SCHEMA_V1
    provenance: Optional[DomainProvenance] = None
    patterns: dict = field(default_factory=dict)
    info: dict = field(default_factory=dict)
    anti_patterns: list = field(default_factory=list)
    sources: list = field(default_factory=list)
    exclude_patterns: list = field(default_factory=list)

    def rules_by_severity(self, severity: str) -> list:
        """Get rules filtered by severity, sorted by ID."""
        rules = [r for r in self.rules.values() if r.severity == severity]
        return sorted(rules, key=lambda r: (r.id[0], int(r.id[1:])))

    def mechanical_rules(self) -> list:
        """Get all rules with mechanical=true."""
        return [r for r in self.rules.values() if r.mechanical]

    def stale_rules(self) -> list:
        """Get rules past their re_verify_after date."""
        today = date.today().isoformat()
        stale = []
        for r in self.rules.values():
            if r.provenance and r.provenance.re_verify_after:
                if r.provenance.re_verify_after < today:
                    stale.append(r)
        return stale

    def unverified_rules(self) -> list:
        """Get mechanical rules without provenance sources."""
        return [r for r in self.rules.values()
                if r.mechanical and (not r.provenance or not r.provenance.sources)]


def parse_rule_provenance(prov_data: dict) -> RuleProvenance:
    """Parse rule-level provenance data."""
    sources = []
    for src in prov_data.get("sources", []):
        if isinstance(src, dict):
            sources.append(SourceReference(
                url=src.get("url", ""),
                accessed=src.get("accessed"),
                quote=src.get("quote"),
            ))
        elif isinstance(src, str):
            sources.append(SourceReference(url=src))

    superseded_by = None
    sup_data = prov_data.get("superseded_by")
    if sup_data and isinstance(sup_data, dict):
        superseded_by = SupersededBy(
            replacement=sup_data.get("replacement", ""),
            version=sup_data.get("version", ""),
            date=sup_data.get("date"),
            note=sup_data.get("note"),
        )

    return RuleProvenance(
        last_verified=prov_data.get("last_verified"),
        confidence=prov_data.get("confidence", "high"),
        re_verify_after=prov_data.get("re_verify_after"),
        sources=sources,
        superseded_by=superseded_by,
    )


def parse_domain_provenance(prov_data: dict) -> DomainProvenance:
    """Parse domain-level provenance data."""
    sources_consulted = []
    for src in prov_data.get("sources_consulted", []):
        if isinstance(src, dict):
            sources_consulted.append(src)
        elif isinstance(src, str):
            sources_consulted.append({"url": src})

    return DomainProvenance(
        last_full_audit=prov_data.get("last_full_audit"),
        audited_by=prov_data.get("audited_by"),
        next_audit_due=prov_data.get("next_audit_due"),
        sources_consulted=sources_consulted,
        coverage=prov_data.get("coverage", {}),
    )


def parse_rules(rules_data: dict) -> dict:
    """Parse rules dictionary into Rule objects."""
    rules = {}
    for rule_id, rule_data in rules_data.items():
        if not isinstance(rule_data, dict):
            continue

        # Parse provenance if present
        provenance = None
        if "provenance" in rule_data:
            provenance = parse_rule_provenance(rule_data["provenance"])

        rules[rule_id] = Rule(
            id=rule_id,
            title=rule_data.get("title", ""),
            severity=rule_data.get("severity", "GUIDANCE"),
            mechanical=rule_data.get("mechanical", False),
            description=rule_data.get("description", ""),
            note=rule_data.get("note", ""),
            check=rule_data.get("check", {}),
            examples=rule_data.get("examples", {}),
            api_files_only=rule_data.get("api_files_only", False),
            provenance=provenance,
        )

    return rules


def validate_spec(data: dict, domain: str) -> tuple[list, list]:
    """Validate the parsed YAML structure. Returns (errors, warnings)."""
    errors = []
    warnings = []

    # Required top-level fields
    if "domain" not in data:
        errors.append(f"{domain}.flight: Missing required field 'domain'")
    if "rules" not in data:
        errors.append(f"{domain}.flight: Missing required field 'rules'")

    # Check schema version
    schema_version = data.get("schema_version", SCHEMA_V1)

    # Validate rules
    rules = data.get("rules", {})
    today = date.today().isoformat()

    for rule_id, rule_data in rules.items():
        if not isinstance(rule_data, dict):
            continue

        # Required rule fields
        if "title" not in rule_data:
            errors.append(f"{domain}.flight: Rule {rule_id} missing 'title'")
        if "severity" not in rule_data:
            errors.append(f"{domain}.flight: Rule {rule_id} missing 'severity'")

        # Validate severity value
        severity = rule_data.get("severity", "")
        if severity and severity not in SEVERITIES:
            errors.append(
                f"{domain}.flight: Rule {rule_id} has invalid severity '{severity}'"
            )

        # mechanical:true requires check config
        if rule_data.get("mechanical") and not rule_data.get("check"):
            errors.append(
                f"{domain}.flight: Rule {rule_id} has mechanical:true but no check config"
            )

        # Validate check type if present
        check = rule_data.get("check", {})
        if check:
            check_type = check.get("type")
            valid_types = ["grep", "presence", "script", "multi-condition", "file_exists"]
            if check_type and check_type not in valid_types:
                errors.append(
                    f"{domain}.flight: Rule {rule_id} has unknown check type '{check_type}'"
                )

            # Validate regex patterns for grep and presence checks
            if check_type in ("grep", "presence"):
                pattern = check.get("pattern", "")
                if pattern and not validate_regex_pattern(pattern, rule_id, domain):
                    errors.append(
                        f"{domain}.flight: Rule {rule_id} has invalid regex pattern"
                    )

            # Validate regex patterns in multi-condition checks
            if check_type == "multi-condition":
                for i, cond in enumerate(check.get("conditions", [])):
                    pattern = cond.get("pattern", "")
                    if pattern and not validate_regex_pattern(pattern, f"{rule_id}.conditions[{i}]", domain):
                        errors.append(
                            f"{domain}.flight: Rule {rule_id} condition {i} has invalid regex pattern"
                        )

        # Provenance warnings (schema v2)
        provenance = rule_data.get("provenance", {})
        if rule_data.get("mechanical"):
            if not provenance.get("sources"):
                warnings.append(
                    f"{domain}.flight: Rule {rule_id} has no sources (unverifiable)"
                )
            re_verify = provenance.get("re_verify_after")
            if re_verify and re_verify < today:
                warnings.append(
                    f"{domain}.flight: Rule {rule_id} is stale (due {re_verify})"
                )
            confidence = provenance.get("confidence", "high")
            if confidence == "low":
                warnings.append(
                    f"{domain}.flight: Rule {rule_id} has low confidence"
                )

    # Validate info section patterns
    info = data.get("info", {})
    for info_id, info_config in info.items():
        if not isinstance(info_config, dict):
            continue
        pattern = info_config.get("pattern", "")
        if pattern and not validate_regex_pattern(pattern, f"info.{info_id}", domain):
            errors.append(
                f"{domain}.flight: Info {info_id} has invalid regex pattern"
            )

    # Domain-level provenance warnings
    domain_prov = data.get("provenance", {})
    if domain_prov:
        next_audit = domain_prov.get("next_audit_due")
        if next_audit and next_audit < today:
            warnings.append(
                f"{domain}.flight: Domain audit overdue (due {next_audit})"
            )

    return errors, warnings


def parse_domain_spec(data: dict) -> DomainSpec:
    """Parse raw YAML data into a DomainSpec object."""
    # Parse domain-level provenance if present
    provenance = None
    if "provenance" in data:
        provenance = parse_domain_provenance(data["provenance"])

    return DomainSpec(
        domain=data.get("domain", ""),
        version=data.get("version", "1.0.0"),
        description=data.get("description", ""),
        file_patterns=data.get("file_patterns", []),
        api_file_detection=data.get("api_file_detection", {}),
        rules=parse_rules(data.get("rules", {})),
        schema_version=data.get("schema_version", SCHEMA_V1),
        provenance=provenance,
        patterns=data.get("patterns", {}),
        info=data.get("info", {}),
        anti_patterns=data.get("anti_patterns", []),
        sources=data.get("sources", []),
        exclude_patterns=data.get("exclude_patterns", []),
    )


def get_domains_dir() -> Path:
    """Get the .flight/domains directory path."""
    script_dir = Path(__file__).parent
    return script_dir.parent / "domains"


# =============================================================================
# Markdown Generator
# =============================================================================

def format_examples_md(examples: dict, rule: Rule) -> str:
    """Format examples as markdown code blocks."""
    lines = []

    def expand_example(ex: str) -> list:
        """Expand escaped newlines in examples."""
        # Replace literal \n with actual newlines
        return ex.replace("\\n", "\n").split("\n")

    # Handle different example structures
    if "bad" in examples:
        lines.append("   ```")
        for ex in examples.get("bad", []):
            lines.append(f"   // BAD")
            for line in expand_example(ex):
                lines.append(f"   {line}")
        if examples.get("good"):
            lines.append("")
            for ex in examples.get("good", []):
                lines.append(f"   // GOOD")
                for line in expand_example(ex):
                    lines.append(f"   {line}")
        lines.append("   ```")
    elif "reference" in examples:
        # For rules with reference examples (like M1, M2)
        lines.append("   ```")
        for ex in examples.get("reference", []):
            lines.append(f"   {ex}")
        lines.append("   ```")
    elif "breaking" in examples and "non_breaking" in examples:
        # For N4 (breaking changes)
        lines.append("   ```")
        lines.append("   Breaking changes:")
        for ex in examples.get("breaking", []):
            lines.append(f"   - {ex}")
        lines.append("")
        lines.append("   Non-breaking changes (additive):")
        for ex in examples.get("non_breaking", []):
            lines.append(f"   - {ex}")
        lines.append("   ```")
    else:
        # Generic handling for other structures
        for key, value in examples.items():
            if isinstance(value, list):
                lines.append("   ```")
                if key not in ("bad", "good"):
                    lines.append(f"   {key.replace('_', ' ').title()}:")
                for ex in value:
                    if isinstance(ex, str):
                        for line in ex.strip().split("\n"):
                            lines.append(f"   {line}")
                lines.append("   ```")
            elif isinstance(value, str):
                lines.append("   ```")
                for line in value.strip().split("\n"):
                    lines.append(f"   {line}")
                lines.append("   ```")

    return "\n".join(lines)


def generate_rule_md(rule: Rule, number: int) -> str:
    """Generate markdown for a single rule."""
    lines = []

    # Rule title
    title = f"{number}. **{rule.title}**"
    if rule.description:
        title += f" - {rule.description}"
    lines.append(title)

    # Non-mechanical warning
    if not rule.mechanical and rule.note:
        lines.append("")
        lines.append(f"   > {rule.note}")

    # Examples
    if rule.examples:
        lines.append(format_examples_md(rule.examples, rule))

    lines.append("")
    return "\n".join(lines)


def generate_md(spec: DomainSpec) -> str:
    """Generate the complete markdown document."""
    lines = []

    # Header
    domain_title = spec.domain.upper() if len(spec.domain) <= 4 else spec.domain.title()
    lines.append(f"# Domain: {domain_title} Design")
    lines.append("")
    lines.append(spec.description)
    lines.append("")
    lines.append(
        f"**Validation:** `{spec.domain}.validate.sh` enforces NEVER/MUST rules. "
        "SHOULD rules trigger warnings. GUIDANCE is not mechanically checked."
    )
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Invariants")
    lines.append("")

    # Generate each severity section
    severity_headers = {
        "NEVER": "### NEVER (validator will reject)",
        "MUST": "### MUST (validator will reject)",
        "SHOULD": "### SHOULD (validator warns)",
        "GUIDANCE": "### GUIDANCE (not mechanically checked)",
    }

    for severity in SEVERITIES:
        rules = spec.rules_by_severity(severity)
        if not rules:
            continue

        lines.append(severity_headers[severity])
        lines.append("")

        for i, rule in enumerate(rules, 1):
            lines.append(generate_rule_md(rule, i))

    # Anti-patterns table
    if spec.anti_patterns:
        lines.append("---")
        lines.append("")
        lines.append("## Anti-Patterns")
        lines.append("")
        lines.append("| Anti-Pattern | Description | Fix |")
        lines.append("|--------------|-------------|-----|")
        for ap in spec.anti_patterns:
            pattern = ap.get("pattern", "")
            example = ap.get("example", "")
            fix = ap.get("fix", "")
            lines.append(f"| {pattern} | {example} | {fix} |")
        lines.append("")

    # Research sources (if we have them in the spec)
    sources = spec.patterns.get("sources", [])
    if sources:
        lines.append("---")
        lines.append("")
        lines.append("## Research Sources")
        lines.append("")
        for source in sources:
            lines.append(f"- {source}")
        lines.append("")

    return "\n".join(lines)


# =============================================================================
# Shell Script Generator
# =============================================================================

def generate_sh_header(spec: DomainSpec) -> str:
    """Generate the shell script header and helper functions."""
    # Convert file_patterns to bash glob patterns
    patterns = " ".join(spec.file_patterns)

    # Extract just the extensions for flight_get_files (e.g., "*.ts" from "**/*.ts")
    file_exts = []
    for p in spec.file_patterns:
        # Strip **/ prefix and path components, keep just the filename pattern
        ext = p.split("/")[-1] if "/" in p else p
        if ext and ext not in file_exts:
            file_exts.append(ext)
    file_ext_patterns = " ".join(f'"{ext}"' for ext in file_exts)

    # Generate find -name patterns for fallback (e.g., -name "*.ts" -o -name "*.tsx")
    find_name_parts = [f'-name "{ext}"' for ext in file_exts]
    find_patterns = " -o ".join(find_name_parts)

    return f'''#!/usr/bin/env bash
# {spec.domain}.validate.sh - {spec.description.split(".")[0]}
# Generated by flight-domain-compile from {spec.domain}.flight
set -euo pipefail

# Script location for sourcing helpers
SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"

# Default: common file patterns
DEFAULT_PATTERNS="{patterns}"
PASS=0
FAIL=0
WARN=0

red() {{ printf '\\033[31m%s\\033[0m\\n' "$1"; }}
green() {{ printf '\\033[32m%s\\033[0m\\n' "$1"; }}
yellow() {{ printf '\\033[33m%s\\033[0m\\n' "$1"; }}

check() {{
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++)) || true
    else
        red "❌ $name"
        printf '%s\\n' "$result" | head -10 | sed 's/^/   /'
        ((FAIL++)) || true
    fi
}}

warn() {{
    local name="$1"
    shift
    local result
    result=$("$@" 2>/dev/null) || true
    if [[ -z "$result" ]]; then
        green "✅ $name"
        ((PASS++)) || true
    else
        yellow "⚠️  $name"
        printf '%s\\n' "$result" | head -5 | sed 's/^/   /'
        ((WARN++)) || true
    fi
}}

printf '%s\\n' "═══════════════════════════════════════════"
printf '%s\\n' "  {spec.domain.upper()} Domain Validation"
printf '%s\\n' "═══════════════════════════════════════════"
printf '\\n'

# Source exclusions helper if available
if [[ -f "$SCRIPT_DIR/../exclusions.sh" ]]; then
    source "$SCRIPT_DIR/../exclusions.sh"
    FLIGHT_HAS_EXCLUSIONS=true
else
    FLIGHT_HAS_EXCLUSIONS=false
fi

# Handle arguments or use defaults
if [[ $# -gt 0 ]]; then
    FILES=("$@")
elif [[ "$FLIGHT_HAS_EXCLUSIONS" == true ]]; then
    # Use exclusions-aware file discovery
    mapfile -t FILES < <(flight_get_files {file_ext_patterns})
else
    # Fallback: use find (works on bash 3.2+, no globstar needed)
    mapfile -t FILES < <(find . -type f \\( {find_patterns} \\) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null | sort)
fi

if [[ ${{#FILES[@]}} -eq 0 ]]; then
    yellow "No files found matching default patterns"
    printf '%s\\n' "  Patterns: {patterns[:60]}..."
    printf '\\n'
    green "  RESULT: SKIP (no files)"
    exit 0
fi

printf 'Files: %d\\n\\n' "${{#FILES[@]}}"
'''


def generate_api_file_detection(spec: DomainSpec) -> str:
    """Generate the is_api_file function if api_file_detection is configured."""
    if not spec.api_file_detection:
        return ""

    detection = spec.api_file_detection
    paths = detection.get("paths", [])
    patterns = detection.get("patterns", [])

    # Build path regex
    path_regex = "|".join(paths) if paths else ""

    # Build content pattern regex
    content_patterns = "|".join(patterns) if patterns else ""

    return f'''
# Filter to actual API endpoint files for API-specific checks
is_api_file() {{
    local f="$1"
    # Path-based detection
    if [[ "$f" =~ ({path_regex}) ]]; then
        return 0
    fi
    # Content-based detection
    if grep -qE "{content_patterns}" "$f" 2>/dev/null; then
        return 0
    fi
    return 1
}}

API_ENDPOINT_FILES=()
for f in "${{FILES[@]}}"; do
    if is_api_file "$f"; then
        API_ENDPOINT_FILES+=("$f")
    fi
done

if [[ ${{#API_ENDPOINT_FILES[@]}} -gt 0 ]]; then
    printf 'API endpoint files: %d\\n\\n' "${{#API_ENDPOINT_FILES[@]}}"
else
    printf 'API endpoint files: 0 (some checks will be skipped)\\n\\n'
fi
'''


def escape_bash_pattern(pattern: str) -> str:
    """Escape a pattern for use in bash double quotes."""
    # Escape characters that have special meaning in bash double quotes
    # Don't escape single quotes as they're literal in double quotes
    result = pattern
    # Escape backslashes first to avoid double-escaping
    result = result.replace("\\", "\\\\")
    # Escape double quotes
    result = result.replace('"', '\\"')
    # Escape dollar signs (variable expansion)
    result = result.replace("$", "\\$")
    # Escape backticks (command substitution)
    result = result.replace("`", "\\`")
    return result


def escape_for_single_quotes(s: str) -> str:
    """Escape a string for use inside bash single quotes.

    In single quotes, only single quotes need escaping, using the pattern:
    ' -> '\''  (end quote, escaped quote, start quote)
    """
    return s.replace("'", "'\"'\"'")


def escape_pattern_for_bash_c(pattern: str) -> str:
    """Escape a pattern for use inside bash -c 'grep "pattern" ...'.

    The outer command uses single quotes, so single quotes in the pattern
    need special handling. The pattern is placed in double quotes for grep,
    so characters special in double quotes need escaping for the inner bash.
    """
    # First, escape characters special in double quotes (for the inner bash)
    result = pattern
    result = result.replace("\\", "\\\\")  # backslash
    result = result.replace("$", "\\$")     # dollar sign
    result = result.replace('"', '\\"')     # double quote
    result = result.replace("`", "\\`")     # backtick

    # Then, escape single quotes for the outer single-quoted context
    result = result.replace("'", "'\"'\"'")

    return result


def generate_check_command(rule: Rule) -> str:
    """Generate the bash command for a rule's check configuration."""
    check = rule.check
    check_type = check.get("type", "")

    if check_type == "grep":
        pattern = check.get("pattern", "")
        flags = check.get("flags", "-E")
        if isinstance(flags, list):
            flags = " ".join(flags)

        # Direct grep - escape for double quotes
        escaped_pattern = escape_bash_pattern(pattern)
        return f'grep {flags} "{escaped_pattern}" "${{FILES[@]}}"'

    elif check_type == "presence":
        pattern = check.get("pattern", "")
        flags = check.get("flags", "-l")
        message = check.get("message", "Pattern not found")

        # For presence checks using bash -c, escape pattern properly
        escaped_pattern = escape_pattern_for_bash_c(pattern)
        escaped_message = escape_for_single_quotes(message)

        return f"bash -c 'grep -q{flags[1:] if flags.startswith('-') else flags} \"{escaped_pattern}\" \"$@\" || echo \"{escaped_message}\"' _ \"${{FILES[@]}}\""

    elif check_type == "script":
        code = check.get("code", "").strip()
        # Escape single quotes for embedding in bash -c
        code = code.replace("'", "'\"'\"'")
        return f"bash -c '{code}' _ \"${{FILES[@]}}\""

    elif check_type == "multi-condition":
        logic = check.get("logic", "AND")
        conditions = check.get("conditions", [])

        if len(conditions) < 2:
            return "# multi-condition with < 2 conditions"

        # Build compound check - use escape_pattern_for_bash_c since we're in bash -c
        checks = []
        for cond in conditions:
            pattern = cond.get("pattern", "")
            flags = cond.get("flags", "-Ei")
            escaped_pattern = escape_pattern_for_bash_c(pattern)
            checks.append(f'grep -q{flags[1:]} "{escaped_pattern}" "$f"')

        operator = " && " if logic == "AND" else " || "
        combined = operator.join(checks)

        return f'''bash -c '
        for f in "$@"; do
            if {combined} 2>/dev/null; then
                echo "$f: condition matched"
            fi
        done
    ' _ "${{FILES[@]}}"'''

    elif check_type == "file_exists":
        paths = check.get("paths", [])
        message = check.get("message", "Required files not found")
        path_list = " ".join(paths)

        return f'''bash -c '
            if ! ls {path_list} 2>/dev/null | head -1 | grep -q .; then
                echo "{message}"
            fi
        ' '''

    else:
        return f"# Unknown check type: {check_type}"


def generate_rule_sh(rule: Rule) -> str:
    """Generate bash code for a single rule's check."""
    if not rule.mechanical:
        return ""  # Skip non-mechanical rules

    func = "check" if rule.severity in ("NEVER", "MUST") else "warn"
    # Escape $ in title to prevent bash variable expansion
    escaped_title = rule.title.replace('$', '\\$')
    title = f"{rule.id}: {escaped_title}"

    # Handle api_files_only
    files_var = "${API_ENDPOINT_FILES[@]}" if rule.api_files_only else "${FILES[@]}"

    # Generate the check command
    cmd = generate_check_command(rule)

    # Adjust file variable if needed
    if rule.api_files_only and "${FILES[@]}" in cmd:
        cmd = cmd.replace("${FILES[@]}", "${API_ENDPOINT_FILES[@]}")

    # For api_files_only rules, wrap in a check for API files
    if rule.api_files_only:
        return f'''
# {rule.id}: {rule.title}
if [[ ${{#API_ENDPOINT_FILES[@]}} -gt 0 ]]; then
    {func} "{title}" \\
        {cmd}
else
    green "✅ {title} (skipped - no API endpoint files)"
    ((PASS++)) || true
fi
'''
    else:
        return f'''
# {rule.id}: {rule.title}
{func} "{title}" \\
    {cmd}
'''


def generate_info_section(spec: DomainSpec) -> str:
    """Generate the info/statistics section."""
    if not spec.info:
        return ""

    lines = ['\nprintf \'\\n%s\\n\' "## Info"\n']

    for info_id, info_config in spec.info.items():
        pattern = info_config.get("pattern", "")
        flags = info_config.get("flags", "-c")
        label = info_config.get("label", info_id)
        aggregate = info_config.get("aggregate", "count")

        if aggregate == "unique_count":
            lines.append(f'''
{info_id.upper()}=$( (grep -ohE "{pattern}" "${{FILES[@]}}" 2>/dev/null || true) | sort -u | wc -l | tr -d ' ')
printf 'ℹ️  {label}: %s\\n' "${info_id.upper()}"
''')
        elif aggregate == "file_count":
            lines.append(f'''
{info_id.upper()}=$( (grep {flags} "{pattern}" "${{FILES[@]}}" 2>/dev/null || true) | wc -l | tr -d ' ')
printf 'ℹ️  {label}: %s\\n' "${info_id.upper()}"
''')
        else:
            lines.append(f'''
{info_id.upper()}=$( (grep {flags} "{pattern}" "${{FILES[@]}}" 2>/dev/null || true) | awk -F: '{{s+=$NF}}END{{print s+0}}')
printf 'ℹ️  {label}: %s\\n' "${info_id.upper()}"
''')

    return "".join(lines)


def generate_sh_footer() -> str:
    """Generate the shell script footer with summary."""
    return '''
printf '\\n%s\\n' "═══════════════════════════════════════════"
printf '  PASS: %d  FAIL: %d  WARN: %d\\n' "$PASS" "$FAIL" "$WARN"
if [[ $FAIL -eq 0 ]]; then
    green "  RESULT: PASS"
else
    red "  RESULT: FAIL"
fi
printf '%s\\n' "═══════════════════════════════════════════"

exit "$FAIL"
'''


def generate_sh(spec: DomainSpec) -> str:
    """Generate the complete shell script validator."""
    lines = []

    # Header
    lines.append(generate_sh_header(spec))

    # API file detection if configured
    if spec.api_file_detection:
        lines.append(generate_api_file_detection(spec))

    # Generate rules by severity section
    severity_sections = {
        "NEVER": "## NEVER Rules",
        "MUST": "## MUST Rules",
        "SHOULD": "## SHOULD Rules",
    }

    for severity in ["NEVER", "MUST", "SHOULD"]:
        rules = [r for r in spec.rules_by_severity(severity) if r.mechanical]
        if not rules:
            continue

        lines.append(f'\nprintf \'\\n%s\\n\' "{severity_sections[severity]}"\n')

        for rule in rules:
            rule_code = generate_rule_sh(rule)
            if rule_code:
                lines.append(rule_code)

    # Info section
    lines.append(generate_info_section(spec))

    # Footer
    lines.append(generate_sh_footer())

    return "".join(lines)


# =============================================================================
# JSON Generator (.rules.json for flight-lint)
# =============================================================================

# Direct mapping from domain name to language
DOMAIN_TO_LANGUAGE = {
    'javascript': 'javascript',
    'typescript': 'typescript',
    'python': 'python',
    'go': 'go',
    'rust': 'rust',
    'react': 'javascript',
    'nextjs': 'javascript',
}


def infer_language_from_domain(domain_name: str, file_patterns: list) -> str:
    """Infer language from domain name or file patterns.

    Returns the programming language for the domain, or 'unknown' if
    it cannot be determined.
    """
    if domain_name in DOMAIN_TO_LANGUAGE:
        return DOMAIN_TO_LANGUAGE[domain_name]

    # Infer from file patterns
    for pattern in file_patterns:
        if '.js' in pattern or '.mjs' in pattern or '.cjs' in pattern:
            return 'javascript'
        if '.ts' in pattern or '.tsx' in pattern:
            return 'typescript'
        if '.py' in pattern:
            return 'python'
        if '.go' in pattern:
            return 'go'
        if '.rs' in pattern:
            return 'rust'

    return 'unknown'


def convert_check_to_rule(rule: Rule) -> dict | None:
    """Convert a Rule with check config to a JSON rule entry.

    Returns None for non-mechanical rules or unknown check types.
    Only grep and presence checks are supported (Task 007 adds ast).
    """
    if not rule.mechanical:
        return None

    check = rule.check
    check_type = check.get('type', 'grep')

    # Only support grep/presence types for now
    if check_type not in ('grep', 'presence'):
        return None

    json_rule = {
        'id': rule.id,
        'title': rule.title,
        'severity': rule.severity,
        'type': 'grep',
        'pattern': check.get('pattern', ''),
        'query': None,
        'message': rule.description.strip() if rule.description else rule.title,
    }

    # Add rule-level provenance if present
    if rule.provenance:
        prov = {}
        if rule.provenance.last_verified:
            prov['last_verified'] = rule.provenance.last_verified
        if rule.provenance.confidence:
            prov['confidence'] = rule.provenance.confidence
        if rule.provenance.re_verify_after:
            prov['re_verify_after'] = rule.provenance.re_verify_after
        if prov:
            json_rule['provenance'] = prov

    return json_rule


def generate_rules_json(spec: DomainSpec) -> str:
    """Generate .rules.json content from a DomainSpec.

    Returns JSON string with proper formatting for flight-lint consumption.
    """
    rules_list = []
    for rule in spec.rules.values():
        json_rule = convert_check_to_rule(rule)
        if json_rule:
            rules_list.append(json_rule)

    # Sort rules by ID for consistent output (N1, N2, ..., S1, S2, ...)
    def sort_key(rule_entry: dict) -> tuple:
        rule_id = rule_entry['id']
        prefix = rule_id[0]
        numeric_part = rule_id[1:]
        return (prefix, int(numeric_part) if numeric_part.isdigit() else 0)

    rules_list.sort(key=sort_key)

    language = infer_language_from_domain(spec.domain, spec.file_patterns)

    rules_file = {
        'domain': spec.domain,
        'version': spec.version,
        'language': language,
        'file_patterns': spec.file_patterns,
    }

    if spec.exclude_patterns:
        rules_file['exclude_patterns'] = spec.exclude_patterns

    # Add domain-level provenance if present
    if spec.provenance:
        prov = {}
        if spec.provenance.last_full_audit:
            prov['last_full_audit'] = spec.provenance.last_full_audit
        if spec.provenance.audited_by:
            prov['audited_by'] = spec.provenance.audited_by
        if spec.provenance.next_audit_due:
            prov['next_audit_due'] = spec.provenance.next_audit_due
        if prov:
            rules_file['provenance'] = prov

    rules_file['rules'] = rules_list

    return json.dumps(rules_file, indent=2)


def validate_rules_json(json_content: str) -> bool:
    """Validate generated .rules.json against schema requirements.

    Returns True if valid, raises ValueError with details if invalid.
    """
    rules_data = json.loads(json_content)

    required_fields = ['domain', 'version', 'language', 'file_patterns', 'rules']
    for field_name in required_fields:
        if field_name not in rules_data:
            raise ValueError(f"Missing required field: {field_name}")

    rules_list = rules_data.get('rules', [])
    required_rule_fields = ['id', 'title', 'severity', 'type', 'message']

    for idx, rule_entry in enumerate(rules_list):
        for field_name in required_rule_fields:
            if field_name not in rule_entry:
                raise ValueError(
                    f"Rule {idx} (id={rule_entry.get('id', 'unknown')}) "
                    f"missing required field: {field_name}"
                )

    return True


def validate_yaml_syntax(flight_path: Path) -> bool:
    """Validate .flight file using yaml.validate.sh (dogfooding).

    Only fails on critical NEVER rules (N1: tabs, N2: duplicate keys) that would
    cause actual YAML parse errors. MUST/SHOULD rules are skipped because:
    - .flight files contain examples of bad patterns (that's their purpose)
    - Python's YAML parser handles type coercion differently

    Returns True if valid, False if critical errors found.
    """
    domains_dir = get_domains_dir()
    yaml_validator = domains_dir / "yaml.validate.sh"

    if not yaml_validator.exists():
        # yaml.validate.sh doesn't exist yet (bootstrapping)
        return True

    # Skip validation for yaml.flight itself - it contains intentional examples
    # of bad YAML patterns and would always fail
    if flight_path.name == "yaml.flight":
        return True

    try:
        result = subprocess.run(
            ["bash", str(yaml_validator), str(flight_path)],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            output = result.stdout + result.stderr
            # Only fail on critical NEVER rules that would break parsing:
            # N1 (tabs) and N2 (duplicate keys)
            # N3 (unsafe load) and N4 (YAML bomb) don't apply to .flight files
            critical_failures = []
            in_never_section = False
            for line in output.split("\n"):
                if "## NEVER Rules" in line:
                    in_never_section = True
                elif line.startswith("## "):
                    in_never_section = False
                elif in_never_section and "❌ N1:" in line:
                    critical_failures.append(("N1: Tab Characters", []))
                elif in_never_section and "❌ N2:" in line:
                    critical_failures.append(("N2: Duplicate Keys", []))

            if critical_failures:
                print(f"ERROR: {flight_path.name} has critical YAML errors:", file=sys.stderr)
                for rule, _ in critical_failures:
                    print(f"  {rule}", file=sys.stderr)
                return False
        return True
    except FileNotFoundError:
        # bash not found
        return True


def validate_regex_pattern(pattern: str, rule_id: str, domain: str) -> bool:
    """Validate a regex pattern using Python's re module.

    Returns True if valid, False if syntax errors found.

    Note: Python's re uses PCRE-style regex which is stricter than POSIX ERE
    (used by grep -E). This catches errors like unbalanced parentheses that
    BSD grep may not report.
    """
    try:
        re.compile(pattern)
        return True
    except re.error as e:
        print(f"ERROR: {domain}.flight: Rule {rule_id} has invalid regex pattern:", file=sys.stderr)
        print(f"  Pattern: {pattern}", file=sys.stderr)
        print(f"  Error: {e}", file=sys.stderr)
        return False


def validate_shell_script(sh_path: Path) -> bool:
    """Validate generated shell script using bash -n (syntax check).

    Returns True if valid, False if syntax errors found.
    """
    try:
        result = subprocess.run(
            ["bash", "-n", str(sh_path)],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"ERROR: Generated validator has syntax errors:", file=sys.stderr)
            if result.stderr:
                for line in result.stderr.strip().split("\n"):
                    print(f"  {line}", file=sys.stderr)
            return False
        return True
    except FileNotFoundError:
        print("WARNING: bash not found, skipping syntax validation", file=sys.stderr)
        return True  # Don't fail if bash isn't available


def load_flight_file(domain: str) -> dict:
    """Load and parse a .flight YAML file."""
    domains_dir = get_domains_dir()
    flight_file = domains_dir / f"{domain}.flight"

    if not flight_file.exists():
        print(f"ERROR: {flight_file} not found", file=sys.stderr)
        sys.exit(1)

    try:
        import yaml
    except ImportError:
        print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
        sys.exit(1)

    with open(flight_file) as f:
        return yaml.safe_load(f)


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Compile .flight files to .md and .validate.sh",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    flight-domain-compile api              # Compile api.flight
    flight-domain-compile --all            # Compile all .flight files
    flight-domain-compile --check api      # Dry-run, show changes
    flight-domain-compile --md-only api    # Generate .md only
    flight-domain-compile --sh-only api    # Generate .sh only
        """
    )

    parser.add_argument(
        "domain",
        nargs="?",
        help="Domain name (e.g., 'api' for api.flight)"
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Compile all .flight files in domains/"
    )

    parser.add_argument(
        "--check",
        action="store_true",
        help="Dry-run: show what would change"
    )

    parser.add_argument(
        "--md-only",
        action="store_true",
        help="Generate .md file only"
    )

    parser.add_argument(
        "--sh-only",
        action="store_true",
        help="Generate .sh file only"
    )

    parser.add_argument(
        "--json-only",
        action="store_true",
        help="Generate only .rules.json, skip .md and .sh generation"
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print parsed YAML structure"
    )

    return parser.parse_args()


def compile_domain(domain: str, args) -> int:
    """Compile a single domain. Returns 0 on success, 1 on error."""
    # Handle both "api" and ".flight/domains/api.flight" or "api.flight"
    domain_path = Path(domain)
    if domain_path.suffix == '.flight':
        domain = domain_path.stem

    # Validate YAML syntax before parsing (dogfooding)
    domains_dir = get_domains_dir()
    flight_path = domains_dir / f"{domain}.flight"
    if flight_path.exists() and not validate_yaml_syntax(flight_path):
        return 1

    data = load_flight_file(domain)

    if args.debug:
        import pprint
        pprint.pprint(data)
        return 0

    # Validate the YAML structure
    errors, warnings = validate_spec(data, domain)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    # Show warnings (don't fail, just inform)
    if warnings:
        for warning in warnings:
            print(f"WARNING: {warning}", file=sys.stderr)

    # Parse into structured object
    spec = parse_domain_spec(data)

    # Print summary
    print(f"Loaded {spec.domain}.flight v{spec.version}")
    print(f"  Description: {spec.description[:60]}...")
    print(f"  Rules: {len(spec.rules)} total")
    for severity in SEVERITIES:
        rules = spec.rules_by_severity(severity)
        mechanical = len([r for r in rules if r.mechanical])
        print(f"    {severity}: {len(rules)} ({mechanical} mechanical)")

    # Generate outputs
    domains_dir = get_domains_dir()

    # Generate .md (unless sh-only or json-only)
    if not args.sh_only and not args.json_only:
        md_content = generate_md(spec)
        md_path = domains_dir / f"{spec.domain}.md"

        if args.check:
            # Dry-run: compare with existing
            if md_path.exists():
                existing = md_path.read_text()
                if existing != md_content:
                    print(f"\n{md_path} would be updated")
                else:
                    print(f"\n{md_path} unchanged")
            else:
                print(f"\n{md_path} would be created")
        else:
            md_path.write_text(md_content, encoding='utf-8')
            print(f"\nWrote {md_path}")

    # Generate .validate.sh (unless md-only or json-only)
    if not args.md_only and not args.json_only:
        sh_content = generate_sh(spec)
        sh_path = domains_dir / f"{spec.domain}.validate.sh"

        if args.check:
            # Dry-run: compare with existing
            if sh_path.exists():
                existing = sh_path.read_text()
                if existing != sh_content:
                    print(f"{sh_path} would be updated")
                else:
                    print(f"{sh_path} unchanged")
            else:
                print(f"{sh_path} would be created")
        else:
            sh_path.write_text(sh_content, encoding='utf-8')
            sh_path.chmod(0o755)  # Make executable
            print(f"Wrote {sh_path}")

            # Validate generated shell script
            if not validate_shell_script(sh_path):
                return 1

    # Generate .rules.json (unless md-only or sh-only)
    if not args.md_only and not args.sh_only:
        json_content = generate_rules_json(spec)
        json_path = domains_dir / f"{spec.domain}.rules.json"

        if args.check:
            # Dry-run: compare with existing
            if json_path.exists():
                existing = json_path.read_text()
                if existing != json_content:
                    print(f"{json_path} would be updated")
                else:
                    print(f"{json_path} unchanged")
            else:
                print(f"{json_path} would be created")
        else:
            # Validate before writing
            try:
                validate_rules_json(json_content)
            except ValueError as validation_error:
                print(f"ERROR: Generated JSON is invalid: {validation_error}", file=sys.stderr)
                return 1

            json_path.write_text(json_content, encoding='utf-8')
            print(f"Wrote {json_path}")

    return 0


def main() -> int:
    """Main entry point."""
    args = parse_args()

    # Validate arguments
    if not args.domain and not args.all:
        print("ERROR: Specify a domain or use --all", file=sys.stderr)
        return 1

    if args.domain and args.all:
        print("ERROR: Cannot specify both domain and --all", file=sys.stderr)
        return 1

    mode_flags = sum([args.md_only, args.sh_only, args.json_only])
    if mode_flags > 1:
        print("ERROR: Cannot specify multiple --*-only flags", file=sys.stderr)
        return 1

    # Handle --all mode
    if args.all:
        domains_dir = get_domains_dir()
        flight_files = list(domains_dir.glob("*.flight"))

        if not flight_files:
            print(f"No .flight files found in {domains_dir}", file=sys.stderr)
            return 1

        errors = 0
        for flight_file in sorted(flight_files):
            domain = flight_file.stem
            print(f"\n{'='*50}")
            print(f"Compiling {domain}...")
            print(f"{'='*50}")
            result = compile_domain(domain, args)
            if result != 0:
                errors += 1

        print(f"\n{'='*50}")
        print(f"Compiled {len(flight_files)} domain(s), {errors} error(s)")
        print(f"{'='*50}")
        return 1 if errors > 0 else 0

    # Single domain mode
    return compile_domain(args.domain, args)


if __name__ == "__main__":
    sys.exit(main())
