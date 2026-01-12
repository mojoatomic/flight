# CLAUDE.md

## About This File

**Flight** (code quality tooling) is installed in this project. This file describes the project itself.

If you see placeholders below, ask the user what they're building.
Use Flight commands to ensure quality. For Flight reference: `.flight/FLIGHT.md`

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

## Flight Quick Start

```bash
/flight-prime "your task"    # Research and gather context
/flight-compile              # Create atomic prompt
# [implement]
/flight-validate             # Check against domain rules
```

**Before generating code:**
1. Load `code-hygiene.md` - Always applies
2. Load task-specific domains - e.g., `react.md`, `python.md`
3. Follow invariants - If code follows them, it's correct

Full reference: `.flight/FLIGHT.md`
