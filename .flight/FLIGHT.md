# Flight Methodology

TDD-style prompt engineering for consistent AI code generation.

## Core Concept

**Invariants over guidelines.** Define what MUST and NEVER happen. Code that follows invariants is correct by definition.

## The PCTV Loop

```
Prime → Compile → [Execute] → Validate → Tighten
  ↑                                         │
  └─────────────────────────────────────────┘
```

1. **Prime**: Research context, load domains, gather constraints
2. **Compile**: Build atomic prompt with invariants → PROMPT.md
3. **Execute**: Ralph autonomous loop OR manual Claude Code
4. **Validate**: Check output against domain invariants
5. **Tighten**: If failures, strengthen rules and retry

## Domain Files

Domain files (`.flight/domains/*.md`) contain:

```markdown
# Domain: [Name]

## Invariants

### MUST
- Required behaviors that code MUST exhibit
- Patterns that MUST be followed

### NEVER  
- Forbidden patterns
- Anti-patterns to avoid

## Patterns

[Code examples satisfying invariants]

## Edge Cases

[Specific scenarios with required handling]
```

## Key Principles

### 1. Invariants Are Binary
Code either follows an invariant or violates it. No "partial compliance."

### 2. Domains Are Authoritative
If a domain file covers a topic, it's the source of truth. Don't search externally for covered topics.

### 3. Atomic Prompts
Each compiled prompt has one clear objective. Complex features = multiple compile cycles.

### 4. Tightening Is Learning
Every validation failure that leads to tightening makes the system more reliable.

### 5. Examples Over Explanations
Show correct code patterns, not lengthy descriptions.

## Integration with Ralph

Flight handles **what** Claude generates (quality).
Ralph handles **how** Claude runs (execution).

```
Flight: /flight-prime → /flight-compile → PROMPT.md
Ralph:  ralph --monitor reads PROMPT.md, loops until done
Flight: /flight-validate checks result
```

## Quick Reference

| Phase | Command | Output |
|-------|---------|--------|
| Prime | `/flight-prime [task]` | Prime Document |
| Compile | `/flight-compile` | PROMPT.md |
| Execute | `ralph --monitor` | Generated code |
| Validate | `/flight-validate` | Pass/Fail report |
| Tighten | `/flight-tighten` | Updated domains |
