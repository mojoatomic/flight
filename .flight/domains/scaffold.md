# Scaffold Domain

> Safe project scaffolding operations that preserve existing infrastructure

## Overview

This domain governs the use of scaffolding tools (create-vite, create-react-app, create-next-app, etc.) to prevent destructive overwrites of project infrastructure.

## Rules

### SCF-001: Never Use Destructive Flags
**NEVER** use `--overwrite`, `--force`, or similar flags that delete existing directories.

```bash
# FORBIDDEN
npx create-vite . --overwrite
npx create-vite my-app --force
npm init vite@latest . -- --overwrite

# ALLOWED
npx create-vite my-app
npm init vite@latest my-app
```

### SCF-002: Protected Directories
The following directories MUST be preserved during any scaffold operation:

- `.flight/` - Flight methodology infrastructure
- `tasks/` - Task definitions
- `.git/` - Version control
- `docs/` - Documentation
- `scripts/` - Project scripts

### SCF-003: Scaffold in Temp Directory
When adding a scaffold to an existing project, use a temp directory and merge:

```bash
# Step 1: Scaffold to temp location
npx create-vite temp-scaffold

# Step 2: Copy needed files (don't overwrite existing)
cp -n temp-scaffold/vite.config.ts .
cp -n temp-scaffold/tsconfig.json .
cp -rn temp-scaffold/src/* src/

# Step 3: Merge package.json dependencies manually or with jq
# Step 4: Clean up
rm -rf temp-scaffold
```

### SCF-004: Backup Before Scaffold
If scaffold MUST run in project root, backup first:

```bash
# Backup protected directories
cp -r .flight .flight.bak
cp -r tasks tasks.bak

# Run scaffold
npx create-vite . --template react-ts

# Restore protected directories
rm -rf .flight && mv .flight.bak .flight
rm -rf tasks && mv tasks.bak tasks
```

### SCF-005: Verify After Scaffold
After any scaffold operation, verify protected directories exist:

```bash
# Verification checklist
[ -d ".flight" ] && echo "✓ .flight intact" || echo "✗ .flight MISSING"
[ -d "tasks" ] && echo "✓ tasks intact" || echo "✗ tasks MISSING"
[ -d ".git" ] && echo "✓ .git intact" || echo "✗ .git MISSING"
```

### SCF-006: Package.json Merge Strategy
Never let scaffold overwrite package.json. Merge dependencies:

```bash
# Save existing
cp package.json package.json.existing

# After scaffold, merge dependencies
jq -s '.[0] * .[1] | .dependencies = (.[0].dependencies + .[1].dependencies) | .devDependencies = (.[0].devDependencies + .[1].devDependencies)' \
  package.json.existing package.json > package.json.merged

mv package.json.merged package.json
rm package.json.existing
```

### SCF-007: Git Commit Before Scaffold
Always commit or stash before scaffolding:

```bash
# Ensure clean state
git status --porcelain | grep -q . && echo "STOP: Uncommitted changes" && exit 1

# Or stash
git stash push -m "pre-scaffold backup"
```

### SCF-008: Document Scaffold Source
When scaffolding, document the source in project README or CHANGELOG:

```markdown
## Project Bootstrap
- Scaffolded with: `npx create-vite@5.4.0 --template react-ts`
- Date: 2026-01-13
- Modified: Added Flight methodology, custom domains
```

## Validation Checks

| ID | Check | Severity |
|----|-------|----------|
| SCF-001 | No `--overwrite` or `--force` in command history | FAIL |
| SCF-002 | Protected directories exist | FAIL |
| SCF-005 | Post-scaffold verification performed | WARN |
| SCF-007 | Git clean before scaffold | WARN |

## Domain-Specific Scaffold Commands

Cross-reference these with their respective domain files for full rules.

### React (see react.md)
```bash
# Vite (preferred)
npx create-vite my-app --template react-ts

# Create React App (legacy)
npx create-react-app my-app --template typescript
```
- Must follow react.md component patterns after scaffold
- Verify tsconfig.json strict mode per typescript.md

### Next.js (see nextjs.md)
```bash
npx create-next-app my-app --typescript --tailwind --app --eslint
```
- App router vs pages router - decide before scaffolding
- Follow nextjs.md for API routes, server components

### Python (see python.md)
```bash
# Poetry (preferred)
poetry new my-project
poetry init  # in existing directory

# Cookiecutter
cookiecutter gh:audreyfeldroy/cookiecutter-pypackage

# Basic
python -m venv venv && pip init
```
- Follow python.md for project structure
- Preserve `pyproject.toml` if exists

### JavaScript/TypeScript (see javascript.md, typescript.md)
```bash
# Node project
npm init -y
npx tsc --init

# Bun
bun init
```
- Merge tsconfig.json, don't overwrite
- Follow typescript.md strict settings

### API Services (see api.md)
```bash
# Express
npx express-generator my-api

# Fastify
npx fastify-cli generate my-api

# Hono
npm create hono@latest my-api
```
- Follow api.md for endpoint patterns
- Webhook scaffolds must follow webhooks.md

### SMS/Twilio (see sms-twilio.md)
```bash
# Twilio Functions
twilio serverless:init my-project
```
- Follow sms-twilio.md for consent handling
- Never scaffold with hardcoded credentials

### Embedded (see rp2040-pico.md, embedded-c-p10.md)
```bash
# Pico SDK project
cp -r $PICO_SDK_PATH/external/pico_sdk_import.cmake .
mkdir build && cd build && cmake ..

# PlatformIO
pio project init --board pico
```
- SDK paths must be environment variables
- Follow embedded-c-p10.md for CMake patterns

### Testing (see testing.md)
```bash
# Jest
npx jest --init

# Vitest (for Vite projects)
npm install -D vitest

# Pytest
pip install pytest && touch pytest.ini
```
- Test scaffolds must not overwrite existing test config
- Follow testing.md for coverage thresholds

### Bash Scripts (see bash.md)
All scaffold backup/restore scripts in this document must follow bash.md:
- Use `set -euo pipefail`
- Quote all variables
- Check exit codes

## Recovery

If protected directories were deleted:

1. Check git: `git checkout HEAD -- .flight/ tasks/`
2. Check backups: `ls *.bak`
3. Restore from Flight template repo
4. Rebuild tasks from PRD if needed
