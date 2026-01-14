# Flight Audit Tool Research

Research for building `/flight-audit` tool.

---

## 1. Domain File Inventory

### .md and .validate.sh Pairs

| Domain | .md | .validate.sh | Notes |
|--------|-----|--------------|-------|
| api | ✅ 17.6KB | ✅ 14.8KB | Mature, well-tested |
| bash | ✅ 10.5KB | ✅ 7.3KB | |
| code-hygiene | ✅ 8.5KB | ✅ 7.5KB | Universal rules |
| embedded-c-p10 | ✅ 5.8KB | ✅ 2.7KB | Specialized |
| javascript | ✅ 4.2KB | ✅ 3.5KB | |
| nextjs | ✅ 10.8KB | ✅ 6.8KB | |
| python | ✅ 9.3KB | ✅ 6.5KB | |
| react | ✅ 9.8KB | ✅ 6.4KB | |
| rp2040-pico | ✅ 9.0KB | ✅ 8.7KB | Specialized |
| scaffold | ✅ 5.9KB | ❌ None | **No validator** |
| sms-twilio | ✅ 17.1KB | ✅ 12.5KB | |
| sql | ✅ 14.5KB | ✅ 7.7KB | |
| testing | ✅ 16.1KB | ✅ 5.8KB | |
| typescript | ✅ 9.3KB | ✅ 6.7KB | |
| webhooks | ✅ 23.6KB | ✅ 11.2KB | |

**Findings:**
- 15 domain .md files
- 14 domain .validate.sh files
- 1 domain missing validator: `scaffold.md`

---

## 2. Rule Section Structure (from api.md)

### Heading Format
```markdown
### NEVER (validator will reject)
### MUST (validator will reject)
### SHOULD (validator warns)
```

**Severity Mapping:**
- `NEVER` → `check()` in validator (fails validation)
- `MUST` → `check()` in validator (fails validation)
- `SHOULD` → `warn()` in validator (warns but passes)

---

## 3. Rule Numbering Format (from api.md)

```markdown
1. **Rule Title** - Brief description
   ```code
   // Example
   ```
```

Rules are numbered within each severity section:
- NEVER rules: 1-8
- MUST rules: 1-9
- SHOULD rules: 1-13+

---

## 4. Validator Check/Warn Patterns (from api.validate.sh)

```bash
# NEVER rules use check() - failures cause exit code > 0
check "N1: No verbs in URI paths" \
    bash -c '...'

check "N2: No 200 status with error responses" \
    bash -c '...'

# SHOULD rules use warn() - warnings don't fail
warn "N3: Potential exposed IDs in pagination (use opaque cursors)" \
    bash -c '...'

warn "M1: Use plural nouns for collections" \
    bash -c '...'

warn "M2: API versioning present" \
    bash -c '...'
```

**Naming Convention:**
- `N1`, `N2`, etc. = NEVER rules
- `M1`, `M2`, etc. = MUST rules
- `S1`, `S2`, etc. = SHOULD rules

---

## 5. Consistent Structure Across Domains

### react.md Structure
```markdown
# Domain: React

Production React patterns for functional components, hooks, and state management.

---

## Invariants

### NEVER

1. **Inline Objects in JSX Props** - Creates new reference every render
   ```jsx
   // BAD
   ...
   // GOOD
   ...
   ```
```

### typescript.md Structure
```markdown
# Domain: TypeScript

Type-safe TypeScript patterns that catch errors at compile time.

---

## Invariants

### NEVER

1. **Implicit `any`** - Enable `noImplicitAny` in tsconfig
   ```typescript
   // BAD - implicit any
   ...
   // GOOD - explicit types
   ...
   ```
```

**Consistent Elements:**
- `# Domain: {Name}` title
- One-line description
- `---` separator
- `## Invariants` section
- `### NEVER` / `### MUST` / `### SHOULD` subsections
- Numbered rules with `**Bold Title** - Description`
- Code blocks with BAD/GOOD examples

---

## 6. Key Insights for flight-audit

### What flight-audit Should Do

1. **Parse .md Files**
   - Extract rules from NEVER/MUST/SHOULD sections
   - Map rule numbers to validator check IDs (N1, M1, S1)

2. **Parse .validate.sh Files**
   - Extract check() and warn() calls
   - Map to rule IDs

3. **Cross-Reference**
   - Verify every .md rule has corresponding validator check
   - Verify every validator check has corresponding .md rule
   - Flag mismatches in severity (check vs warn)

4. **Report**
   - Coverage: % of rules with validators
   - Gaps: Rules missing validation
   - Orphans: Validator checks without .md rules
   - Severity mismatches

### Potential Issues to Detect

1. **Missing Validators**
   - scaffold.md has no validator

2. **Rule/Check Mismatch**
   - .md says NEVER but validator uses warn()
   - .md rule exists but no corresponding check

3. **Numbering Gaps**
   - N1, N2, N4 (missing N3)
   - Inconsistent numbering between .md and .validate.sh

4. **Orphaned Checks**
   - Validator has check not documented in .md

---

## 7. Recommended flight-audit Output Format

```
═══════════════════════════════════════════
  Flight Domain Audit: api
═══════════════════════════════════════════

## Coverage
- NEVER rules: 8/8 (100%)
- MUST rules: 7/9 (78%)
- SHOULD rules: 10/13 (77%)
- Overall: 25/30 (83%)

## Gaps (rules without validation)
- M4: Rate Limit Headers - no check found
- S7: Support Content Negotiation - no check found

## Orphans (checks without rules)
- (none)

## Severity Mismatches
- N3: Spec says NEVER, validator uses warn()

═══════════════════════════════════════════
  AUDIT COMPLETE: 1 issue found
═══════════════════════════════════════════
```

---

## 8. Next Steps

1. Write PRD using `/flight-prd`
2. Design parsing logic for .md files (regex for rule extraction)
3. Design parsing logic for .validate.sh (regex for check/warn extraction)
4. Build cross-reference engine
5. Create report generator
