# Flight

**TDD-style prompt engineering for AI-assisted development.**

Flight is a methodology and toolset that reduces AI code generation mistakes by front-loading constraints. Instead of fixing AI mistakes after the fact, Flight ensures the rules are known before a single line is written.

---

## Why Flight Exists

AI code generation has a fundamental problem: **it often produces code that looks correct but violates project standards, framework conventions, and established engineering patterns.**

The traditional fix is linting and code review after generation. This fails because:

1. **Remediation is expensive** - Fixing generated code takes longer than writing it right
2. **Context is lost** - By the time you're fixing, Claude has forgotten why it wrote what it wrote
3. **Patterns repeat** - Claude makes the same mistakes across sessions
4. **Standards drift** - Each conversation starts from zero knowledge of your rules

Flight inverts this. **The rules come first. The code comes second.**

---

## Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  /flight-prd                                                                │
│  INPUT:  Rough idea ("document collection via SMS")                         │
│  OUTPUT: PRD.md + tasks/*.md                                                │
│  TOOLS:  Web Search, Firecrawl, Context7                                    │
│  USE:    Starting from scratch, need to understand problem space            │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  /flight-prime                                                              │
│  INPUT:  Task description, PRD.md, or tasks/001-*.md                        │
│  OUTPUT: PRIME.md                                                           │
│  TOOLS:  Domain Files, Codebase Scan, Web Search, Context7, Firecrawl       │
│  USE:    Have a clear task, need to gather implementation details           │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  /flight-compile                                                            │
│  INPUT:  PRIME.md                                                           │
│  OUTPUT: PROMPT.md                                                          │
│  TOOLS:  None - pure synthesis                                              │
│  USE:    After prime, before implementation                                 │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  EXECUTE                                                                    │
│  INPUT:  PROMPT.md                                                          │
│  OUTPUT: Code files                                                         │
│  HOW:    Claude implements following the compiled prompt                    │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  /flight-validate                                                           │
│  INPUT:  Generated code files                                               │
│  OUTPUT: PASS/FAIL with specific violations                                 │
│  TOOLS:  .validate.sh scripts (deterministic grep-based checks)             │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                         ┌─────────┴─────────┐
                         ▼                   ▼
                      PASS               FAIL
                        │                   │
                        ▼                   ▼
                      Done            /flight-tighten
                                           │
                                           ▼
                                  Loop back to /flight-compile
```

### Entry Points

| Starting Point | First Command |
|----------------|---------------|
| Vague idea ("build SMS thing") | `/flight-prd` |
| Clear task description | `/flight-prime` |
| PRD.md or tasks/*.md file | `/flight-prime` |
| Have domain.md, need validator | `/flight-create-validator` |
| Have code, need to check it | `/flight-validate` |

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/mojoatomic/flight/main/install.sh | bash
```

This creates:
```
your-project/
├── .flight/
│   ├── FLIGHT.md              # Core methodology
│   └── domains/               # Domain rules + validators
│       ├── bash.md / .validate.sh
│       ├── javascript.md / .validate.sh
│       ├── react.md / .validate.sh
│       └── ...
├── .claude/commands/          # Slash commands
│   ├── flight-prd.md
│   ├── flight-prime.md
│   ├── flight-compile.md
│   ├── flight-validate.md
│   ├── flight-tighten.md
│   └── flight-create-validator.md
└── CLAUDE.md                  # Project instructions
```

### Update

```bash
./update.sh
```

Or fetch the latest update script directly:
```bash
curl -fsSL https://raw.githubusercontent.com/mojoatomic/flight/main/update.sh | bash
```

Updates:
- `.claude/commands/*` (all slash commands)
- `.flight/FLIGHT.md` (core methodology)
- `.flight/validate-all.sh`
- `.flight/domains/*` (all stock domains)
- `.flight/examples/`, `exercises/`, `templates/`

Preserves:
- `CLAUDE.md` (your project description)
- `PROMPT.md`, `PRIME.md` (your working files)
- Custom domains (any `.md`/`.sh` not in Flight repo)

---

## Commands

### `/flight-prd <rough idea>`

**Purpose:** Transform a rough product idea into atomic tasks.

Claude Code excels at atomic, well-defined tasks. It struggles with large, multi-step projects. This command breaks big ideas into executable units.

**Output:**
- `PRD.md` - Product vision (human reference)
- `MILESTONES.md` - Phases with exit criteria
- `tasks/*.md` - Atomic task files (001-project-setup.md, 002-database-schema.md, etc.)

**Tools Used:**
- Web Search → Competitors, market research, recent articles
- Firecrawl → Deep crawl competitor sites, extract features
- Context7 → Current docs for considered tech stack

**Example:**
```
/flight-prd Simple document collection - user gets SMS link, uploads docs, stored encrypted
```

### `/flight-prime <task>`

**Purpose:** Gather all context needed to implement a task.

**Input:** Task description, PRD.md, or task file (tasks/001-*.md)

**Output:** `PRIME.md` with:
- Relevant domain constraints (NEVER/MUST/SHOULD)
- Existing patterns from codebase
- External API documentation
- Files to create/modify

**Tools Used:**
- Domain Files → Project constraints (always first)
- Codebase Scan → Existing patterns, configs
- Web Search → Current API docs, recent changes
- Context7 → Library/framework documentation
- Firecrawl → Deep dive specific doc sites

**Example:**
```
/flight-prime tasks/003-auth-basic.md
```

### `/flight-compile`

**Purpose:** Transform research into an atomic, executable prompt.

**Input:** `PRIME.md`

**Output:** `PROMPT.md` containing:
- Single, focused task
- Extracted NEVER/MUST constraints
- Acceptance criteria
- Definition of done

**Why atomic?** Large tasks fail. Small, well-specified tasks succeed.

### `/flight-validate [files]`

**Purpose:** Check generated code against domain rules.

Runs relevant `.validate.sh` scripts. Returns pass/fail with specific violations.

**Example:**
```
/flight-validate src/auth/*.ts

═══════════════════════════════════════════
  TypeScript Domain Validation
═══════════════════════════════════════════

## NEVER Rules
✅ N1: No explicit any without justification
✅ N2: No @ts-ignore without explanation

## MUST Rules
✅ M1: Explicit return types on exports

  RESULT: PASS
═══════════════════════════════════════════
```

### `/flight-tighten`

**Purpose:** Analyze validation failures and strengthen rules.

When validation fails, tighten examines why and suggests domain improvements to prevent recurrence. Then loop back to `/flight-compile`.

### `/flight-create-validator <domain.md>`

**Purpose:** Generate validator script and test files from a domain contract.

**Input:** Domain `.md` file

**Output:**
- `domain.validate.sh` - Executable validator matching NEVER/MUST/SHOULD rules
- `tests/domain.bad.ext` - Test file that must fail validation
- `tests/domain.good.ext` - Test file that must pass validation

**Example:**
```
/flight-create-validator .flight/domains/my-domain.md
```

---

## Research Tools

| Tool | What It Does | When to Use |
|------|--------------|-------------|
| Web Search | General search, news, articles | Competitors, market research, recent changes |
| Context7 | Library/framework docs (curated, versioned) | Getting current API docs for Next.js, React, Supabase, etc. |
| Firecrawl | Deep web scraping, crawl entire sites | Extracting features from competitor sites, scraping doc sites |
| Domain Files | Project-specific rules | Always - before any code generation |
| Codebase Scan | Find existing patterns | Understanding project conventions |

**MCP Tool Installation:**
- Context7: https://github.com/upstash/context7
- Firecrawl: https://github.com/mendableai/firecrawl

Commands work without MCP tools (using web search fallback) but produce better results with them.

---

## Domains

Domains are the heart of Flight. Each domain captures:
- **NEVER rules** - Hard constraints that fail validation
- **MUST rules** - Required patterns that fail validation
- **SHOULD rules** - Best practices that warn but don't fail
- **GUIDANCE** - Patterns too complex for grep, documented for Claude

### Code Hygiene (Always Loaded)

The `code-hygiene` domain applies to **all code in every language**. It catches AI-generated code smells that transcend syntax:

- **Generic variable names** - `data`, `result`, `temp`, `item`, `value`, `obj` → use descriptive names
- **Redundant conditionals** - `if (x) return true; else return false;` → `return x;`
- **Meaningless prefixes** - `myVar`, `theUser`, `aResult` → drop the noise
- **Magic number calculations** - `1024 * 1024` → `BYTES_PER_MB`
- **Boolean parameter blindness** - `process(true, false)` → use named options

This domain runs automatically on every validation. You don't need to explicitly load it.

### Available Domains

| Domain | Focus | Key Rules |
|--------|-------|-----------|
| `api` | REST/HTTP APIs | Resource URIs, status codes, versioning |
| `bash` | Shell scripts | Strict mode, quoting, error handling |
| `code-hygiene` | **Universal** | Naming, redundant logic, semantic clarity |
| `docker` | Container config | Multi-stage builds, non-root users, layer caching |
| `embedded-c-p10` | Safety-critical C | NASA Power of 10 rules |
| `go` | Go source files | Error handling, defer patterns, concurrency |
| `javascript` | JS files | No `var`, no `==`, no `console.log` |
| `kubernetes` | K8s manifests | Resource limits, probes, security contexts |
| `nextjs` | Next.js App Router | Server/client boundaries, loading states |
| `python` | Python files | No bare except, type hints, logging |
| `react` | React components | No inline objects in JSX, proper hooks |
| `rp2040-pico` | RP2040 embedded | Spinlocks, watchdog, static allocation |
| `rust` | Rust files | Error handling, unsafe blocks, ownership |
| `scaffold` | Project setup | create-vite, npm init patterns |
| `sms-twilio` | SMS/Twilio | Message validation, error handling, opt-out |
| `sql` | Database queries | No `SELECT *`, parameterized queries, RLS |
| `supabase` | Supabase (TS/Next.js) | @supabase/ssr, auth patterns, realtime cleanup |
| `testing` | Unit tests | Isolation, naming, assertion patterns |
| `typescript` | TypeScript files | No unjustified `any`, explicit returns |
| `webhooks` | Webhook handlers | Idempotency, signature verification, timeouts |
| `yaml` | YAML config | Quoting, anchors, multiline strings |

### Domain Contract

**The `.md` file is a contract. The `.validate.sh` file enforces it.**

Rules in NEVER/MUST sections **must** have corresponding validator checks. If a rule can't be mechanically checked, it belongs in GUIDANCE, not NEVER.

This keeps the contract honest. No aspirational rules that aren't enforced.

---

## Creating Custom Domains

Flight domains are defined in `.flight` YAML files and compiled to `.md` (documentation) + `.validate.sh` (executable validator). This single-source approach eliminates drift between specs and validators.

### Prerequisites

```bash
# One-time setup
python3 -m venv .venv
.venv/bin/pip install pyyaml
```

### Workflow

```
1. Create .flight/domains/my-domain.flight
2. Compile: .flight/bin/flight-domain-compile my-domain.flight
3. Test: .flight/validate-all.sh
```

### YAML Structure

```yaml
domain: my-domain
version: "1.0"
description: What this domain covers
file_patterns:
  - "**/*.ts"

rules:
  N1:
    title: Rule title
    severity: NEVER          # NEVER, MUST, SHOULD, or GUIDANCE
    mechanical: true         # Generate validator check
    description: Why this rule exists
    check:
      type: grep             # grep, script, presence, file_exists
      pattern: "bad-pattern"
    examples:
      bad:
        - "code that violates"
      good:
        - "code that passes"
```

### Commands

```bash
# Compile single domain
.flight/bin/flight-domain-compile my-domain.flight

# Compile all domains
.flight/bin/flight-domain-compile --all

# Syntax check only
.flight/bin/flight-domain-compile --check my-domain.flight
```

### Severity Levels

| Level | Validator | Blocks |
|-------|-----------|--------|
| NEVER | `check()` | Yes |
| MUST | `check()` | Yes |
| SHOULD | `warn()` | No |
| GUIDANCE | None | No |

See `.flight/FLIGHT.md` for complete YAML reference and check types.

---

## Philosophy

### Why Not Just ESLint/Prettier?

Linters catch syntax and style. Flight catches **semantic mistakes**:

- Standard linters typically won't flag `const data = fetchUser()` - it's valid JS
- Flight flags it because `data` is a meaningless name
- Standard linters typically won't flag `if (x) return true; else return false;`
- Flight flags it because it should be `return x;`

Linters and Flight are complementary. Linters handle formatting. Flight handles intent.

### Why Not Just Better Prompts?

Prompts decay over long conversations. Claude forgets instructions. Context windows fill up.

Flight commands **re-inject rules at decision points**. Every `/flight-prime` loads fresh domain knowledge. Every `/flight-validate` checks against ground truth.

### Why Shell Scripts for Validation?

- **Deterministic** - Same input, same output, every time
- **Fast** - Grep is faster than AST parsing for most checks
- **Transparent** - Read the script, understand the check
- **No dependencies** - Bash exists everywhere
- **Composable** - Chain validators, filter output, integrate with CI

### Core Principles

> If it follows the invariants, it's correct.

- Invariants beat intelligence
- Prompts are compiled, not written
- Validation is executable, not interpreted
- Failures strengthen the system

---

## Integration

### With CI/CD

```yaml
# .github/workflows/flight.yml
- name: Flight Validation
  run: |
    for validator in .flight/domains/*.validate.sh; do
      bash "$validator" "src/**/*.ts" || exit 1
    done
```

### With Pre-commit

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: flight-validate
      name: Flight Domain Validation
      entry: bash -c 'for v in .flight/domains/*.validate.sh; do bash "$v" || exit 1; done'
      language: system
```

### With Claude Code

Flight commands are automatically available in Claude Code when `.claude/commands/` exists in your project.

---

## FAQ

**Q: Does this replace code review?**

No. Flight catches mechanical violations. Humans catch architectural mistakes, business logic errors, and "this works but is the wrong approach."

**Q: What if a rule has false positives?**

Refine the grep pattern or move the rule to GUIDANCE. The validator should only fail on actual violations.

**Q: Can I disable rules?**

Yes. Remove them from the domain file, or add exclusion patterns to the validator.

**Q: How do I know which domains apply?**

`/flight-prime` auto-detects based on file extensions and framework markers. You can also specify explicitly.

---

## License

Apache 2.0
