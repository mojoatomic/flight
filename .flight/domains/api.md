# Domain: API Design

REST/HTTP API design patterns. Framework-agnostic. Prevents common integration failures.

**Validation:** `api.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings

Add `// flight:ok` comment on the same line to suppress a specific check:

```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

Use sparingly. Document why the suppression is acceptable.

---

## Invariants

### NEVER (validator will reject)

1. **Verbs in URIs** - URIs identify resources, HTTP methods define actions
   ```
   // BAD - action encoded in URI
   POST /createUser
   POST /users/delete/123
   GET /getUsers
   POST /api/doSomething

   // GOOD - nouns only, method implies action
   POST /users           # create
   DELETE /users/123     # delete
   GET /users            # list
   POST /orders/123/cancel  # action as sub-resource (acceptable)
   ```

2. **200 OK with Error Body** - Status code must reflect outcome
   ```javascript
   // BAD - status lies, body tells truth
   HTTP/1.1 200 OK
   { "success": false, "error": "User not found" }

   // BAD - generic 500 for everything
   HTTP/1.1 500 Internal Server Error
   { "message": "Something went wrong" }

   // GOOD - status code is semantic
   HTTP/1.1 404 Not Found
   { "error": { "code": "USER_NOT_FOUND", "message": "..." } }
   ```

3. **Exposing Internal IDs in Pagination** - Auto-increment IDs leak data
   ```javascript
   // BAD - reveals record count and sequence
   { "next_page": "/users?after_id=84729" }

   // GOOD - opaque cursor (base64 encoded)
   { "next_cursor": "eyJ1cGRhdGVkX2F0IjoiMjAyNC0wMS0xNSIsImlkIjoiODQ3MjkifQ==" }
   ```

4. **Breaking Changes Without Versioning** - Existing clients must not break
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

5. **Sensitive Data in Query Strings** - URLs are logged everywhere
   ```
   // BAD - tokens/passwords in URL (logged by proxies, browsers, servers)
   GET /api/users?api_key=sk_live_abc123
   GET /api/auth?password=hunter2

   // GOOD - sensitive data in headers or body
   Authorization: Bearer sk_live_abc123
   POST /api/auth { "password": "..." }
   ```

6. **Offset Pagination for Large Datasets** - Performance degrades at scale
   ```javascript
   // BAD - database scans and discards rows
   GET /transactions?limit=20&offset=10000
   // SQL: SELECT * FROM transactions LIMIT 20 OFFSET 10000

   // GOOD - cursor/keyset pagination
   GET /transactions?limit=20&after=eyJ0cyI6IjIwMjQtMDEtMTUifQ==
   // SQL: SELECT * FROM transactions WHERE (updated_at, id) > (?, ?) LIMIT 20
   ```

7. **500 for Client Errors** - Server errors mask validation failures
   ```javascript
   // BAD - 500 hides what went wrong
   try {
       validateInput(data)
   } catch (e) {
       res.status(500).json({ error: e.message })  // WRONG!
   }

   // GOOD - distinguish client vs server errors
   try {
       validateInput(data)
   } catch (e) {
       if (e instanceof ValidationError) {
           res.status(400).json({ error: e.message })  // Client's fault
       } else {
           res.status(500).json({ error: "Internal error" })  // Server's fault
       }
   }
   ```

8. **Missing Request IDs** - Impossible to trace issues across services
   ```javascript
   // BAD - no way to correlate logs
   { "error": "Something failed" }

   // GOOD - every response includes trace ID
   {
     "error": "Something failed",
     "request_id": "req_abc123",
     "trace_id": "trace_xyz789"
   }

   // Generate on entry, propagate through, return in response
   X-Request-ID: req_abc123
   ```

9. **CORS Wildcard with Credentials** - Security vulnerability
   ```javascript
   // BAD - allows any origin to send credentials
   Access-Control-Allow-Origin: *
   Access-Control-Allow-Credentials: true

   // BAD - programmatic wildcard with credentials
   res.header('Access-Control-Allow-Origin', '*')
   res.header('Access-Control-Allow-Credentials', 'true')

   // GOOD - explicit origin, no wildcard with credentials
   Access-Control-Allow-Origin: https://app.example.com
   Access-Control-Allow-Credentials: true

   // GOOD - if you need multiple origins, validate against allowlist
   const allowedOrigins = ['https://app.example.com', 'https://admin.example.com']
   if (allowedOrigins.includes(req.headers.origin)) {
       res.header('Access-Control-Allow-Origin', req.headers.origin)
   }
   ```

### MUST (validator will reject)

1. **Use Correct HTTP Methods for Operations**
   ```
   GET     - Read (safe, idempotent, cacheable)
   POST    - Create (not idempotent)
   PUT     - Replace entire resource (idempotent)
   PATCH   - Partial update (idempotent)
   DELETE  - Remove (idempotent)

   Safe: No side effects (GET, HEAD, OPTIONS)
   Idempotent: Same request = same result (GET, PUT, PATCH, DELETE)
   ```

2. **Use Correct Status Codes**
   ```
   2xx Success:
     200 OK           - Successful GET/PUT/PATCH/DELETE
     201 Created      - Successful POST (include Location header)
     204 No Content   - Successful DELETE with no body

   4xx Client Errors:
     400 Bad Request  - Malformed syntax, validation failure
     401 Unauthorized - Missing/invalid authentication
     403 Forbidden    - Authenticated but not authorized
     404 Not Found    - Resource doesn't exist
     409 Conflict     - State conflict (duplicate, version mismatch)
     422 Unprocessable - Valid syntax but semantic errors
     429 Too Many     - Rate limited (include Retry-After)

   5xx Server Errors:
     500 Internal     - Unexpected server failure
     502 Bad Gateway  - Upstream service failure
     503 Unavailable  - Temporarily unavailable (include Retry-After)
     504 Timeout      - Upstream timeout
   ```

3. **Consistent Error Response Format** - RFC 7807 Problem Details
   ```javascript
   // Content-Type: application/problem+json
   {
     "type": "https://api.example.com/errors/validation",
     "title": "Validation Error",
     "status": 400,
     "detail": "Email address is not properly formatted",
     "instance": "/users/123",
     "errors": [
       { "field": "email", "code": "INVALID_FORMAT", "message": "..." }
     ],
     "traceId": "abc123-def456"
   }

   Required: status, title, detail
   Recommended: type (URI), instance, traceId
   ```

4. **Plural Nouns for Collection URIs**
   ```
   // BAD - inconsistent
   GET /user/123
   GET /product
   POST /order

   // GOOD - plural collections
   GET /users/123
   GET /products
   POST /orders
   ```

5. **Include Pagination Metadata in Response**
   ```javascript
   // Cursor-based (preferred)
   {
     "data": [...],
     "pagination": {
       "next_cursor": "eyJ...",
       "prev_cursor": "eyJ...",
       "has_more": true
     }
   }

   // Offset-based (small datasets only)
   {
     "data": [...],
     "pagination": {
       "page": 3,
       "per_page": 20,
       "total": 156,
       "total_pages": 8
     }
   }
   ```

6. **Version Your API from Day One**
   ```
   Approaches (pick one, be consistent):

   URI path (most common):
     /v1/users
     /v2/users

   Header:
     Accept: application/vnd.api+json; version=1
     X-API-Version: 2

   Query param (least preferred):
     /users?version=1
   ```

7. **Rate Limit Headers**
   ```
   X-RateLimit-Limit: 1000        # requests allowed per window
   X-RateLimit-Remaining: 456     # requests remaining
   X-RateLimit-Reset: 1704067200  # Unix timestamp when window resets

   On 429 response:
   Retry-After: 60                # seconds until retry allowed
   ```

8. **Location Header on 201 Created**
   ```javascript
   // BAD - client doesn't know where resource is
   res.status(201).json(newUser)

   // GOOD - include Location header
   res.status(201)
      .header('Location', `/users/${newUser.id}`)
      .json(newUser)
   ```

9. **Content-Type Header on All Responses**
   ```javascript
   // BAD - missing content type
   res.send(data)

   // GOOD - explicit content type
   res.type('application/json').json(data)
   res.type('application/problem+json').json(errorDetails)  // for errors
   ```

### SHOULD (validator warns)

1. **Use HTTPS Always** - Never expose APIs over plain HTTP
   ```
   // BAD
   http://api.example.com/users

   // GOOD
   https://api.example.com/users
   ```

2. **Support Content Negotiation**
   ```
   Request:
     Accept: application/json

   Response:
     Content-Type: application/json

   Support at minimum: application/json
   Error responses: application/problem+json
   ```

3. **Use ISO 8601 for Dates**
   ```javascript
   // BAD - ambiguous formats
   { "created": "01/02/2024" }        // US or EU?
   { "created": 1704067200 }          // Unix timestamp (timezone?)
   { "created": "Jan 1, 2024" }       // Locale-dependent

   // GOOD - ISO 8601 with timezone
   { "created_at": "2024-01-01T12:00:00Z" }
   { "updated_at": "2024-01-01T12:00:00+00:00" }
   ```

4. **Use snake_case for JSON Fields** (or camelCase - be consistent)
   ```javascript
   // Pick one and stick with it
   { "user_id": 123, "created_at": "..." }  // snake_case
   { "userId": 123, "createdAt": "..." }    // camelCase

   // NEVER mix
   { "user_id": 123, "createdAt": "..." }   // inconsistent
   ```

5. **Nest Related Resources Appropriately**
   ```
   // Direct relationship
   GET /users/123/orders           # orders for user 123
   GET /orders/456/items           # items in order 456

   // Don't over-nest (max 2 levels)
   // BAD
   GET /users/123/orders/456/items/789/reviews

   // GOOD - flatten or use query params
   GET /reviews?item_id=789
   GET /items/789/reviews
   ```

6. **Support Filtering, Sorting, Field Selection**
   ```
   Filtering:
     GET /users?status=active&role=admin
     GET /products?price_min=10&price_max=100

   Sorting:
     GET /users?sort=created_at       # ascending
     GET /users?sort=-created_at      # descending (prefix with -)

   Field selection (sparse fieldsets):
     GET /users?fields=id,name,email
   ```

7. **Cache Headers for GET Requests**
   ```
   Cache-Control: public, max-age=3600
   ETag: "9f62089e"
   Last-Modified: Wed, 24 Apr 2024 10:12:00 GMT

   Client sends:
     If-None-Match: "9f62089e"

   Server responds:
     304 Not Modified (if unchanged)
   ```

8. **Idempotency Keys for Non-Idempotent Operations**
   ```
   POST /payments
   Idempotency-Key: a1b2c3d4-e5f6-7890

   - Same key = same result (prevents duplicate charges)
   - Store key → response mapping for 24-48 hours
   - Return cached response for duplicate requests
   ```

9. **CORS Headers for Browser Clients**
   ```
   Access-Control-Allow-Origin: https://app.example.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
   Access-Control-Allow-Headers: Content-Type, Authorization
   Access-Control-Max-Age: 86400

   // Preflight (OPTIONS) must return 204 No Content
   // Never use * for Allow-Origin with credentials
   ```

10. **202 Accepted for Long-Running Operations**
    ```javascript
    // Operation takes > 10 seconds? Don't block.

    // Request
    POST /reports/generate

    // Response (immediate)
    HTTP/1.1 202 Accepted
    Location: /reports/jobs/abc123
    {
      "job_id": "abc123",
      "status": "pending",
      "status_url": "/reports/jobs/abc123"
    }

    // Client polls status_url until complete
    GET /reports/jobs/abc123
    {
      "job_id": "abc123",
      "status": "completed",
      "result_url": "/reports/abc123"
    }
    ```

11. **OpenAPI/Swagger Specification**
    ```
    Maintain machine-readable API documentation:
    - openapi.yaml or openapi.json in project root
    - Keep in sync with implementation
    - Include all endpoints, schemas, examples
    - Use for client SDK generation, testing, docs

    Benefits:
    - Auto-generated client libraries
    - Interactive documentation (Swagger UI)
    - Contract testing
    - IDE autocompletion
    ```

12. **No Hardcoded URLs** - Use configuration/environment
    ```javascript
    // BAD - hardcoded external URLs
    const apiUrl = "https://api.stripe.com/v1/charges"
    fetch("https://maps.googleapis.com/maps/api/geocode")

    // GOOD - from config/environment
    const apiUrl = process.env.STRIPE_API_URL
    const apiUrl = config.get('services.stripe.url')

    // GOOD - relative URLs for same-origin
    fetch("/api/users")

    // Exception: localhost in development is OK
    const devUrl = "http://localhost:3000/api"
    ```

### GUIDANCE (not mechanically checked)

1. **Design for Consumers, Not Your Database**
   ```
   BAD: Expose database schema directly
   - Table names as resources
   - All columns as fields
   - Internal IDs everywhere

   GOOD: Design the interface you'd want to use
   - Domain-driven resources
   - Only relevant fields
   - Stable external identifiers
   ```

2. **Fail Fast with Clear Messages**
   ```
   Validate early:
   - Authentication before processing
   - Required fields before business logic
   - Format validation before database calls

   Return specific errors:
   - Which field failed
   - Why it failed
   - How to fix it
   ```

3. **Document Everything**
   ```
   OpenAPI/Swagger spec should include:
   - All endpoints with examples
   - Request/response schemas
   - Error codes and meanings
   - Authentication methods
   - Rate limits
   - Deprecation notices
   ```

4. **Handle Partial Failures Gracefully**
   ```
   Batch operations should report:
   - Which items succeeded
   - Which items failed
   - Why each failed

   {
     "succeeded": [{ "id": "1" }, { "id": "2" }],
     "failed": [{ "id": "3", "error": { ... } }]
   }
   ```

---

## Patterns

### Resource Naming
```
Collection:     /users
Item:           /users/{id}
Sub-collection: /users/{id}/orders
Sub-item:       /users/{id}/orders/{order_id}
Action:         /users/{id}/activate (POST, when CRUD doesn't fit)
```

### Pagination Decision Tree
```
Dataset size < 10,000 records?
  → Offset pagination is fine

Dataset changes frequently?
  → Cursor pagination required

Users need "jump to page X"?
  → Offset (accept the tradeoffs)

Users scroll infinitely?
  → Cursor pagination

Performance critical?
  → Cursor/keyset pagination always
```

### HTTP Method Decision Tree
```
Reading data?
  → GET (cacheable, safe)

Creating new resource?
  → POST (returns 201 + Location)

Replacing entire resource?
  → PUT (idempotent)

Updating part of resource?
  → PATCH (idempotent)

Removing resource?
  → DELETE (idempotent)

Action that doesn't fit CRUD?
  → POST to action sub-resource
    POST /orders/{id}/cancel
    POST /users/{id}/reset-password
```

### Status Code Decision Tree
```
Success?
  ├─ Created new resource? → 201 + Location header
  ├─ No content to return? → 204
  └─ Returning data? → 200

Client error?
  ├─ Bad syntax/validation? → 400
  ├─ Not authenticated? → 401
  ├─ Authenticated but forbidden? → 403
  ├─ Resource not found? → 404
  ├─ Conflict with current state? → 409
  ├─ Valid syntax, invalid semantics? → 422
  └─ Rate limited? → 429 + Retry-After

Server error?
  ├─ Unexpected failure? → 500
  ├─ Upstream service failed? → 502
  ├─ Temporarily unavailable? → 503 + Retry-After
  └─ Upstream timeout? → 504
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
| Breaking changes | Remove/rename without versioning | Additive changes only |
| Exposed internals | DB IDs, table structure | Domain-driven design |
| No pagination | Return all records | Always paginate collections |
| Offset at scale | OFFSET 100000 | Cursor/keyset pagination |
| Inconsistent naming | Mix snake_case and camelCase | Pick one, enforce it |
| Silent failures | 200 OK on error | Status code = outcome |
| Missing rate limits | No throttling | 429 + headers |
| Plain HTTP | No TLS | HTTPS always |
| No request ID | Can't trace errors | X-Request-ID header |
| Missing Location | 201 without resource URL | Location header on create |
| Blocking long ops | Sync call for slow work | 202 Accepted + polling |
| CORS * + creds | Wildcard origin with credentials | Explicit origin allowlist |
| No API spec | Missing OpenAPI/Swagger | Maintain openapi.yaml |
| Hardcoded URLs | URLs in source code | Use config/environment |

---

## Research Sources

- [RFC 7807 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807)
- [RFC 7231 - HTTP Semantics and Content](https://datatracker.ietf.org/doc/html/rfc7231)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)
- [Google API Design Guide](https://cloud.google.com/apis/design)
- [Stripe API Reference](https://stripe.com/docs/api) - Gold standard
- [Richardson Maturity Model](https://martinfowler.com/articles/richardsonMaturityModel.html)
