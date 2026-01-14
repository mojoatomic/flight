# Flight Audit Report: api

**Generated:** 2024-01-14
**Domain:** api.md ↔ api.validate.sh

---

## Summary

| Metric | Count |
|--------|-------|
| Spec Rules | 30 (8 NEVER, 9 MUST, 13 SHOULD) |
| Validator Checks | 18 (5 check, 13 warn) |
| Matched | 16 |
| Severity Mismatches | 9 |
| Gaps | 13 |
| Orphans | 1 |
| Skipped | 1 |
| **Total Issues** | **23** |

---

## Spec Rules (api.md)

| ID | Severity | Title | Expected |
|----|----------|-------|----------|
| N1 | NEVER | Verbs in URIs | check |
| N2 | NEVER | 200 OK with Error Body | check |
| N3 | NEVER | Exposing Internal IDs in Pagination | check |
| N4 | NEVER | Breaking Changes Without Versioning | skip |
| N5 | NEVER | Sensitive Data in Query Strings | check |
| N6 | NEVER | Offset Pagination for Large Datasets | check |
| N7 | NEVER | 500 for Client Errors | check |
| N8 | NEVER | CORS Wildcard with Credentials | check |
| M1 | MUST | Use Correct HTTP Methods for Operations | check |
| M2 | MUST | Use Correct Status Codes | check |
| M3 | MUST | Consistent Error Response Format | check |
| M4 | MUST | Plural Nouns for Collection URIs | check |
| M5 | MUST | Include Pagination Metadata in Response | check |
| M6 | MUST | Version Your API from Day One | check |
| M7 | MUST | Rate Limit Headers | check |
| M8 | MUST | Location Header on 201 Created | check |
| M9 | MUST | Content-Type Header on All Responses | check |
| S1 | SHOULD | Use HTTPS Always | warn |
| S2 | SHOULD | Support Content Negotiation | warn |
| S3 | SHOULD | Use ISO 8601 for Dates | warn |
| S4 | SHOULD | Use snake_case for JSON Fields | warn |
| S5 | SHOULD | Nest Related Resources Appropriately | warn |
| S6 | SHOULD | Support Filtering, Sorting, Field Selection | warn |
| S7 | SHOULD | Cache Headers for GET Requests | warn |
| S8 | SHOULD | Idempotency Keys for Non-Idempotent Operations | warn |
| S9 | SHOULD | CORS Headers for Browser Clients | warn |
| S10 | SHOULD | 202 Accepted for Long-Running Operations | warn |
| S11 | SHOULD | OpenAPI/Swagger Specification | warn |
| S12 | SHOULD | No Hardcoded URLs | warn |
| S13 | SHOULD | Include Request IDs | warn |

---

## Validator Checks (api.validate.sh)

| ID | Function | Title |
|----|----------|-------|
| N1 | check | No verbs in URI paths |
| N2 | check | No 200 status with error responses |
| N3 | warn | Potential exposed IDs in pagination (use opaque cursors) |
| N4 | check | No sensitive data in query strings |
| N5 | warn | Potential offset pagination (prefer cursor for large datasets) |
| N6 | check | No 500 status for validation errors |
| N7 | warn | Error responses should include request/trace IDs |
| M1 | warn | Use plural nouns for collections |
| M2 | warn | API versioning present |
| M4 | warn | Rate limit headers present |
| M4a | warn | Pagination responses include metadata |
| M5 | warn | Location header on 201 responses |
| M6 | warn | Content-Type headers on responses |
| S1 | warn | Use HTTPS (no plain HTTP URLs) |
| S3 | warn | Consistent field naming (no mixed casing) |
| S5 | warn | Consider 202 Accepted for async operations |
| S8 | warn | No hardcoded API URLs (use config) |
| S9 | check | No CORS wildcard (*) with credentials |

---

## Issues

### Severity Mismatches (9)

Rules that exist in both but have wrong severity level:

| ID | Spec | Validator | Problem |
|----|------|-----------|---------|
| N3 | NEVER | warn | Should FAIL build, only warns |
| N5 | NEVER | warn | Should FAIL build, only warns |
| N7 | NEVER | warn | Should FAIL build, only warns |
| M1 | MUST | warn | Should FAIL build, only warns |
| M2 | MUST | warn | Should FAIL build, only warns |
| M4 | MUST | warn | Should FAIL build, only warns |
| M5 | MUST | warn | Should FAIL build, only warns |
| M6 | MUST | warn | Should FAIL build, only warns |
| S9 | SHOULD | check | Should only WARN, but fails build |

**Action Required:** Update validator to use `check` for NEVER/MUST rules and `warn` for SHOULD rules.

---

### Gaps (13)

Rules in spec with NO validator implementation:

| ID | Title |
|----|-------|
| M3 | Consistent Error Response Format |
| M7 | Rate Limit Headers |
| M8 | Location Header on 201 Created |
| M9 | Content-Type Header on All Responses |
| N8 | CORS Wildcard with Credentials |
| S2 | Support Content Negotiation |
| S4 | Use snake_case for JSON Fields |
| S6 | Support Filtering, Sorting, Field Selection |
| S7 | Cache Headers for GET Requests |
| S10 | 202 Accepted for Long-Running Operations |
| S11 | OpenAPI/Swagger Specification |
| S12 | No Hardcoded URLs |
| S13 | Include Request IDs |

**Action Required:** Implement validator checks for these rules or mark as "not mechanically validated" in spec.

---

### Orphans (1)

Checks in validator with NO corresponding spec rule:

| ID | Title |
|----|-------|
| M4a | Pagination responses include metadata |

**Action Required:** Document this sub-rule in api.md or remove from validator.

---

### Skipped (1)

Rules explicitly marked as not mechanically validated:

| ID | Title | Reason |
|----|-------|--------|
| N4 | Breaking Changes Without Versioning | Enforced via code review |

---

## Recommendations

1. **Fix severity mismatches first** - These 9 rules are either too lenient (NEVER/MUST using warn) or too strict (SHOULD using check)

2. **Implement high-priority gaps:**
   - N8: CORS Wildcard with Credentials (security)
   - M3: Consistent Error Response Format (API quality)
   - M7-M9: Required headers

3. **Document M4a in spec** - This is a valid check that should be in the spec

4. **Consider marking some SHOULD rules as not mechanically validated** if they're too complex to automate (S6, S11)

---

## Result

```
DRIFT DETECTED: 23 issues
```
