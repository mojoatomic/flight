---
name: flight-research
description: Temporal research for dependencies - validates versions, discovers issues, updates landmines. Use before implementation to catch breaking changes and version incompatibilities.
---

# /flight-research

Temporal research for dependencies. Validates versions, discovers breaking changes, updates known landmines.

## Usage

```
/flight-research [dependencies...] [flags]
```

## Arguments

- `$ARGUMENTS` - Optional: specific packages (e.g., `express@5 react@19`)
- If empty: auto-detect from package.json, PRD.md, or tasks/

## Flags

| Flag | Behavior |
|------|----------|
| (none) | Major deps, web search + Context7 |
| `--quick` | Check landmines staleness only, no new searches |
| `--deep` | All deps, add Firecrawl deep dives |
| `--include-all` | Include tooling deps (eslint, prettier, @types) |

---

## Process

### Step 0: Date Anchor (MANDATORY)

**BEFORE ANY TOOL CALLS**, output:

```
📅 Research Date: {CURRENT_DATE}
🔍 Research Window: {YEAR-1}-01-01 to {CURRENT_DATE}
```

This anchors ALL subsequent searches. Without this, queries will return stale results.

**Example:**
```
📅 Research Date: January 16, 2026
🔍 Research Window: 2025-01-01 to 2026-01-16
```

---

### Step 1: Identify Dependencies

Detect dependencies in priority order:

1. **$ARGUMENTS** (if provided) - Use exactly what user specified
2. **package.json** - Parse `dependencies` + `devDependencies`
3. **PRD.md** - Extract tech stack from "## Tech Stack" or similar
4. **tasks/*.md** - Grep for `npm install` commands

#### Skip Patterns (Default)

Skip tooling deps unless `--include-all`:

```
@types/*
eslint*
prettier*
*-loader
*-plugin
typescript  (unless explicitly requested)
```

**Heuristic:** If a breaking change would require CODE changes (not just config), research it.

#### Output Step 1:

```markdown
## Dependencies to Research

**Source:** {package.json|PRD.md|args}

| Package | Current | Category |
|---------|---------|----------|
| express | ^5.0.0 | Backend |
| react | ^19.0.0 | Frontend |
| tailwindcss | ^4.0.0 | Styling |

**Skipped (tooling):** eslint, prettier, @types/node
```

---

### Step 2: Check Existing Landmines

If `.flight/known-landmines.md` exists:

1. **Read the "Last Full Review" date**
2. **If >3 months old:** Mark ALL entries as NEEDS_VERIFICATION
3. **Check each entry against dependencies being researched**
4. **Use entries as research STARTING POINTS, not facts**

#### Output Step 2:

```markdown
## Existing Landmines Check

**Last Review:** 2025-10-15 (3+ months ago - treating as unverified)

| Entry | Status | Action |
|-------|--------|--------|
| Express 5.x middleware hang | NEEDS_VERIFICATION | Will re-verify |
| Tailwind v4 PostCSS | NEEDS_VERIFICATION | Will re-verify |
```

If no landmines file exists, note: "No existing landmines file. Will create."

---

### Step 3: Research Each Dependency

For each dependency, run date-anchored searches.

#### 3a. Breaking Changes (GitHub)

```
"{library} breaking changes {YEAR-1}-{YEAR}" site:github.com
```

**Why GitHub first:** Issues surface pain 6-12 months before blog posts.

#### 3b. Migration Guide

```
"{library} v{X} migration guide after:{YEAR-1}-01-01"
```

**Why:** Indicates major version transitions requiring code changes.

#### 3c. Integration Issues (if using scaffold tools)

```
"vite {library} {YEAR}" OR "create-react-app {library} {YEAR}"
```

**Why:** Scaffold tools may install incompatible versions.

#### 3d. Stack Overflow

```
"{library} {framework} after:{YEAR-1}-01-01" site:stackoverflow.com
```

**Why:** Community pain points surface here. Date filter critical.

#### 3e. Context7 Documentation (version-pinned)

```
context7 "{library}@{version}"  # ALWAYS include version
```

**NEVER:** `context7 "{library}"` without version - will get wrong docs.

#### --deep mode only: Firecrawl

If initial searches are inconclusive, use Firecrawl for deep dives:
- Official changelog pages
- GitHub release notes
- Migration guide sites

---

### Step 4: Update Landmines File

Update `.flight/known-landmines.md`:

#### New Issues → Add Entry

```markdown
### {Issue Title}
**Discovered:** {CURRENT_DATE}
**Status:** ACTIVE
**Re-verify After:** {CURRENT_DATE + 6 months}
**Issue:** {description}
**Verify By:** Search "{library} {issue} fixed {YEAR}"
**Solution (if active):** {workaround or version pin}
```

#### Existing Issues → Update Status

- Still valid → Keep as ACTIVE, update "Last Verified"
- Fixed → Change to RESOLVED, note which version fixed it
- Uncertain → Keep as NEEDS_VERIFICATION

#### Update File Header

```markdown
> **Last Full Review:** {CURRENT_DATE}
```

---

### Step 5: Update Existing Files (if they exist)

**Principle:** Update what exists, don't create new artifacts.

#### If `tasks/*.md` exist with `npm install`:

Update version pins:

```diff
- npm install express
+ npm install express@4.21.0  # Pinned - v5.x has middleware issues (see landmines)
```

#### If `PRD.md` exists:

Append to "Known Technical Issues" section (create section if missing):

```markdown
## Known Technical Issues

### Express v5.x Middleware Hang
**Risk:** High
**Issue:** `express.json()` causes silent hangs on POST requests
**Mitigation:** Pin to express@4.21.0 in Task 001
**Source:** [GitHub Issue #5678](url)
```

---

### Step 6: Output Summary

```markdown
## Research Summary

📅 **Research Date:** {CURRENT_DATE}
🔍 **Research Window:** {YEAR-1}-01-01 to {CURRENT_DATE}
📦 **Dependencies Researched:** {count}

### Version Recommendations

| Package | Latest | Recommended | Reason |
|---------|--------|-------------|--------|
| express | 5.1.0 | 4.21.0 | v5.x middleware hang |
| react | 19.0.0 | 19.0.0 | Stable |
| tailwindcss | 4.0.0 | 3.4.0 | v4 requires PostCSS changes |

### New Landmines Discovered
- Express 5.x: middleware hang (ACTIVE)
- Tailwind 4.x: PostCSS plugin requirement (ACTIVE)

### Landmines Verified Still Active
- (none from previous research)

### Landmines Now Resolved
- React 18 hydration bug: Fixed in 18.3.0

### Files Updated
- `.flight/known-landmines.md` - 2 entries added
- `tasks/001-setup.md` - version pins updated
- `PRD.md` - Known Technical Issues section added
```

---

## Critical Rules

1. **DATE ANCHOR IS MANDATORY** - Step 0 must happen BEFORE any searches
2. **VERSION-PIN CONTEXT7 QUERIES** - Always `{library}@{version}`
3. **LANDMINES ARE STARTING POINTS** - Never trust without re-verification
4. **UPDATE, DON'T CREATE** - Only modify existing files
5. **SKIP TOOLING BY DEFAULT** - Focus on decision dependencies

---

## Tool Usage

| Tool | When | Query Format |
|------|------|--------------|
| Web Search | Always (primary) | `"{lib} breaking changes {YEAR-1}-{YEAR}"` |
| Context7 | Docs lookup | `"{lib}@{version}"` (versioned!) |
| Firecrawl | --deep mode only | Changelog URLs, release notes |
| Read | Check existing files | package.json, landmines.md, PRD.md |
| Edit | Update task files | Version pins |

---

## When to Use

| Situation | Use This? |
|-----------|-----------|
| Before `/flight-compile` on new project | Yes |
| Adding new dependencies to existing project | Yes |
| Resuming work on stale project (>3 months) | Yes - use `--quick` first |
| Just finished `/flight-prd` Step 2A | Yes |
| Already know exact versions needed | No |
| Only changing internal code (no new deps) | No |

---

## Workflow Integration

### New Project

```
/flight-prd "my app idea"
  → Step 2A completes, recommends: "Run /flight-research"

/flight-research
  → Researches deps, updates landmines

/flight-compile
  → Has temporal context from research
```

### Existing Project, New Dependencies

```
/flight-research express@5 mongodb@7
  → Researches specific deps
  → Updates landmines
```

### Stale Project

```
/flight-research --quick
  → Checks landmine staleness
  → Flags what needs re-verification

/flight-research
  → Full re-verification
```

---

## Next Step

After research completes:

```
/flight-compile
```

Or continue with `/flight-prd` Step 3 (task decomposition).

**Workflow**: `/flight-prd` Step 2A → `/flight-research` → `/flight-prd` Step 3 → `/flight-compile`

| Response | Action |
|----------|--------|
| `compile` or `c` | Proceed to `/flight-compile` |
| `continue` | Return to `/flight-prd` for task decomposition |
| `deep` | Re-run with `--deep` for more thorough research |

---

## Notes

- Research is TEMPORAL - findings have expiration dates
- The landmines file is institutional memory, not gospel
- Date anchoring prevents the #1 cause of stale research
- When in doubt, re-verify with fresh searches
