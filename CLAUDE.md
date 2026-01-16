# CLAUDE.md

## About This File

**Flight** (code quality tooling) is installed in this project. This file describes the project itself.

If you see placeholders below, ask the user what they're building.

---

## MANDATORY: Before ANY /flight-* Command

**⚠️ READ `.flight/FLIGHT.md` FIRST.** It contains:
- Domain quick reference table (which .md files to load)
- Priority order: Domain files > Codebase > External docs
- Critical rules for AI

**Then scan available domains:**
```bash
ls .flight/domains/*.md
```

Domain files are authoritative. They override external documentation.

### Key Domains Quick Reference

| Domain | When It Applies |
|--------|-----------------|
| `code-hygiene.md` | ALWAYS - every task |
| `scaffold.md` | Project setup (create-vite, npm init, etc.) |
| `typescript.md` | Any .ts files |
| `react.md` | React components |
| `nextjs.md` | Next.js projects |
| `prisma.md` | Prisma ORM (multi-tenant SaaS) |
| `python.md` | Python code |

See `.flight/FLIGHT.md` for complete table.

---

## Project

<!-- USER: Describe your project here. What are you building? -->

[Project description goes here]

## Build Commands

<!-- USER: Add your build, test, lint commands -->

```bash
# npm run dev
# npm run build
# npm run test
```

## Flight Workflow

### Starting a New Project

```bash
/flight-prd "your idea"      # Creates PRD + tasks (includes temporal research)
/flight-prime tasks/001-*.md # Research and gather context
/flight-compile              # Create atomic prompt
# [implement]
npm run preflight            # Local CI (validate + lint)
/flight-validate             # Full Flight validation
```

### Existing Project / Clear Task

```bash
/flight-prime "your task"    # Research and gather context
/flight-compile              # Create atomic prompt
# [implement]
npm run preflight            # Local CI (validate + lint)
/flight-validate             # Full Flight validation
```

### Adding New Dependencies Mid-Project

```bash
/flight-research express@5 mongodb@7   # Validate versions, check for issues
```

### Before Generating Code

1. **Read `.flight/FLIGHT.md`** - Understand methodology
2. **Scan `.flight/domains/`** - Discover available constraints
3. **Load `code-hygiene.md`** - Always applies
4. **Load task-specific domains** - e.g., `react.md`, `scaffold.md`
5. **Follow MUST/NEVER rules** - They are non-negotiable

### Local CI

After Task 001 sets up `npm run preflight`, use it after every task:
- Runs `.flight/validate-all.sh` (Flight domain validation)
- Runs `npm run lint` (ESLint)

This catches issues before remote CI or code review.

---

Full reference: `.flight/FLIGHT.md`
