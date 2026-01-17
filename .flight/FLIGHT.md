# Flight - AI Quick Reference

**Read this file first.** This tells you everything you need to work with Flight.

---

## What Flight Is

Flight is TDD for prompts. Rules come first, code comes second.

**Core principle:** If code follows the domain invariants, it's correct.

---

## Commands - What to Use When

| Situation | Command | What It Does |
|-----------|---------|--------------|
| Vague idea ("build SMS thing") | `/flight-prd` | Creates PRD.md + tasks (includes temporal research) |
| Clear task to implement | `/flight-prime` | Gathers context → PRIME.md |
| Have PRIME.md, ready to code | `/flight-compile` | Creates atomic PROMPT.md |
| Code written, need to check | `/flight-validate` | Runs validators → PASS/FAIL |
| Validation failed | `/flight-tighten` | Strengthens rules, retry |
| Have domain.md, need validator | `/flight-create-validator` | Generates .validate.sh + tests |
| Existing project, new deps | `/flight-research` | Validates versions, updates landmines |

---

## The Loop

```
/flight-prd (if starting from scratch)
      ↓
  [Temporal research runs automatically]
      ↓
  PRD.md + tasks/*.md + known-landmines.md
      ↓
/flight-prime tasks/001-*.md
      ↓
/flight-compile
      ↓
[Execute - write code following PROMPT.md]
      ↓
/flight-validate
      ↓
PASS → Done
FAIL → /flight-tighten → /flight-compile → repeat
```

**Note:** `/flight-prd` includes temporal research by default. Use `--no-research` to skip.

---

## Domain Files

Location: `.flight/domains/*.md`

**Always read these first.** Domains override external documentation.

### Structure

```markdown
# Domain: [Name]

## Invariants

### NEVER (validator will reject)
- Rules that cause hard failure
- Each has a corresponding check in .validate.sh

### MUST (validator will reject)
- Required patterns that cause hard failure
- Each has a corresponding check in .validate.sh

### SHOULD (validator warns)
- Best practices, warnings only
- Don't block validation

### GUIDANCE (not mechanically checked)
- Too complex for grep
- Human/AI judgment required

## Patterns
[Code examples that satisfy invariants]
```

### The Contract

**The `.md` file is the contract. The `.validate.sh` enforces it.**

If it's in NEVER/MUST, there's a validator check. If there's no check possible, it goes in GUIDANCE.

---

## Domain Compiler (flight-domain-compile)

The domain compiler generates both `.md` and `.validate.sh` from a single `.flight` YAML source file. This eliminates drift between specs and validators.

### Prerequisites

```bash
# Create virtual environment (one-time setup)
python3 -m venv .venv
.venv/bin/pip install pyyaml
```

The wrapper script auto-detects `.venv/` in project root or `.flight/.venv/`.

### Usage

```bash
# Compile a single domain
.flight/bin/flight-domain-compile api.flight

# Compile all .flight files in domains/
.flight/bin/flight-domain-compile --all

# Check syntax only (no output)
.flight/bin/flight-domain-compile --check api.flight

# Generate only .md or .sh
.flight/bin/flight-domain-compile --md-only api.flight
.flight/bin/flight-domain-compile --sh-only api.flight

# Debug mode (show parsed structure)
.flight/bin/flight-domain-compile --debug api.flight
```

### YAML Format

```yaml
domain: api
description: REST/HTTP API design patterns
default_patterns:
  - "**/routes*.{js,ts}"
  - "**/controller*.{js,ts}"
  - "**/api/**/*.{js,ts}"

rules:
  - id: N1
    severity: NEVER
    title: Verbs in URIs
    description: URIs identify resources, HTTP methods define actions
    mechanical: true          # Generate validator check
    api_files_only: false     # Apply to all matched files
    check_type: grep          # See check types below
    pattern: "['\"]/?)?(create|delete|remove|update|get|fetch|add|edit|modify)([A-Z]|[_-][a-z])"
    supports_ok_comment: true # Allow // flight:ok suppression
    examples:
      bad:
        - "POST /createUser"
        - "GET /getUsers"
      good:
        - "POST /users"
        - "GET /users"
```

### Severity Levels

| Level | Validator | Blocks Build |
|-------|-----------|--------------|
| NEVER | `check()` | Yes |
| MUST | `check()` | Yes |
| SHOULD | `warn()` | No (warning only) |
| GUIDANCE | None | No (not mechanical) |

### Check Types

**1. grep** - Pattern matching with optional flight:ok suppression
```yaml
check_type: grep
pattern: "after_id|before_id|since_id"
supports_ok_comment: true
```

**2. presence** - Check if pattern exists in codebase
```yaml
check_type: presence
pattern: "/v[0-9]+([/'\"?]|$)|version.*header"
presence_mode: require  # or "forbid"
error_message: "No API versioning detected"
```

**3. script** - Custom bash script
```yaml
check_type: script
script: |
  for f in "$@"; do
    if grep -qEi "status\\(201\\)" "$f"; then
      if ! grep -qEi "location.*header" "$f"; then
        echo "$f: 201 responses found but no Location header"
      fi
    fi
  done
```

**4. multi_condition** - Multiple conditions on same file
```yaml
check_type: multi_condition
conditions:
  - pattern: "origin.*\\*|Allow-Origin.*\\*"
    description: "wildcard origin"
  - pattern: "credentials.*true|withCredentials"
    description: "credentials enabled"
error_message: "{file}: CORS wildcard with credentials"
```

**5. file_exists** - Check for required files
```yaml
check_type: file_exists
files:
  - "openapi.yaml"
  - "openapi.json"
  - "swagger.yaml"
error_message: "No OpenAPI/Swagger spec found"
```

### Workflow

```
1. Create/edit .flight/domains/foo.flight
2. Run: .flight/bin/flight-domain-compile foo.flight
3. Outputs: foo.md + foo.validate.sh
4. Test: bash -n foo.validate.sh  # Syntax check
5. Run: .flight/validate-all.sh   # Full validation
```

### Key Flags

| Flag | Effect |
|------|--------|
| `mechanical: false` | Skip validator check (for GUIDANCE rules) |
| `api_files_only: true` | Only check API endpoint files |
| `supports_ok_comment: true` | Allow `// flight:ok` inline suppression |
| `presence_mode: require` | Fail if pattern NOT found |
| `presence_mode: forbid` | Fail if pattern IS found |

---

## Schema v2: Provenance

Schema v2 adds **provenance metadata** to track when rules were verified, their confidence level, and source documentation. This combats information rot - external APIs change, and domain files need to stay current.

### Why Provenance?

Domain files encode "truth" about external APIs. That truth has a shelf life:
- APIs deprecate methods
- Best practices evolve
- Security recommendations change

Provenance answers: "When was this rule last verified? Where did it come from? Is it still valid?"

### Domain-Level Provenance

Add a `provenance` block at the domain level to track overall audit status:

```yaml
schema_version: 2

provenance:
  last_full_audit: "2026-01-16"     # Date of comprehensive review
  audited_by: "flight-research"     # Who/what performed audit
  next_audit_due: "2026-07-16"      # When to re-audit

  sources_consulted:                # Documentation reviewed
    - url: "https://docs.example.com"
      accessed: "2026-01-16"
      note: "Official API documentation"

  coverage:                         # What's covered and what's not
    apis_covered:
      - "Authentication API"
      - "Error handling patterns"
    known_gaps:
      - "WebSocket patterns (not yet documented)"
```

### Rule-Level Provenance

Add `provenance` to individual rules to track verification:

```yaml
rules:
  N1:
    title: Example Rule
    severity: NEVER
    mechanical: true
    description: Example with provenance

    provenance:
      last_verified: "2026-01-16"   # When this rule was verified
      confidence: high              # high | medium | low
      re_verify_after: "2027-01-16" # Re-check after this date

      sources:                      # Where the rule came from
        - url: "https://rfc.example.com/spec"
          accessed: "2026-01-16"
          quote: "Implementations MUST NOT expose internal identifiers"

      # For deprecated patterns - what replaced them
      superseded_by:
        replacement: "newMethod()"
        version: "2.0.0"
        date: "2025-06-01"
        note: "oldMethod removed in v3.0"

    check:
      type: grep
      pattern: 'bad_pattern'
      flags: -En
```

### Confidence Levels

| Level | Meaning | Re-verify Interval |
|-------|---------|-------------------|
| `high` | Well-established, stable API | 12 months |
| `medium` | Generally reliable, may change | 6 months |
| `low` | Emerging pattern, needs validation | 3 months |

### Compiler Warnings

The compiler emits warnings (not errors) for provenance issues:

| Warning | Cause | Action |
|---------|-------|--------|
| `Rule X has no sources` | Mechanical rule without provenance sources | Add sources |
| `Rule X is stale` | Past `re_verify_after` date | Re-verify and update |
| `Rule X has low confidence` | `confidence: low` | Consider verification |
| `Domain audit overdue` | Past `next_audit_due` | Run `/flight-research` |

### Migration from v1 to v2

1. Add `schema_version: 2` after the version field
2. Add domain-level `provenance` block with audit dates and sources
3. Add rule-level `provenance` to mechanical rules (start with NEVER/MUST)
4. Compile to verify: `.flight/bin/flight-domain-compile your-domain`
5. Address any warnings

**Template:** See `.flight/templates/domain-schema-v2.flight` for a complete example.

---

## Research Tools

Use these during `/flight-prime` and `/flight-prd`:

| Tool | Use For |
|------|---------|
| Domain Files | Project constraints - **always read first** |
| Codebase Scan | Existing patterns, configs, conventions |
| Web Search | Current API docs, recent changes |
| Context7 (MCP) | Library/framework documentation |
| Firecrawl (MCP) | Deep crawl documentation sites |

**Priority:** Domain files > Codebase patterns > External docs

If MCP tools aren't available, fall back to web search.

---

## Key Files

| File | Purpose |
|------|---------|
| `.flight/domains/*.flight` | Domain source (YAML) - single source of truth |
| `.flight/domains/*.md` | Domain rules (generated from .flight) |
| `.flight/domains/*.validate.sh` | Executable validators (generated from .flight) |
| `.flight/bin/flight-domain-compile.py` | Domain compiler (generates .md + .sh) |
| `.flight/templates/domain-schema-v2.flight` | Schema v2 template with provenance |
| `.flight/validate-all.sh` | Auto-detect and run all relevant validators |
| `.flight/known-landmines.md` | Temporal issues discovered during research |
| `update.sh` | Update Flight (preserves customizations) |
| `PRIME.md` | Output of /flight-prime |
| `PROMPT.md` | Output of /flight-compile command (what to execute) |
| `PRD.md` | Output of /flight-prd (product vision) |
| `tasks/*.md` | Atomic task files from /flight-prd |

---

## Domain Quick Reference

| Domain | When to Load |
|--------|--------------|
| `code-hygiene` | **ALWAYS** - applies to all code |
| `clerk` | Clerk auth, organizations, multi-tenant SaaS (TypeScript/Next.js) |
| `prisma` | Prisma ORM, multi-tenant queries, error handling, connection management |
| `api` | REST/HTTP API routes, controllers |
| `bash` | Shell scripts (.sh) |
| `docker` | Dockerfiles, container configuration |
| `embedded-c-p10` | Safety-critical C (NASA Power of 10) |
| `go` | Go source files (.go) |
| `javascript` | .js files |
| `kubernetes` | Kubernetes YAML manifests |
| `nextjs` | Next.js projects |
| `python` | .py files |
| `react` | React components (.jsx, .tsx) |
| `rp2040-pico` | RP2040 microcontroller |
| `rust` | Rust source files (.rs) |
| `scaffold` | Project scaffolding (create-vite, etc.) |
| `sms-twilio` | SMS messaging, Twilio integration |
| `sql` | Database queries, migrations |
| `supabase` | Supabase client, auth, realtime (TypeScript/Next.js) |
| `testing` | Unit tests (any language) |
| `typescript` | .ts files |
| `webhooks` | Webhook handlers (provider/consumer) |
| `yaml` | YAML configuration files |

---

## Critical Rules for AI

1. **Read domains BEFORE external research** - They're authoritative
2. **Always load code-hygiene.md** - It applies to everything
3. **One task per compile** - Atomic prompts succeed, big prompts fail
4. **NEVER/MUST rules are enforced** - Validator will catch violations
5. **Cite your sources** - Note where information came from in PRIME.md
6. **Don't skip validation** - Run `/flight-validate` after generating code

---

## Project Setup (Local CI)

Set this up **before starting work** on a project. Flight validators act as local CI - catching issues before they hit remote CI or code review.

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/mojoatomic/flight/main/install.sh | bash
```

This automatically:
- Copies `.flight/`, `.claude/`, and `update.sh`
- Makes validators executable
- Adds `validate` and `preflight` scripts to package.json (if exists and jq installed)

To update Flight later: `./update.sh` (preserves your customizations)

### Manual Setup (if needed)

If package.json wasn't updated, add:

```json
{
  "scripts": {
    "validate": ".flight/validate-all.sh",
    "preflight": "npm run validate && npm run lint",
    "lint": "eslint ."
  }
}
```

### (Optional) Git pre-commit hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
npm run validate || exit 1
```

Or use with husky/lint-staged for staged files only.

### 4. CI Integration

Add to your CI pipeline (GitHub Actions example):

```yaml
- name: Flight Validation
  run: npm run validate
```

### Workflow

```
Write code → npm run preflight → Fix failures → Commit → Push
```

Run `npm run preflight` before every commit. If it passes locally, CI will pass.

---

## Validation Output

### Output Format

```
═══════════════════════════════════════════
  [Domain] Validation
═══════════════════════════════════════════

## NEVER Rules
✅ N1: Rule passed
❌ N2: Rule failed
   src/file.ts:42: violation details

## MUST Rules
✅ M1: Rule passed

## SHOULD Rules
⚠️  S1: Warning (doesn't fail)

  PASS: 5  FAIL: 1  WARN: 1
  RESULT: FAIL
═══════════════════════════════════════════
```

**FAIL means fix the code, then re-validate.**

---

## When Things Go Wrong

| Problem | Solution |
|---------|----------|
| Validator false positive | Edit `.flight` YAML, recompile with `flight-domain-compile` |
| Spec/validator drift | Use single `.flight` source, regenerate both files |
| Missing domain | Create `.flight` file, compile with `flight-domain-compile` |
| Task too big | Break into smaller atomic tasks |
| Context lost | Re-run `/flight-prime` |
| Rules unclear | Check domain file examples |
| Bash syntax errors | Run `bash -n file.validate.sh` to find issues |
