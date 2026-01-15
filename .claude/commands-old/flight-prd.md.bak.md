# /flight-prd - Product Requirements → Atomic Tasks

Transform a rough product idea into atomic tasks that Claude Code can actually execute.

## The Problem This Solves

Claude Code excels at **atomic, well-defined tasks** (1-2 hours). It struggles with:
- Large, interconnected systems
- Multi-day projects with many files
- Maintaining consistency across long sessions

A monolithic PRD like "Build an SMS document system" will fail. Claude will:
- Lose context
- Make inconsistent decisions
- Over-engineer
- Produce code that doesn't fit together

## The Solution: Atomic Task Decomposition

Instead of one big PRD, output a **task queue** that feeds the Flight loop:

```
/flight-prd "rough idea"
    ↓
PRD.md              # Vision (human reference)
MILESTONES.md       # Phases (human planning)
tasks/
  001-project-setup.md
  002-database-schema.md
  003-auth-system.md
  ...
    ↓
/flight-prime tasks/001-project-setup.md
    ↓
PROMPT.md
    ↓
[Claude executes atomic task]
    ↓
npm run preflight          # Local CI (validate + lint)
    ↓
/flight-validate           # Full Flight validation
    ↓
[Human reviews, approves]
    ↓
/flight-prime tasks/002-database-schema.md
    ↓
... loop continues
```

---

## Usage

```
/flight-prd <rough product idea>
```

## Example

```
/flight-prd Simple document collection - user gets SMS link, uploads docs, stored encrypted
```

---

## Process

### 0. Load Flight Context (MANDATORY - before any research)

**⚠️ CRITICAL: Do this FIRST, before any external research.**

Flight domain files contain project-specific rules that override external documentation. Missing them can result in destructive operations (e.g., scaffold.md prevents overwriting project infrastructure).

1. **Read `.flight/FLIGHT.md`** - understand methodology and domain quick reference table
2. **Scan available domains**:
   ```bash
   ls .flight/domains/*.md
   ```
3. **Match domains to planned tech stack**. For this PRD, identify which domains will apply:
   - `code-hygiene.md` - ALWAYS (every task)
   - `scaffold.md` - if project setup uses create-vite, create-next-app, npm init, etc.
   - `react.md` - if React components
   - `typescript.md` - if TypeScript
   - `nextjs.md` - if Next.js
   - `python.md` - if Python
   - etc.
4. **Read matched domain files** to understand constraints BEFORE external research

**Why this order matters:**
- Priority: Domain files > Codebase patterns > External docs
- Domain MUST/NEVER rules are non-negotiable
- External research may contradict domain rules; domains win

### 1. Understand the Request

Parse the rough idea into:
- **Core problem**: What pain point?
- **Target users**: Who needs this?
- **Key capabilities**: What must it do (high level)?

### 2. Research Phase

Use available tools to ground the PRD in reality:

#### Web Search
- Competitor solutions
- Problem space articles
- Technology options
- **Queries**: `"{problem} solutions"`, `"best {category} tools"`, `"{competitor} alternatives"`

#### MCP Tools (if available)
Check your tool list for:
- `context7_*` → Use for framework/library documentation
- `firecrawl_*` → Use for competitor deep-dives

**If tools are missing but would help:**
```
NOTE: Better results with [Context7/Firecrawl]. Install from:
- Context7: https://github.com/upstash/context7
- Firecrawl: https://github.com/mendableai/firecrawl

Proceed with available tools, or install first?
```

### 3. Competitive Analysis

| Competitor | What They Do Well | Where They Fall Short |
|------------|-------------------|----------------------|
| ... | ... | ... |

### 4. Generate Outputs

Create THREE outputs:

#### A. `PRD.md` - The Vision

```markdown
# PRD: [Product Name]

## Problem Statement
[Specific problem. Who has it. Why current solutions fail.]

## Target Users
- Primary: [specific persona]
- Secondary: [specific persona]

## Core Value Proposition
[One sentence: what makes this different]

## Success Metrics
- [Measurable metric]: [Target]

## Competitive Landscape
[Brief summary of research findings]

## Technical Constraints
- [Constraint]: [Reason]

## Out of Scope (V1)
- [What this is NOT building]

## Research Sources
- [URL]: [Key finding]
```

#### B. `MILESTONES.md` - The Phases

```markdown
# Milestones

## M1: Foundation (Tasks 001-003)
Project setup, database schema, basic auth.
**Exit Criteria**: Can log in and see empty dashboard.
**Validation**: `.flight/validate-all.sh` should pass after each task.

## M2: Core Feature (Tasks 004-007)
[The main thing the product does]
**Exit Criteria**: [Specific testable outcome]
**Validation**: `.flight/validate-all.sh` should pass after each task.

## M3: Polish (Tasks 008-010)
Error handling, edge cases, UX improvements.
**Exit Criteria**: Ready for beta users.
**Validation**: `.flight/validate-all.sh` should pass after each task.
```

#### C. `tasks/` - Atomic Task Files

Create 8-15 task files, each following this structure:

```markdown
# Task [NNN]: [Short Name]

## Depends On
- [Task numbers that must complete first]
- OR "None (first task)"

## Delivers
- [Specific, concrete output 1]
- [Specific, concrete output 2]
- [Specific, concrete output 3]

## NOT In Scope (Critical)
- [Thing that seems related but is a different task]
- [Thing user might expect but we're deferring]
- [Adjacent feature that's Task XXX]

## Acceptance Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] [Testable criterion 3]
- [ ] `.flight/validate-all.sh` passes (local CI)

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- [relevant-domain].md
- [relevant-domain].md

## Context
[Minimal context Claude needs for THIS task only.
Don't repeat the whole PRD. Just what's relevant.]

## Technical Notes
[Any specific technical decisions or patterns to follow.
Reference prior tasks if building on them.]

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
```

---

## Task Decomposition Rules

### Size Constraints
- **Maximum**: 2 hours of Claude work
- **Maximum files**: 5-7 files created/modified
- **If bigger**: Split into multiple tasks

### Dependency Rules
- Tasks should be **sequential** where possible
- Minimize parallel dependencies (harder to coordinate)
- Each task should work even if future tasks never happen

### Scope Rules
- **"NOT In Scope" is the most important section**
- Be explicit about what's adjacent but excluded
- Reference which task WILL handle deferred items

### Domain Constraints Discovery

For each task, the "Domain Constraints" section MUST:
1. Always include `code-hygiene.md`
2. Include domains matching the task's tech (from FLIGHT.md Domain Quick Reference table)
3. Include `scaffold.md` for ANY task that creates/initializes project structure
4. Be based on actual `.flight/domains/` contents, not assumptions

**Anti-pattern:** Guessing domains based on keywords
**Correct:** Reading FLIGHT.md table + scanning `.flight/domains/`

### Key Domain Mappings

| Task Type | Required Domains |
|-----------|------------------|
| Project setup (create-vite, npm init, etc.) | `code-hygiene.md`, `scaffold.md` |
| React components | `code-hygiene.md`, `react.md` |
| TypeScript files | `code-hygiene.md`, `typescript.md` |
| Next.js routes/pages | `code-hygiene.md`, `nextjs.md`, `react.md` |
| Database/SQL | `code-hygiene.md`, `sql.md` |
| API endpoints | `code-hygiene.md`, `api.md` (if exists) |
| Python code | `code-hygiene.md`, `python.md` |

Always verify against actual `.flight/domains/` contents.

### Flight Local CI Setup (Task 001 MUST include)

Every `001-project-setup` task MUST configure Flight as local CI:

1. **Use scaffolding tools with linting enabled**:
   ```bash
   # Next.js - include --eslint flag
   npx create-next-app my-app --typescript --tailwind --app --eslint

   # Vite - add ESLint after
   npm create vite@latest my-app -- --template react-ts
   npm install -D eslint @eslint/js typescript-eslint
   npx eslint --init
   ```

2. **Add scripts to package.json**:
   ```json
   {
     "scripts": {
       "lint": "eslint .",
       "validate": ".flight/validate-all.sh",
       "preflight": "npm run validate && npm run lint"
     }
   }
   ```
   Note: `lint` script may already exist from scaffolding. Verify it works.

3. **Include in acceptance criteria**:
   - `npm run lint` works (ESLint configured)
   - `package.json has validate and preflight scripts`
   - `npm run validate passes`
   - `npm run preflight passes`

This ensures both linting and Flight validation are available as local CI.

### Naming Convention
```
tasks/
  001-project-setup.md       # Always first
  002-database-schema.md     # Data layer early
  003-auth-basic.md          # Auth before features
  004-[core-feature-1].md
  005-[core-feature-2].md
  ...
  0XX-error-handling.md      # Polish later
  0XX-testing.md             # Near end
```

---

## Example Decomposition

**Input**: `/flight-prd Document collection via SMS - encrypted storage`

**Output**:

### tasks/001-project-setup.md
```markdown
# Task 001: Project Setup

## Depends On
- None (first task)

## Delivers
- Next.js 14 project with App Router (use --eslint flag)
- Supabase project connected
- Environment variables configured
- Basic layout component
- ESLint configured and working
- Flight local CI configured in package.json

## NOT In Scope
- Authentication (Task 003)
- Database tables (Task 002)
- Any business logic
- Styling beyond basic layout

## Acceptance Criteria
- [ ] `npm run dev` starts without errors
- [ ] `/` route renders "Hello World"
- [ ] `supabase status` shows connection
- [ ] .env.local has SUPABASE_URL and SUPABASE_ANON_KEY
- [ ] `npm run lint` works (ESLint configured)
- [ ] package.json has `validate` and `preflight` scripts
- [ ] `npm run validate` passes
- [ ] `npm run preflight` passes

## Domain Constraints
- code-hygiene.md (always)
- scaffold.md (project initialization)
- nextjs.md
- typescript.md

## Flight Setup (REQUIRED for Task 001)

1. Use scaffolding with ESLint:
```bash
npx create-next-app my-app --typescript --tailwind --app --eslint
```

2. Add/verify scripts in package.json:
```json
{
  "scripts": {
    "lint": "next lint",
    "validate": ".flight/validate-all.sh",
    "preflight": "npm run validate && npm run lint"
  }
}
```

This makes Flight validation available as `npm run validate`.
Run `npm run preflight` before commits to catch all issues.

## Validation
Run after implementing:
```bash
npm run preflight    # Must pass before moving to next task
```
```

### tasks/002-database-schema.md
```markdown
# Task 002: Database Schema

## Depends On
- 001-project-setup

## Delivers
- users table (id, email, created_at)
- documents table (id, user_id, filename, encrypted_url, created_at)
- upload_links table (id, user_id, token, expires_at, used_at)
- RLS policies for all tables
- Indexes on foreign keys

## NOT In Scope
- Authentication logic (Task 003)
- File upload handling (Task 005)
- SMS sending (Task 004)
- Any API routes

## Acceptance Criteria
- [ ] All tables created in Supabase
- [ ] RLS enabled on all tables
- [ ] Can insert test row via SQL editor
- [ ] Foreign key indexes exist
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
- code-hygiene.md (always)
- sql.md

## Technical Notes
Use snake_case for columns. user_id references auth.users().

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
```

### tasks/003-auth-basic.md
```markdown
# Task 003: Basic Authentication

## Depends On
- 001-project-setup
- 002-database-schema

## Delivers
- /login page with email/password
- /signup page
- Auth middleware protecting /dashboard
- useAuth hook
- Logout functionality

## NOT In Scope
- Magic links (future enhancement)
- OAuth providers (future enhancement)
- Password reset (Task 008)
- Profile editing

## Acceptance Criteria
- [ ] Can create account at /signup
- [ ] Can log in at /login
- [ ] /dashboard redirects to /login if not authenticated
- [ ] Logout clears session
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
- code-hygiene.md (always)
- nextjs.md
- react.md
- typescript.md

## Validation
Run after implementing:
```bash
.flight/validate-all.sh    # Must pass before moving to next task
```
```

*[Continue for all tasks...]*

---

## Critical Rules

1. **Read Flight context FIRST** - Load FLIGHT.md and scan domains before any research

2. **Research AFTER domain discovery** - External docs may conflict; domains are authoritative

3. **Tasks must be atomic** - If you can't do it in 2 hours, split it

4. **"NOT In Scope" is sacred** - This prevents Claude from scope creeping

5. **Dependencies flow forward** - Task 005 can depend on 001-004, not on 006

6. **Each task is self-contained** - Include enough context to execute without re-reading PRD

7. **Acceptance criteria are testable** - "Works well" is bad. "Returns 200 on GET /api/users" is good.

8. **Always include domain constraints** - Based on FLIGHT.md table and actual `.flight/domains/` contents

9. **Include scaffold.md for project setup** - Prevents destructive overwrites of project infrastructure

10. **Number tasks with padding** - 001, 002... not 1, 2 (sorting matters)

11. **validate-all.sh in acceptance criteria** - Local CI must pass before moving to next task

12. **Task 001 configures Flight CI** - ESLint + validate/preflight scripts in package.json

---

## Checklist Before Finishing

### Flight Context
- [ ] Read `.flight/FLIGHT.md` first
- [ ] Scanned `.flight/domains/*.md` to discover available domains
- [ ] Matched domains to tech stack before external research

### Research
- [ ] At least 3 competitors analyzed
- [ ] Tech stack decisions grounded in research
- [ ] Sources cited in PRD.md

### Decomposition
- [ ] 8-15 tasks (not too few, not too many)
- [ ] No task exceeds 2-hour estimate
- [ ] Dependencies are linear where possible
- [ ] Every task has "NOT In Scope" section

### Task Quality
- [ ] Each task has 3-5 acceptance criteria
- [ ] All acceptance criteria are testable
- [ ] All tasks include `.flight/validate-all.sh` passes in acceptance criteria
- [ ] Domain constraints based on actual `.flight/domains/` contents
- [ ] `scaffold.md` included for project setup tasks
- [ ] Task 001 includes Flight CI setup (ESLint + validate/preflight scripts)
- [ ] Context section is minimal but sufficient

### Workflow Ready
- [ ] tasks/ directory created
- [ ] User knows to run `/flight-prime tasks/001-*.md` next
- [ ] User knows to run `.flight/validate-all.sh` after each task
- [ ] MILESTONES.md shows the journey

---

## Output Summary

After running `/flight-prd`, tell the user:

```
Created:
  PRD.md           - Product vision (for reference)
  MILESTONES.md    - 3 milestones, [X] tasks total
  tasks/
    001-project-setup.md
    002-database-schema.md
    ...

Workflow for each task:
  /flight-prime tasks/001-project-setup.md   # Research & compile
  /flight-compile                             # Create atomic prompt
  [implement]
  npm run preflight                           # Local CI (validate + lint)
  /flight-validate                            # Full Flight validation
  [review and approve]
  /flight-prime tasks/002-[next].md           # Next task

Notes:
- Task 001 will configure local CI: ESLint + Flight validation
- After Task 001: use `npm run preflight` (runs validate + lint)
- This catches issues before they hit remote CI or code review
```
