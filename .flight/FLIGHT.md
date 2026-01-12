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
| Vague idea ("build SMS thing") | `/flight-prd` | Creates PRD.md + atomic task files |
| Clear task to implement | `/flight-prime` | Gathers context → PRIME.md |
| Have PRIME.md, ready to code | `/flight-compile` | Creates atomic PROMPT.md |
| Code written, need to check | `/flight-validate` | Runs validators → PASS/FAIL |
| Validation failed | `/flight-tighten` | Strengthens rules, retry |
| Have domain.md, need validator | `/flight-create-validator` | Generates .validate.sh + tests |

---

## The Loop

```
/flight-prd (if starting from scratch)
      ↓
/flight-prime <task>
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
| `.flight/domains/*.md` | Domain rules (read these!) |
| `.flight/domains/*.validate.sh` | Executable validators |
| `PRIME.md` | Output of /flight-prime |
| `PROMPT.md` | Output of /flight-compile (what to execute) |
| `PRD.md` | Output of /flight-prd (product vision) |
| `tasks/*.md` | Atomic task files from /flight-prd |

---

## Domain Quick Reference

| Domain | When to Load |
|--------|--------------|
| `code-hygiene` | **ALWAYS** - applies to all code |
| `testing` | Unit tests (any language) |
| `api` | REST/HTTP API routes, controllers |
| `bash` | Shell scripts (.sh) |
| `javascript` | .js files |
| `typescript` | .ts files |
| `react` | React components (.jsx, .tsx) |
| `nextjs` | Next.js projects |
| `python` | .py files |
| `sql` | Database queries, migrations |
| `embedded-c-p10` | Safety-critical C |
| `rp2040-pico` | RP2040 microcontroller |

---

## Critical Rules for AI

1. **Read domains BEFORE external research** - They're authoritative
2. **Always load code-hygiene.md** - It applies to everything
3. **One task per compile** - Atomic prompts succeed, big prompts fail
4. **NEVER/MUST rules are enforced** - Validator will catch violations
5. **Cite your sources** - Note where information came from in PRIME.md
6. **Don't skip validation** - Run `/flight-validate` after generating code

---

## Validation Output

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
| Validator false positive | Refine grep pattern or move rule to GUIDANCE |
| Missing domain | Create with `/flight-create-validator` |
| Task too big | Break into smaller atomic tasks |
| Context lost | Re-run `/flight-prime` |
| Rules unclear | Check domain file examples |
