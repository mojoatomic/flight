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
/flight-validate
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

## M2: Core Feature (Tasks 004-007)
[The main thing the product does]
**Exit Criteria**: [Specific testable outcome]

## M3: Polish (Tasks 008-010)
Error handling, edge cases, UX improvements.
**Exit Criteria**: Ready for beta users.
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

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- [relevant-domain].md

## Context
[Minimal context Claude needs for THIS task only.
Don't repeat the whole PRD. Just what's relevant.]

## Technical Notes
[Any specific technical decisions or patterns to follow.
Reference prior tasks if building on them.]
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
- Next.js 14 project with App Router
- Supabase project connected
- Environment variables configured
- Basic layout component

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

## Domain Constraints
- code-hygiene.md
- nextjs.md
- typescript.md
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

## Domain Constraints
- code-hygiene.md
- sql.md

## Technical Notes
Use snake_case for columns. user_id references auth.users().
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

## Domain Constraints
- code-hygiene.md
- nextjs.md
- react.md
- typescript.md
```

*[Continue for all tasks...]*

---

## Critical Rules

1. **Research BEFORE decomposing** - Understand the problem space first

2. **Tasks must be atomic** - If you can't do it in 2 hours, split it

3. **"NOT In Scope" is sacred** - This prevents Claude from scope creeping

4. **Dependencies flow forward** - Task 005 can depend on 001-004, not on 006

5. **Each task is self-contained** - Include enough context to execute without re-reading PRD

6. **Acceptance criteria are testable** - "Works well" is bad. "Returns 200 on GET /api/users" is good.

7. **Always include domain constraints** - Tell Claude which .md files to load

8. **Number tasks with padding** - 001, 002... not 1, 2 (sorting matters)

---

## Checklist Before Finishing

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
- [ ] Domain constraints specified for each task
- [ ] Context section is minimal but sufficient

### Workflow Ready
- [ ] tasks/ directory created
- [ ] User knows to run `/flight-prime tasks/001-*.md` next
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

Next step:
  /flight-prime tasks/001-project-setup.md

Then after each task:
  /flight-validate
  [review and approve]
  /flight-prime tasks/002-[next].md
```
