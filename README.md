# Flight

**TDD-style prompt engineering for AI-assisted development.**

Flight is a methodology and toolset that prevents bad code from being generated in the first place. Instead of fixing AI mistakes after the fact, Flight front-loads quality constraints so Claude knows the rules before writing a single line.

---

## Why Flight Exists

AI code generation has a fundamental problem: **Claude writes code that looks right but violates project standards, framework conventions, and hard-won engineering patterns.**

The traditional fix is linting and code review after generation. This fails because:

1. **Remediation is expensive** - Fixing generated code takes longer than writing it right
2. **Context is lost** - By the time you're fixing, Claude has forgotten why it wrote what it wrote
3. **Patterns repeat** - Claude makes the same mistakes across sessions
4. **Standards drift** - Each conversation starts from zero knowledge of your rules

Flight inverts this. **The rules come first. The code comes second.**

---

## Theory of Operation

Flight works like Test-Driven Development, but for prompts:

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLIGHT WORKFLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /flight-prime ──► /flight-compile ──► Execute ──► /flight-validate
│        │                  │                              │      │
│        ▼                  ▼                              ▼      │
│   Research &         Build atomic          Validate against     │
│   gather rules       PROMPT.md             domain rules         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### The Core Insight

> "The bugs aren't created because Claude knows the rules before writing."

Claude generates bad code because it doesn't know your rules. Flight solves this by:

1. **Injecting domain rules into context** before code generation
2. **Requiring research** so Claude understands current APIs, not training data
3. **Compiling atomic prompts** with explicit constraints and acceptance criteria
4. **Validating output** with deterministic shell scripts, not Claude's opinion

### Why This Works

**Prevention beats remediation.** ESLint catches bugs after they exist. Flight prevents them from being created.

**Ceremony forces compliance.** Each step makes Claude slow down and think. No more "sure, here's some code" that ignores your architecture.

**Rules are executable.** Domain validators are shell scripts. They return pass/fail. No ambiguity, no "I think this looks okay."

**Knowledge compounds.** Domains capture patterns once. Every future task benefits.

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
│   ├── flight-prime.md
│   ├── flight-compile.md
│   ├── flight-validate.md
│   └── flight-tighten.md
└── CLAUDE.md                  # Project instructions
```

### Update

```bash
curl -fsSL https://raw.githubusercontent.com/mojoatomic/flight/main/update.sh | bash
```

Updates core domains and commands while preserving your `CLAUDE.md`, `PROMPT.md`, and custom domains.

---

## Commands

### `/flight-prime <task>`

**Purpose:** Research and prepare for a task.

Gathers everything Claude needs to do the job right:
- Reads relevant domain files (`.flight/domains/*.md`)
- Uses web search for current documentation
- Uses Context7 MCP for library docs (if available)
- Uses Firecrawl MCP for deep site analysis (if available)
- Outputs `PRIME.md` with consolidated research

**Example:**
```
/flight-prime Add Clerk authentication to the Next.js app
```

### `/flight-compile`

**Purpose:** Transform research into an atomic, executable prompt.

Takes `PRIME.md` and produces `PROMPT.md` containing:
- Single, focused task
- Relevant constraints from domains
- Acceptance criteria
- What "done" looks like

**Why atomic?** Large tasks fail. Small, well-specified tasks succeed. Compile breaks work into executable units.

### `/flight-validate [files]`

**Purpose:** Check generated code against domain rules.

Runs all relevant `.validate.sh` scripts against the specified files. Returns pass/fail with specific violations.

**Example:**
```
/flight-validate src/auth/*.ts

═══════════════════════════════════════════
  TypeScript Domain Validation
═══════════════════════════════════════════

## NEVER Rules
✅ N1: No explicit any without justification
✅ N2: No @ts-ignore without explanation
✅ N3: No non-null assertions

## MUST Rules
✅ M1: Explicit return types on exports
✅ M2: Error handling with typed errors

  RESULT: PASS
═══════════════════════════════════════════
```

### `/flight-tighten`

**Purpose:** Analyze validation failures and strengthen rules.

When validation fails, tighten examines why and suggests domain improvements to prevent recurrence.

---

## Domains

Domains are the heart of Flight. Each domain captures:
- **NEVER rules** - Hard constraints that fail validation
- **MUST rules** - Required patterns that fail validation
- **SHOULD rules** - Best practices that warn but don't fail
- **GUIDANCE** - Patterns too complex for grep, documented for Claude
- **Patterns** - Copy-paste templates for common tasks

### Available Domains

| Domain | Focus | Key Rules |
|--------|-------|-----------|
| `bash` | Shell scripts | Strict mode, quoting, error handling |
| `code-hygiene` | Universal (always load) | Naming, redundant logic, semantic clarity |
| `javascript` | JS hygiene | No `var`, no `==`, no `console.log` |
| `typescript` | Type safety | No unjustified `any`, explicit returns |
| `react` | Component patterns | No inline objects in JSX, proper hooks |
| `nextjs` | App Router | Server/client boundaries, loading states |
| `python` | Python idioms | No bare except, type hints, logging |
| `sql` | Database access | No `SELECT *`, parameterized queries, RLS |
| `embedded-c-p10` | Safety-critical C | NASA Power of 10 rules |
| `rp2040-pico` | Embedded dual-core | Spinlocks, watchdog, static allocation |

### Domain Contract

**The `.md` file is a contract. The `.validate.sh` file enforces it.**

Rules in NEVER/MUST sections **must** have corresponding validator checks. If a rule can't be mechanically checked, it belongs in GUIDANCE, not NEVER.

This keeps the contract honest. No aspirational rules that aren't enforced.

---

## Creating Custom Domains

1. **Create the rules file:** `.flight/domains/your-domain.md`
   ```markdown
   # Domain: Your Domain

   ## Invariants

   ### NEVER (validator will reject)
   1. **Rule name** - Why it matters
      ```code
      # BAD
      bad_example()

      # GOOD
      good_example()
      ```

   ### MUST (validator will reject)
   ...

   ### SHOULD (validator warns)
   ...

   ### GUIDANCE (not mechanically checked)
   ...
   ```

2. **Create the validator:** `.flight/domains/your-domain.validate.sh`
   ```bash
   #!/bin/bash
   set -uo pipefail

   check() {
       local name="$1"; shift
       local result=$("$@" 2>/dev/null) || true
       if [[ -z "$result" ]]; then
           echo "✅ $name"; ((PASS++))
       else
           echo "❌ $name"; echo "$result" | head -5; ((FAIL++))
       fi
   }

   # N1: Check for violation
   check "N1: No bad pattern" grep -En 'bad_pattern' "$@"
   ```

3. **Test both directions:**
   - Bad code should fail
   - Good code should pass

---

## Philosophy

### Why Not Just ESLint/Prettier?

Linters catch syntax and style. Flight catches **semantic mistakes**:

- ESLint won't flag `const data = fetchUser()` - it's valid JS
- Flight flags it because `data` is a meaningless name
- ESLint won't flag `if (x) return true; else return false;`
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
