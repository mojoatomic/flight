# Task 007: CLI Integration & Exit Codes

## Depends On
- 001-script-skeleton
- 006-output-format

## Delivers
- Complete CLI integration tying all functions together
- `--all` mode that audits every domain in directory
- Exit code = total issue count (0 = pass)
- Summary output for multi-domain mode
- Make script executable

## NOT In Scope
- Individual parsing functions (Tasks 002-003)
- Detection logic (Tasks 004-005)
- Single-domain formatting (Task 006)

## Acceptance Criteria
- [ ] `flight-audit api` audits single domain, exits with issue count
- [ ] `flight-audit --all` audits all domains in .flight/domains/
- [ ] `flight-audit --dir /path/` audits all domains in custom directory
- [ ] Exit code 0 when all domains in sync
- [ ] Exit code N when N issues found (summed across all domains)
- [ ] Multi-domain mode shows summary at end
- [ ] Script is executable (`chmod +x`)
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- bash.md (shell script)

## Context

This task wires everything together:

**Single domain flow:**
```
flight-audit api
  → parse_spec api.md
  → parse_validator api.validate.sh
  → cross_reference
  → detect_severity_mismatches
  → print_report
  → exit $issue_count
```

**Multi-domain flow:**
```
flight-audit --all
  → for each .md file in directory:
      → audit single domain
      → accumulate issue count
  → print summary
  → exit $total_issues
```

Multi-domain summary format:
```
═══════════════════════════════════════════
  Flight Audit Summary
═══════════════════════════════════════════

Domains audited: 15
  ✅ In sync: 12
  ⚠️  With issues: 2
  ❌ No validator: 1

Total issues: 7
  Severity mismatches: 2
  Gaps: 4
  Orphans: 1

═══════════════════════════════════════════
  RESULT: 7 ISSUES FOUND
═══════════════════════════════════════════
```

## Technical Notes

Main function structure:
```bash
main() {
    local domains_dir=".flight/domains"
    local audit_all=false
    local total_issues=0

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) usage; exit 0 ;;
            --all) audit_all=true; shift ;;
            --dir) domains_dir="$2"; shift 2 ;;
            *) domain="$1"; shift ;;
        esac
    done

    if [[ "$audit_all" == true ]]; then
        # Audit all .md files
        for spec_file in "$domains_dir"/*.md; do
            domain="${spec_file##*/}"
            domain="${domain%.md}"
            issues=$(audit_domain "$domain" "$domains_dir")
            total_issues=$((total_issues + issues))
        done
        print_summary
    else
        # Audit single domain
        total_issues=$(audit_domain "$domain" "$domains_dir")
    fi

    exit "$total_issues"
}
```

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
chmod +x .flight/flight-audit.sh
.flight/flight-audit.sh --all  # Should run successfully
```
