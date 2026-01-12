# Flight v2

**TDD-style prompt engineering meets context engineering.**

A methodology for producing consistent, predictable LLM output through invariant-based prompts, validation loops, and example-driven context.

---

## The Synthesis

**From Flight v1:**
- Invariants over guidelines
- Allowed lists over forbidden lists
- Atomic, self-contained prompts
- Pass/fail before implementation
- Cross-model consistency

**From Context Engineering (Cole Medin):**
- PIV Loop (Prime → Implement → Validate)
- Examples folder for pattern matching
- Auto-generated validation commands
- Slash command integration
- Progressive success (simple → validate → enhance)

**The result:** Prompts that are both *well-researched* AND *tightly constrained*.

---

## Core Loop: PCTV

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│    ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│    │  PRIME  │ ──► │ COMPILE │ ──► │   TEST  │ ──► │VALIDATE │
│    └─────────┘     └─────────┘     └─────────┘     └─────────┘
│         │                                               │
│         │                                               │
│         └───────────────────────────────────────────────┘
│                         Tighten & Retry
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Prime
Load context, research facts, understand the codebase.
- Scan existing patterns
- Fetch external docs
- Identify constraints from project

### Compile  
Assemble atomic prompt with invariants.
- Pull from domain files
- Match examples
- Define pass/fail criteria
- Inline everything

### Test
Execute the prompt, evaluate output.
- Run generated code
- Check against invariants
- Binary: pass or fail

### Validate
If pass → ship. If fail → analyze and tighten.
- Ask LLM why it failed
- Convert soft constraints to hard invariants
- Update domain files
- Re-compile and retry

---

## Directory Structure

```
project/
├── .flight/
│   ├── domains/               # Invariants by language/framework
│   │   ├── javascript.md
│   │   ├── python.md
│   │   ├── api.md
│   │   └── database.md
│   │
│   ├── examples/              # Concrete code to pattern-match
│   │   ├── api-endpoint.js
│   │   ├── migration.sql
│   │   └── component.tsx
│   │
│   ├── templates/             # Prompt skeletons by task type
│   │   ├── api-endpoint.md
│   │   ├── migration.md
│   │   └── component.md
│   │
│   └── commands/              # CLI slash commands
│       ├── prime.md
│       ├── compile.md
│       ├── validate.md
│       └── tighten.md
│
├── .claude/
│   └── commands/              # Symlink or copy for Claude Code
│       └── (flight commands)
│
└── FLIGHT.md                  # Project-specific overrides
```

---

## Slash Commands

### /flight:prime

**Purpose:** Load context, research facts, understand the task.

```markdown
# Prime: [Task Name]

## Inputs
- Task description or GitHub issue
- Relevant file paths (optional)

## Process
1. Read FLIGHT.md for project-specific rules
2. Scan codebase for related patterns:
   - Similar files/functions
   - Existing conventions
   - Database schema (if relevant)
3. Fetch external docs (if needed):
   - API documentation
   - Library usage
4. Identify constraints:
   - What exists that must be preserved
   - What patterns must be followed
   - What's forbidden in this project

## Output
A "Prime Document" containing:
- Task summary
- Relevant files and line numbers
- Existing patterns to follow
- External API details
- Constraints discovered
```

### /flight:compile

**Purpose:** Generate an atomic Flight prompt from primed context.

```markdown
# Compile: [Task Name]

## Inputs
- Prime document (from /flight:prime)
- Domain files to include
- Template to use (optional)

## Process
1. Select relevant domain files
2. Extract only applicable sections
3. Match examples from /examples
4. Define pass/fail criteria:
   - What must be present
   - What must be absent
   - Exact shapes required
5. Assemble atomic prompt:
   - Task
   - Context (inlined)
   - Contract (exact shapes)
   - Invariants (allowed/forbidden)
   - Code style (from domain)
   - Self-check

## Output
A complete Flight prompt ready for execution.
No links. No references. Everything inline.
```

### /flight:validate

**Purpose:** Run validation against output.

```markdown
# Validate: [Task Name]

## Inputs
- Generated code/output
- Pass/fail criteria from prompt

## Process
1. Static checks:
   - Lint (eslint, ruff, etc.)
   - Type check (tsc, mypy, etc.)
   - Format check (prettier, black, etc.)
2. Invariant checks:
   - Response shapes match exactly
   - No forbidden patterns present
   - All required patterns present
3. Functional checks:
   - Unit tests pass
   - Integration tests pass
   - Manual smoke test (if needed)
4. E2E validation:
   - Test actual user workflow
   - Not just internal APIs

## Output
- PASS: All checks green → ship it
- FAIL: List of violations → tighten
```

### /flight:tighten

**Purpose:** Analyze failure and strengthen constraints.

```markdown
# Tighten: [Task Name]

## Inputs
- Failed output
- Original prompt
- Specific violations

## Process
1. Ask: "Why did the model produce this?"
   - Constraint too vague?
   - Conflicting instructions?
   - Training prior override?
2. Identify the fix:
   - Convert guideline → invariant
   - Add to allowed/forbidden list
   - Show in example
3. Update domain files (if pattern is reusable)
4. Re-compile prompt with fix
5. Retry

## Output
- Updated prompt
- (Optional) Updated domain file
- Explanation of what was tightened
```

---

## Domain Files

Domain files contain **invariants**, not guidelines.

### Structure

```markdown
# Flight Domain: [Language/Framework]

## Formatting (Invariants)
| Rule | Value |
|------|-------|
| Indentation | 2 spaces |
| ... | ... |

## Naming (Invariants)
| Context | Convention | Example |
|---------|------------|---------|
| Files | kebab-case | `user-service.js` |
| ... | ... | ... |

## Patterns (Invariants)

### Response Pattern
Every response must use exactly:
```code
return res.status(<code>).json(<object>);
```
[Explain the invariant clearly]

## Allowed (Explicit List)
- [thing 1]
- [thing 2]
- Nothing else

## Forbidden (Explicit List)
- [thing 1]
- [thing 2]

## Examples
See: `.flight/examples/[relevant-file]`
```

### Key Principles

1. **Invariants, not guidelines**
   - Bad: "Try to keep functions small"
   - Good: "Max 30 lines per function"

2. **Allowed lists close the space**
   - Bad: "Don't add unnecessary validation"
   - Good: "Only these 3 checks allowed: [list]"

3. **Show, don't tell**
   - Reference concrete examples
   - Patterns as literal code

4. **Mechanically checkable**
   - Can a linter verify this?
   - Can grep find violations?

---

## Examples Folder

The examples folder is **critical**.

LLMs pattern-match. Give them patterns.

### What to Include

```
.flight/examples/
├── api-endpoint.js        # Your style of endpoint
├── api-endpoint.test.js   # Your style of tests
├── migration.sql          # Your migration pattern
├── component.tsx          # Your component pattern
├── hook.ts                # Your hook pattern
└── README.md              # Index of examples
```

### How Examples Work

When compiling a prompt:

1. Identify task type (API endpoint, migration, component, etc.)
2. Find matching example
3. Include in prompt: "Follow this pattern exactly: [example]"

Examples are more powerful than descriptions. A 50-line example beats 500 words of explanation.

---

## Prompt Structure

Every compiled Flight prompt follows this structure:

```markdown
# Flight: [Task Name]

## Task
[One sentence]

## Output Rules (Hard)
[What to create, what not to create]

## Context
[Upstream APIs, dependencies, existing code - all inlined]

## Contract (Strict)
[Exact input/output shapes]

## Invariants

### Allowed
[Explicit list of what's permitted]

### Forbidden  
[Explicit list of what's banned]

## Code Style
[From domain file, relevant sections only]

## Pattern
[Example code to follow]

## Self-Check
[Verification steps before output]

## File Output
[Exact path(s)]
```

---

## The Tighten Loop

When output fails validation:

```
┌─────────────────────────────────────────────┐
│ 1. Identify the violation                   │
│    - What specifically failed?              │
│    - Which invariant was violated?          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 2. Ask the LLM why                          │
│    - "Why did you produce X?"               │
│    - "What was ambiguous about Y?"          │
│    - Get honest analysis                    │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 3. Strengthen the constraint                │
│    - Guideline → Invariant                  │
│    - Add to allowed/forbidden               │
│    - Add example                            │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 4. Update domain file (if reusable)         │
│    - Pattern applies to future tasks?       │
│    - Add to domain                          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 5. Re-compile and retry                     │
│    - Generate new prompt                    │
│    - Execute                                │
│    - Validate again                         │
└─────────────────────────────────────────────┘
```

**The goal:** Every failure makes the system smarter. Domain files accumulate hard-won knowledge.

---

## Cross-Model Consistency

Flight prompts should work across capable LLMs.

### The Dullard Test

Run every prompt on a weaker/faster model.

- If it passes → prompt is tight enough
- If it fails → prompt has soft constraints

### Why This Matters

- Not locked to one vendor
- Validates prompt quality
- Cheaper models for simple tasks

### How to Achieve It

1. Invariants, not guidelines (can't be interpreted)
2. Allowed lists (closes the space)
3. Self-check (model verifies itself)
4. Examples (pattern matching works everywhere)

---

## Progressive Success

Don't try to get it perfect on the first prompt.

```
Simple prompt → Validate → Tighten
     ↓              ↓          ↓
  Fast fail    Find holes   Close them
```

### The Progression

1. **v1:** Basic task + obvious constraints
2. **Run it:** See what breaks
3. **v2:** Add invariants for failures
4. **Run it:** See what else breaks
5. **v3:** Add allowed lists, examples
6. **Run it:** Usually converges here
7. **v4+:** Edge cases, cross-model testing

Each version gets tighter. Domain files capture the learnings.

---

## Integration with Claude Code

Flight commands live in `.claude/commands/` for native integration.

### Setup

```bash
# Create .claude/commands if it doesn't exist
mkdir -p .claude/commands

# Symlink or copy Flight commands
ln -s ../.flight/commands/prime.md .claude/commands/flight-prime.md
ln -s ../.flight/commands/compile.md .claude/commands/flight-compile.md
ln -s ../.flight/commands/validate.md .claude/commands/flight-validate.md
ln -s ../.flight/commands/tighten.md .claude/commands/flight-tighten.md
```

### Usage

```
/flight-prime "Add user authentication endpoint"
/flight-compile (uses prime output)
# Execute the compiled prompt
/flight-validate
# If failed:
/flight-tighten
```

---

## Quick Start

### 1. Initialize Flight

```bash
mkdir -p .flight/{domains,examples,templates,commands}
```

### 2. Create Your First Domain File

Start with your primary language. Copy from Flight's defaults, customize to your project.

### 3. Add Examples

Put 2-3 representative code files in `.flight/examples/`. These are your patterns.

### 4. Try the Loop

```
1. /flight:prime "your task"
2. /flight:compile
3. Execute the prompt
4. /flight:validate
5. If fail: /flight:tighten and retry
```

### 5. Capture Learnings

Every time you tighten, consider: should this go in a domain file?

---

## Philosophy

### Each to Their Gifts

- **Humans:** Define constraints, recognize pass/fail, know what they don't want
- **LLMs:** Execute within tight boundaries, pattern-match from examples

### Invariants Beat Intelligence

A dumb model following strict invariants outperforms a smart model following vague guidelines.

### Prompts Are Compiled, Not Written

You maintain domain files (source of truth). The system compiles task-specific prompts. Prompts are disposable. Domain files are permanent.

### Test Like Code

Prompts are testable artifacts. Run them. Evaluate. Refine. If it doesn't pass, it has a bug.

### Failures Make It Smarter

Every failure that gets tightened improves the domain files. The system learns from mistakes.

---

## Origin

Flight emerged from a collaboration between Doug (human) and Claude (LLM), later synthesized with Cole Medin's Context Engineering approach.

The core insight: **Prompts fail when they leave room for interpretation. Close that room with invariants, allowed lists, examples, and validation loops.**

---

*"Guessing is offensive."* — Applied to prompts.
