# Known Landmines

> **TEMPORAL DATA WARNING**
>
> This file contains issue reports that WILL become stale.
> ALWAYS re-verify before acting on any entry.
>
> **Last Full Review:** {DATE}

---

## How to Use This File

1. **Check the discovery date** - if >6 months old, re-research
2. **Search for resolution** - `"{library} {issue} fixed {current_year}"`
3. **Update status** when you verify
4. **Delete entries** when issues are confirmed resolved

**These are research STARTING POINTS, not facts.**

---

## Entry Format

```markdown
### {Issue Title}
**Discovered:** {YYYY-MM-DD}
**Status:** NEEDS_VERIFICATION | ACTIVE | RESOLVED | ARCHITECTURAL | EVERGREEN
**Re-verify After:** {YYYY-MM-DD, typically +6 months}
**Issue:** {description of the problem}
**Verify By:** Search "{query to check if still valid}"
**Solution (if active):** {workaround or version pin}
**If Resolved:** {note which version fixed it}
```

---

## Status Types

| Status | Meaning | Action |
|--------|---------|--------|
| `ACTIVE` | Confirmed current issue | Use workaround |
| `NEEDS_VERIFICATION` | Entry >6 months old | Re-research before trusting |
| `RESOLVED` | Was problem, now fixed | Note fix version, consider removing |
| `ARCHITECTURAL` | Framework design choice | Unlikely to change, but verify |
| `EVERGREEN` | Timeless pattern | Port conflicts, etc. |

---

## Landmines

<!-- Populate during /flight-research -->
<!-- Remove this comment when adding first entry -->

