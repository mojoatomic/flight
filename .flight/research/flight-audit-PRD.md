# PRD: flight-audit

## Problem Statement

Flight domain specs (`.md` files) define rules. Validators (`.validate.sh` files) implement them. These can drift apart over time:

- Rules in spec not implemented in validator (gaps)
- Checks in validator not documented in spec (orphans)
- Severity mismatches (spec says NEVER, validator uses `warn`)
- Missing validators entirely (scaffold.md has no validator)

Currently, the only way to detect drift is manual review. This is error-prone and time-consuming, especially as the number of domains grows (currently 15 domains, 14 with validators).

## Target Users

- **Primary**: Developers maintaining Flight domains
- **Secondary**: CI pipelines validating domain integrity

## Core Value Proposition

Automated, mechanical verification that domain specs and validators are in sync.

## Success Metrics

| Metric | Target |
|--------|--------|
| Detection accuracy | 100% (no false negatives) |
| Runtime | <5 seconds for all domains |
| CI integration | Exit code reflects issue count |

## Technical Constraints

- **Stack**: Bash only (matches existing Flight tooling)
- **Dependencies**: grep, sed, awk (standard Unix tools)
- **Location**: `.flight/flight-audit.sh`
- **Exit codes**: 0 = all sync, N = number of issues

## Research Findings (from flight-audit-research.md)

### Domain Structure

All domain `.md` files follow consistent structure:
```markdown
# Domain: {Name}
## Invariants
### NEVER (validator will reject)
1. **Rule Title** - Description
### MUST (validator will reject)
1. **Rule Title** - Description
### SHOULD (validator warns)
1. **Rule Title** - Description
```

### Validator Structure

All `.validate.sh` files use consistent patterns:
```bash
check "N1: Rule title" \    # NEVER/MUST - fails build
    command

warn "M1: Rule title" \     # SHOULD - warns only
    command
```

### ID Convention

- `N1`, `N2`... = NEVER rules
- `M1`, `M2`... = MUST rules
- `S1`, `S2`... = SHOULD rules

### Edge Cases

1. **"not mechanically validated" annotation** → Skip, don't flag as gap
2. **Validators with "skipped" output** → OK, not an orphan
3. **Missing `.validate.sh` entirely** → Report as "NO VALIDATOR"
4. **Sub-IDs like `M4a`** → Treat as separate rule

## Out of Scope (V1)

- Auto-fixing mismatches
- Generating missing validators
- Checking rule implementation quality
- Cross-domain rule analysis

## Research Sources

- `.flight/research/flight-audit-research.md` - File inventory, structure analysis
- `.flight/domains/api.md` - Reference spec structure
- `.flight/domains/api.validate.sh` - Reference validator structure
