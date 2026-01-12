# Flight v2

TDD-style prompt engineering methodology for consistent AI code generation.

## Quick Install

```bash
# From your project root
unzip flight-v2.zip
./flight-v2/install.sh
```

## What Gets Installed

```
your-project/
├── .flight/
│   ├── FLIGHT.md              # Core methodology
│   ├── domains/
│   │   ├── javascript.md      # JS/Node invariants
│   │   ├── react.md           # React invariants
│   │   └── react-line-formulas.md
│   ├── exercises/             # Training exercises
│   ├── examples/              # Reference code
│   └── templates/             # Prompt skeletons
├── .claude/
│   └── commands/
│       ├── flight-prime.md
│       ├── flight-compile.md
│       ├── flight-validate.md
│       └── flight-tighten.md
└── CLAUDE.md                  # Add Flight reference here
```

## Usage

### Slash Commands

| Command | Purpose |
|---------|---------|
| `/flight-prime` | Research context, scan codebase, identify constraints |
| `/flight-compile` | Build atomic prompt from task + domain + examples |
| `/flight-validate` | Check output against invariants |
| `/flight-tighten` | Analyze failures, strengthen rules |

### Typical Workflow

```
> /flight-prime Build a contact form with email validation

[Claude researches: React domain, form patterns, validation rules]

> /flight-compile

[Claude outputs atomic prompt with invariants]

> [Execute the prompt - Claude generates code]

> /flight-validate

[Claude checks: named exports ✓, useReducer ✓, handlers ✓...]

> /flight-tighten   # Only if validation fails

[Claude identifies root cause, updates domain file]
```

### CLAUDE.md Setup

Add to your project's `CLAUDE.md`:

```markdown
## Flight Methodology

Before any code generation task:
1. Read .flight/FLIGHT.md for methodology
2. Check .flight/domains/ for relevant invariants
3. Use line formulas from react-line-formulas.md for targets

Key principle: If it follows the invariants, it's correct.
```

## Core Concepts

### Invariants vs Guidelines

- **Invariant**: Must pass or output is wrong
- **Guideline**: Aim for, but don't fail if missed

### Line Formulas

Calculable targets instead of arbitrary limits:

| Component Type | Formula |
|----------------|---------|
| Stateful | `35 + (state × 3) + (handlers × 5)` |
| Form (reducer) | `90 + (fields × 20) + (rules × 3)` |
| List | `40 + (fields × 3) + (actions × 4)` |
| Modal | `45 + (sections × 8) + (actions × 5)` |

### The Loop

```
Prime → Compile → Execute → Validate
                              ↓
                    [Pass] → Done
                    [Fail] → Tighten → Compile → ...
```

## Training

Run exercises to calibrate the model:

```
.flight/exercises/react/
├── 01-counter.md        # Beginner
├── 02-user-card.md      # Intermediate  
├── 03-contact-form.md   # Advanced
├── 04-todo-list.md      # Intermediate
└── 05-confirm-modal.md  # Intermediate
```

Each exercise has:
- Requirements
- Line estimation formula
- Must-pass invariants
- Reference solution
- Common failures

## Philosophy

> "If it follows the rules and invariants, it's correct."

- Invariants beat intelligence
- Prompts are compiled, not written
- Test like code
- Failures make it smarter

---

Created by Doug + Claude, synthesized with Cole Medin's Context Engineering.
