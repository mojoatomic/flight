# Domain: API Design

REST/HTTP API design patterns. Framework-agnostic. Prevents common integration failures.

**Validation:** `api.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Verbs in URIs** - URIs identify resources, HTTP methods define actions
   ```
   // BAD
   POST /createUser
   // BAD
   POST /users/delete/123
   // BAD
   GET /getUsers

   // GOOD
   POST /users
   // GOOD
   DELETE /users/123
   // GOOD
   GET /users
   ```

2. **200 OK with Error Body** - Status code must reflect outcome
   ```
   // BAD
   HTTP/1.1 200 OK
   { "success": false, "error": "User not found" }

   // GOOD
   HTTP/1.1 404 Not Found
   { "error": { "code": "USER_NOT_FOUND" } }
   ```

3. **Exposing Internal IDs in Pagination** - Auto-increment IDs leak data (record count, sequence)
   ```
   // BAD
   { "next_page": "/users?after_id=84729" }

   // GOOD
   { "next_cursor": "eyJ1cGRhdGVkX2F0Ijo..." }
   ```

4. **Breaking Changes Without Versioning** - Existing clients must not break

   > ⚠️ Not mechanically validated. Enforced via code review and semantic versioning.
   ```
   Breaking changes:
   - Removing or renaming fields
   - Changing field types
   - Removing endpoints
   - Changing required/optional status
   - Changing authentication

   Non-breaking changes (additive):
   - Adding new optional fields
   - Adding new endpoints
   - Adding new optional query params
   ```

5. **Sensitive Data in Query Strings** - URLs are logged everywhere (proxies, browsers, servers)
   ```
   // BAD
   GET /api/users?api_key=sk_live_abc123
   // BAD
   GET /api/auth?password=hunter2

   // GOOD
   Authorization: Bearer sk_live_abc123
   // GOOD
   POST /api/auth { "password": "..." }
   ```

6. **Offset Pagination for Large Datasets** - Performance degrades at scale (database scans and discards rows)
   ```
   // BAD
   GET /transactions?limit=20&offset=10000

   // GOOD
   GET /transactions?limit=20&after=eyJ0cyI6...
   ```

7. **500 for Client Errors** - Server errors mask validation failures
   ```
   // BAD
   catch (e) { res.status(500).json({ error: e.message }) }

   // GOOD
   if (e instanceof ValidationError) { res.status(400)... }
   ```

8. **CORS Wildcard with Credentials** - Security vulnerability - allows any origin to send credentials
   ```
   // BAD
   Access-Control-Allow-Origin: *
   Access-Control-Allow-Credentials: true

   // GOOD
   Access-Control-Allow-Origin: https://app.example.com
   Access-Control-Allow-Credentials: true
   ```

### MUST (validator will reject)

1. **Use Correct HTTP Methods for Operations** - GET=read, POST=create, PUT=replace, PATCH=update, DELETE=remove

   > Semantic check - requires understanding intent, not mechanically validatable
   ```
   GET     - Read (safe, idempotent, cacheable)
   POST    - Create (not idempotent)
   PUT     - Replace entire resource (idempotent)
   PATCH   - Partial update (idempotent)
   DELETE  - Remove (idempotent)
   ```

2. **Use Correct Status Codes** - Status codes must semantically match the response

   > Semantic check - requires understanding context, not mechanically validatable
   ```
   2Xx:
   200 OK - Successful GET/PUT/PATCH/DELETE
   201 Created - Successful POST (include Location header)
   204 No Content - Successful DELETE with no body
   ```
   ```
   4Xx:
   400 Bad Request - Malformed syntax, validation failure
   401 Unauthorized - Missing/invalid authentication
   403 Forbidden - Authenticated but not authorized
   404 Not Found - Resource doesn't exist
   409 Conflict - State conflict
   422 Unprocessable - Valid syntax but semantic errors
   429 Too Many - Rate limited (include Retry-After)
   ```
   ```
   5Xx:
   500 Internal - Unexpected server failure
   502 Bad Gateway - Upstream service failure
   503 Unavailable - Temporarily unavailable
   504 Timeout - Upstream timeout
   ```

3. **Consistent Error Response Format (RFC 9457)** - Use Problem Details for HTTP APIs (RFC 9457 supersedes RFC 7807)
   ```
   {
     "type": "https://api.example.com/errors/validation",
     "title": "Validation Error",
     "status": 400,
     "detail": "Email address is not properly formatted",
     "instance": "/users/123",
     "traceId": "abc123-def456"
   }
   ```

4. **Plural Nouns for Collection URIs** - Collections should use plural nouns
   ```
   // BAD
   GET /user/123
   // BAD
   POST /order

   // GOOD
   GET /users/123
   // GOOD
   POST /orders
   ```

5. **Include Pagination Metadata in Response** - Paginated responses must include navigation metadata
   ```
   Cursor Based:
   {
     "data": [...],
     "pagination": {
       "next_cursor": "eyJ...",
       "prev_cursor": "eyJ...",
       "has_more": true
     }
   }
   ```
   ```
   Offset Based:
   {
     "data": [...],
     "pagination": {
       "page": 3,
       "per_page": 20,
       "total": 156
     }
   }
   ```

6. **Version Your API from Day One** - APIs must be versioned
   ```
   Uri Path:
   /v1/users
   /v2/users
   ```
   ```
   Header:
   Accept: application/vnd.api+json; version=1
   X-API-Version: 2
   ```

7. **Rate Limit Headers** - Include rate limiting information in responses
   ```
   Headers:
   X-RateLimit-Limit: 1000
   X-RateLimit-Remaining: 456
   X-RateLimit-Reset: 1704067200
   Retry-After: 60
   ```

8. **Location Header on 201 Created** - Created responses must include Location header
   ```
   // BAD
   res.status(201).json(newUser)

   // GOOD
   res.status(201).header("Location", `/users/${id}`).json(newUser)
   ```

9. **Content-Type Header on All Responses** - All responses must have explicit Content-Type
   ```
   res.type("application/json").json(data)
   res.type("application/problem+json").json(errorDetails)
   ```

### SHOULD (validator warns)

1. **Use HTTPS Always** - Never expose APIs over plain HTTP
   ```
   // BAD
   http://api.example.com/users

   // GOOD
   https://api.example.com/users
   ```

2. **Support Content Negotiation** - Support Accept header for content type negotiation

   > Complex to validate mechanically
   ```
   Request:
   Accept: application/json
   ```
   ```
   Response:
   Content-Type: application/json
   ```

3. **Use ISO 8601 for Dates** - Use standard date format with timezone
   ```
   // BAD
   { "created": "01/02/2024" }
   // BAD
   { "created": 1704067200 }

   // GOOD
   { "created_at": "2024-01-01T12:00:00Z" }
   ```

4. **Consistent Field Naming Convention** - Use snake_case or camelCase consistently, never mix
   ```
   // BAD
   { "user_id": 123, "createdAt": "..." }

   // GOOD
   { "user_id": 123, "created_at": "..." }
   // GOOD
   { "userId": 123, "createdAt": "..." }
   ```

5. **Nest Related Resources Appropriately** - Use sub-resources for direct relationships, max 2 levels deep

   > Semantic check - requires understanding resource relationships
   ```
   // BAD
   GET /users/123/orders/456/items/789/reviews

   // GOOD
   GET /users/123/orders
   // GOOD
   GET /orders/456/items
   ```

6. **Support Filtering, Sorting, Field Selection** - Collection endpoints should support query operations

   > Feature completeness check - not mechanically validatable
   ```
   Filtering:
   GET /users?status=active&role=admin
   ```
   ```
   Sorting:
   GET /users?sort=-created_at
   ```
   ```
   Fields:
   GET /users?fields=id,name,email
   ```

7. **Cache Headers for GET Requests** - Include caching headers for cacheable responses

   > Context-dependent - not all GETs should be cached
   ```
   Headers:
   Cache-Control: public, max-age=3600
   ETag: "9f62089e"
   Last-Modified: Wed, 24 Apr 2024 10:12:00 GMT
   ```

8. **Idempotency Keys for Non-Idempotent Operations** - POST operations should support idempotency keys
   ```
   POST /payments
   Idempotency-Key: a1b2c3d4-e5f6-7890
   ```

9. **CORS Headers for Browser Clients** - Include CORS headers for browser-based API consumers
   ```
   Headers:
   Access-Control-Allow-Origin: https://app.example.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
   Access-Control-Allow-Headers: Content-Type, Authorization
   ```

10. **202 Accepted for Long-Running Operations** - Use async pattern for operations > 10 seconds
   ```
   Response:
   HTTP/1.1 202 Accepted
   Location: /reports/jobs/abc123
   { "job_id": "abc123", "status": "pending" }
   ```

11. **OpenAPI/Swagger Specification** - Maintain machine-readable API documentation
   ```
   Benefits:
   Auto-generated client libraries
   Interactive documentation (Swagger UI)
   Contract testing
   ```

12. **No Hardcoded URLs** - Use configuration/environment for external URLs
   ```
   // BAD
   const apiUrl = "https://api.stripe.com/v1/charges"

   // GOOD
   const apiUrl = process.env.STRIPE_API_URL
   // GOOD
   fetch("/api/users")
   ```

13. **Include Request IDs** - Enable tracing across services with request/trace IDs
   ```
   // BAD
   { "error": "Something failed" }

   // GOOD
   { "error": "Something failed", "request_id": "req_abc123" }
   ```

### GUIDANCE (not mechanically checked)

1. **Design for Consumers, Not Your Database** - API should reflect domain model, not database schema
   ```
   // BAD
   Expose database schema directly
   // BAD
   Table names as resources
   // BAD
   Internal IDs everywhere

   // GOOD
   Domain-driven resources
   // GOOD
   Only relevant fields
   // GOOD
   Stable external identifiers
   ```

2. **Fail Fast with Clear Messages** - Validate early, return specific errors
   ```
   Validate Order:
   Authentication before processing
   Required fields before business logic
   Format validation before database calls
   ```
   ```
   Error Format:
   Which field failed
   Why it failed
   How to fix it
   ```

3. **Document Everything** - OpenAPI spec should be comprehensive
   ```
   Include:
   All endpoints with examples
   Request/response schemas
   Error codes and meanings
   Authentication methods
   Rate limits
   Deprecation notices
   ```

4. **Handle Partial Failures Gracefully** - Batch operations should report individual success/failure
   ```
   Response:
   {
     "succeeded": [{ "id": "1" }, { "id": "2" }],
     "failed": [{ "id": "3", "error": { ... } }]
   }
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Verbs in URIs | POST /createUser | POST /users |
| 200 with error | 200 OK + error body | Use 4xx/5xx codes |
| 500 for validation | Server error for bad input | 400 for client errors |
| RPC over REST | Single endpoint, action in body | Resource-oriented design |
| Chatty API | Many calls for one task | Aggregate endpoints |
| Exposed internals | DB IDs, table structure | Domain-driven design |
| No pagination | Return all records | Always paginate collections |
| Offset at scale | OFFSET 100000 | Cursor/keyset pagination |
| Inconsistent naming | Mix snake_case and camelCase | Pick one, enforce it |
| Missing rate limits | No throttling | 429 + headers |
| Plain HTTP | No TLS | HTTPS always |
| No request ID | Can't trace errors | X-Request-ID header |
| CORS * + creds | Wildcard origin with credentials | Explicit origin allowlist |
