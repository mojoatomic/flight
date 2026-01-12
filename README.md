# Flight

TDD-style prompt engineering methodology for consistent AI code generation.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/mojoatomic/flight/main/install.sh | bash
```

## What Gets Installed

```
your-project/
├── .flight/
│   ├── FLIGHT.md                       # Core methodology
│   ├── domains/
│   │   ├── embedded-c-p10.md           # NASA JPL Power of 10 rules
│   │   ├── embedded-c-p10.validate.sh  # Executable validation
│   │   ├── javascript.md               # JS/Node invariants
│   │   ├── javascript.validate.sh      # Executable validation
│   │   ├── react.md                    # React invariants
│   │   └── rp2040-pico.md              # RP2040 dual-core patterns
│   ├── examples/
│   └── templates/
├── .claude/
│   └── commands/
│       ├── flight-prime.md
│       ├── flight-compile.md
│       ├── flight-validate.md
│       └── flight-tighten.md
├── CLAUDE.md
├── PROMPT.md
└── @fix_plan.md
```

## Usage

### Slash Commands

| Command | Purpose |
|---------|---------|
| `/flight-prime` | Research context, scan codebase, identify constraints |
| `/flight-compile` | Build atomic prompt from task + domain + examples |
| `/flight-validate` | Run domain validation scripts |
| `/flight-tighten` | Analyze failures, strengthen rules |

### Typical Workflow

```
> /flight-prime Build a P10-compliant ring buffer

[Claude reads domains, scans codebase, gathers context]

> /flight-compile

[Claude builds PROMPT.md with invariants]

> [Claude generates code]

> /flight-validate

[Runs validation script]

═══════════════════════════════════════════
  P10 Validation: src/ring_buffer.c
═══════════════════════════════════════════

## NEVER Rules
✅ N1: No goto
✅ N2: No setjmp/longjmp
✅ N3: No malloc/free

## MUST Rules
✅ M1: Compile -Wall -Wextra -Werror
✅ M2: Functions ≤60 lines
✅ M3: ≥2 asserts/function

  RESULT: PASS
═══════════════════════════════════════════
```

## Executable Domain Validation

Each domain includes:
- `*.md` — Constraints for code generation
- `*.validate.sh` — Executable checks returning PASS/FAIL

```bash
.flight/domains/embedded-c-p10.validate.sh src/*.c src/*.h
```

Validation is deterministic. The script decides correctness, not interpretation.

### Available Domains

| Domain | Validation Script |
|--------|-------------------|
| `embedded-c-p10` | ✅ |
| `javascript` | ✅ |
| `react` | — |
| `rp2040-pico` | — |

## Core Concepts

### Invariants vs Guidelines

- **Invariant**: Must pass or output is incorrect
- **Guideline**: Target, but not a failure condition

### The Loop

```
Prime → Compile → Execute → Validate
                              ↓
                    [PASS] → Done
                    [FAIL] → Tighten → Compile → ...
```

### Line Formulas

Calculable targets for component sizing:

| Component Type | Formula |
|----------------|---------|
| Stateful | `35 + (state × 3) + (handlers × 5)` |
| Form (reducer) | `90 + (fields × 20) + (rules × 3)` |
| List | `40 + (fields × 3) + (actions × 4)` |
| Modal | `45 + (sections × 8) + (actions × 5)` |

## With Ralph Loop

For autonomous execution:

```
/ralph-wiggum:ralph-loop "Implement P10-compliant state machine.
Follow .flight/domains/embedded-c-p10.md.
Run: .flight/domains/embedded-c-p10.validate.sh src/*.c
Output COMPLETE when validation passes." --max-iterations 20 --completion-promise "COMPLETE"
```

## Philosophy

> If it follows the invariants, it's correct.

- Invariants beat intelligence
- Prompts are compiled, not written
- Validation is executable, not interpreted
- Failures strengthen the system
