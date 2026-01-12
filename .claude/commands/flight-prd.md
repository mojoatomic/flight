# /flight-prd - Product Requirements Document Generator

Generate a PRD from a rough idea using comprehensive research.

## Purpose

Transform a vague product idea into a concrete, well-researched PRD that can be fed to `/flight-prime`.

## Usage

```
/flight-prd <rough product idea>
```

## Example

```
/flight-prd Simple document collection system - user uploads docs via SMS link, stored encrypted
```

---

## Process

### 1. Understand the Request

Parse the rough idea into:
- **Core problem**: What pain point does this solve?
- **Target users**: Who needs this?
- **Key capabilities**: What must it do?

### 2. Research Phase - USE ALL AVAILABLE TOOLS

**IMPORTANT**: You have access to multiple research tools. Use them strategically:

#### Web Search (built-in)
- Search for existing solutions and competitors
- Find articles about the problem space
- Look for recent developments and trends
- **Queries**: `"{problem} solutions"`, `"{problem} software"`, `"best {category} tools"`, `"{competitor} alternatives"`

#### Context7 MCP (if available)
- Get up-to-date documentation for relevant libraries/frameworks
- Pull current API examples for tech stack decisions
- **Check for**: `resolve-library-id` and `get-library-docs` tools
- **Use for**: Framework docs (Next.js, React, Supabase, etc.)

#### Firecrawl MCP (if available)
- Deep crawl competitor websites
- Extract features, pricing, architecture details
- Scrape documentation sites for patterns
- **Check for**: `firecrawl_scrape`, `firecrawl_crawl`, `firecrawl_search` tools
- **Use for**: Competitor analysis, feature extraction

#### Tool Availability Check

Before researching, check what MCP tools are available by looking at your tool list. Look for:
- `context7_*` tools → Context7 is available
- `firecrawl_*` tools → Firecrawl is available

**If a tool is NOT available but would significantly improve the PRD:**

```
NOTE: This PRD would benefit from [Context7/Firecrawl] for [specific reason].

To install (check docs for current method):
- Context7: https://github.com/upstash/context7
- Firecrawl: https://github.com/mendableai/firecrawl

Would you like me to proceed with available tools, or install these first?
```

### 3. Competitive Analysis

Using research results, document:

| Competitor | Strengths | Weaknesses | Price Point |
|------------|-----------|------------|-------------|
| ... | ... | ... | ... |

### 4. Generate PRD.md

Create `PRD.md` with this structure:

```markdown
# PRD: [Product Name]

## Problem Statement
[What problem does this solve? Who has this problem? Why do current solutions fail?]

## Target Users
- Primary: [who]
- Secondary: [who]

## User Stories

### Must Have (P0)
- As a [user], I want to [action] so that [benefit]
- ...

### Should Have (P1)
- ...

### Nice to Have (P2)
- ...

## Functional Requirements

### Core Features
1. [Feature]: [Description]
   - Acceptance criteria: [specific, testable criteria]
   
2. [Feature]: [Description]
   - Acceptance criteria: [specific, testable criteria]

### Integrations
- [Integration]: [Why needed]

## Non-Functional Requirements

### Security
- [Requirement]

### Performance  
- [Requirement]

### Scalability
- [Requirement]

## Technical Constraints
- [Constraint]: [Reason]

## Out of Scope
- [What this is NOT]
- [What we're explicitly deferring]

## Competitive Landscape
[Summary of competitors and how this differs]

## Success Metrics
- [Metric]: [Target]

## Open Questions
- [Question that needs user input]

---

## Research Sources
- [URL]: [What was learned]
- [URL]: [What was learned]
```

### 5. Output

1. Save to `PRD.md` in project root
2. Summarize key findings
3. List any open questions that need user input
4. Suggest next step: `/flight-prime Implement the system in PRD.md`

---

## Research Strategy by Product Type

### SaaS / Web App
1. Web search for competitors
2. Firecrawl competitor sites for feature lists
3. Context7 for framework docs (Next.js, React, etc.)

### API / Developer Tool
1. Web search for existing solutions
2. Context7 for SDK patterns and conventions
3. Firecrawl for documentation structure examples

### Mobile App
1. Web search for App Store competitors
2. Firecrawl for competitor landing pages
3. Context7 for React Native / Flutter docs

### Integration / Plugin
1. Context7 for platform API docs
2. Web search for existing integrations
3. Firecrawl for integration examples

---

## Critical Rules

1. **ALWAYS check for available tools first** - Don't assume. List MCP tools.

2. **Use ALL available tools** - Don't skip Context7 if it's there. Don't skip Firecrawl if it's there.

3. **If tools are missing, tell the user** - They may want to install them for better results.

4. **Research BEFORE writing** - Don't generate a PRD from imagination. Research first.

5. **Cite sources** - Every claim should trace back to research.

6. **Ask about unknowns** - If something is ambiguous, add it to Open Questions.

7. **Be specific** - "User authentication" is bad. "Email/password auth with magic link option" is good.

8. **Include acceptance criteria** - Every feature needs testable criteria.

---

## PRD Completeness Checklist

Before finalizing, verify:

### Research
- [ ] At least 3 competitors identified
- [ ] Competitor strengths/weaknesses documented
- [ ] Price points researched (if applicable)
- [ ] All claims have source citations

### Requirements
- [ ] Problem statement is specific, not generic
- [ ] Target users are named personas, not "users"
- [ ] P0 features are truly minimal (3-5 max)
- [ ] Every feature has acceptance criteria
- [ ] Non-functional requirements cover security, performance, scalability

### Clarity
- [ ] No vague terms ("fast", "secure", "easy") without metrics
- [ ] Out of Scope section explicitly lists what's NOT included
- [ ] Open Questions captures genuine unknowns
- [ ] Technical constraints are justified

### Workflow Ready
- [ ] PRD.md saved to project root
- [ ] Can be directly fed to `/flight-prime`
- [ ] Success metrics are measurable

---

## Example Output

Given: `/flight-prd Simple document collection system - user uploads docs via SMS link, stored encrypted`

After research, outputs `PRD.md` with:
- Competitor analysis (DocuSign Request, Dropbox File Request, HelloSign, etc.)
- Differentiation (SMS-first, zero-knowledge encryption, simpler UX)
- Specific features with acceptance criteria
- Security requirements based on competitor research
- Tech stack suggestions based on Context7 docs
- Open questions (SMS provider choice, encryption key management)
