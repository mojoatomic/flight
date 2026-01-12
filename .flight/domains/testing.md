# Domain: Testing

Universal unit test patterns. Language-agnostic, framework-agnostic. Prevents weak tests.

**Validation:** `testing.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Enumerated Test Names** - test1, test2 provides no information
   ```javascript
   // BAD - what does this test?
   test('test1', () => { ... })
   def test1(self): ...
   func Test1(t *testing.T) { ... }

   // GOOD - name describes behavior
   test('should return user when valid ID provided', () => { ... })
   def test_returns_empty_list_when_no_matches(self): ...
   func TestUserService_ReturnsError_WhenNotFound(t *testing.T) { ... }
   ```

2. **Empty Tests / No Assertions** - Tests that pass without asserting anything
   ```javascript
   // BAD - passes but proves nothing
   it('works', () => {})
   it('handles edge case', () => { doSomething() })  // no assertion!
   def test_something(self): pass

   // GOOD - explicit assertions
   it('works', () => { expect(result).toBe(true) })
   def test_something(self): self.assertEqual(result, expected)
   ```

3. **Hardcoded Sleep/Delays** - Flaky and slow tests
   ```javascript
   // BAD - arbitrary wait, still flaky
   await sleep(1000)
   time.sleep(2)
   Thread.sleep(500)
   await new Promise(r => setTimeout(r, 100))

   // GOOD - wait for condition
   await waitFor(() => expect(element).toBeVisible())
   mock_time.advance(seconds=2)
   eventually { assert condition }
   ```

4. **Testing Private Methods Directly** - Breaks encapsulation, couples to implementation
   ```javascript
   // BAD - accessing internals
   expect(obj._privateMethod()).toBe(...)
   expect(obj.__private_attr).toBe(...)
   expect(obj['#privateField']).toBe(...)

   // GOOD - test through public interface
   expect(obj.publicMethod()).toBe(...)
   // Private behavior is tested implicitly
   ```

5. **Shared Mutable State Between Tests** - Order-dependent failures (Generous Leftovers)
   ```javascript
   // BAD - tests pollute each other
   let sharedUser;
   beforeAll(() => { sharedUser = createUser() })
   test('modifies user', () => { sharedUser.name = 'changed' })
   test('reads user', () => { expect(sharedUser.name).toBe('original') }) // FAILS!

   // GOOD - each test owns its state
   test('test1', () => {
       const user = createUser()
       user.name = 'changed'
       expect(user.name).toBe('changed')
   })
   test('test2', () => {
       const user = createUser()
       expect(user.name).toBe('original')
   })
   ```

6. **Mocking the System Under Test** - You're testing mocks, not code (Mockery)
   ```javascript
   // BAD - mocking what you're testing
   const calculator = mock(Calculator)
   when(calculator.add(2, 2)).thenReturn(4)
   expect(calculator.add(2, 2)).toBe(4)  // USELESS - proves nothing

   // GOOD - mock dependencies, test real code
   const database = mock(Database)
   const service = new UserService(database)  // real service
   when(database.findById(1)).thenReturn(mockUser)
   expect(service.getUser(1)).toEqual(mockUser)  // tests real logic
   ```

7. **Unawaited Async Assertions** - Promise never awaited, test passes even on failure
   ```javascript
   // BAD - promise not awaited, test always passes
   test('fetches data', () => {
       fetchData().then(data => expect(data).toBeDefined())
   })

   // BAD - assertion in callback, never executed if error
   test('loads user', () => {
       api.getUser(1).then(user => {
           expect(user.name).toBe('Alice')
       })
   })

   // GOOD - await the assertion
   test('fetches data', async () => {
       const data = await fetchData()
       expect(data).toBeDefined()
   })

   // GOOD - return the promise
   test('fetches data', () => {
       return fetchData().then(data => expect(data).toBeDefined())
   })
   ```

8. **Try-Catch Swallowing Failures** - Catches error, test passes when it shouldn't
   ```javascript
   // BAD - if no error thrown, catch never runs, test passes
   test('throws error', () => {
       try {
           doThing()
       } catch (e) {
           expect(e).toBeDefined()  // never reached if no error!
       }
   })

   // BAD - catches and ignores
   test('handles error', () => {
       try {
           riskyOperation()
           expect(true).toBe(true)
       } catch (e) {
           expect(e.message).toContain('error')
       }
   })

   // GOOD - use expect().toThrow()
   test('throws error', () => {
       expect(() => doThing()).toThrow()
   })

   // GOOD - use rejects for async
   test('rejects with error', async () => {
       await expect(asyncDoThing()).rejects.toThrow(Error)
   })
   ```

### MUST (validator will reject)

1. **Follow AAA Pattern** - Arrange, Act, Assert with clear separation
   ```javascript
   test('should calculate total with tax', () => {
       // Arrange
       const cart = new Cart()
       cart.addItem({ price: 100 })
       const taxRate = 0.1

       // Act
       const total = cart.calculateTotal(taxRate)

       // Assert
       expect(total).toBe(110)
   })
   ```
   ```python
   def test_calculate_total_with_tax(self):
       # Arrange
       cart = Cart()
       cart.add_item(Item(price=100))
       tax_rate = 0.1

       # Act
       total = cart.calculate_total(tax_rate)

       # Assert
       self.assertEqual(total, 110)
   ```

2. **Descriptive Test Names** - Name describes the behavior being tested
   ```
   Good naming patterns:
   - should_[expected]_when_[condition]
   - [method]_returns_[result]_when_[condition]
   - [method]_throws_[error]_for_[input]
   - given_[state]_when_[action]_then_[result]

   Examples:
   - should_return_null_when_user_not_found
   - calculateTotal_returns_zero_for_empty_cart
   - login_throws_AuthError_for_invalid_credentials
   - given_expired_token_when_refresh_then_new_token_issued
   ```

3. **One Behavior Per Test** - Single logical assertion per test (Free Ride prevention)
   ```javascript
   // BAD - testing multiple unrelated behaviors
   test('user service', () => {
       expect(service.create(user)).toBeTruthy()
       expect(service.findById(1)).toEqual(user)
       expect(service.delete(1)).toBeTruthy()
       expect(service.findById(1)).toBeNull()
   })

   // GOOD - one behavior per test
   test('create returns created user', () => {
       const result = service.create(user)
       expect(result).toEqual(user)
   })

   test('findById returns user when exists', () => {
       service.create(user)
       expect(service.findById(1)).toEqual(user)
   })

   test('findById returns null when not exists', () => {
       expect(service.findById(999)).toBeNull()
   })
   ```

4. **Test Independence** - Tests must not depend on execution order
   ```javascript
   // GOOD - clean state for each test
   beforeEach(() => {
       database.clear()
       cache.reset()
   })

   afterEach(() => {
       cleanup()
   })
   ```
   ```python
   def setUp(self):
       self.database = create_test_database()

   def tearDown(self):
       self.database.clear()
   ```

5. **Mock Only External Dependencies** - Not internal collaborators
   ```
   MOCK these (external/slow/non-deterministic):
   - Database connections
   - HTTP clients / API calls
   - File system operations
   - System clock / timers
   - Random number generators
   - Email/SMS services

   DON'T MOCK these (internal/fast/deterministic):
   - The class you're testing (SUT)
   - Pure functions
   - Value objects
   - Internal helper classes (usually)
   - Simple data transformations
   ```

6. **Async Tests Must Await or Return Promise** - Otherwise assertions are ignored
   ```javascript
   // BAD - async test without await (assertions never run)
   test('fetches user', async () => {
       fetchUser(1).then(u => expect(u).toBeDefined())  // not awaited!
   })

   // GOOD - await async operations
   test('fetches user', async () => {
       const user = await fetchUser(1)
       expect(user).toBeDefined()
   })

   // GOOD - return promise (older style)
   test('fetches user', () => {
       return fetchUser(1).then(user => {
           expect(user).toBeDefined()
       })
   })
   ```
   ```python
   # Python - use pytest.mark.asyncio or similar
   @pytest.mark.asyncio
   async def test_fetches_user():
       user = await fetch_user(1)
       assert user is not None
   ```

### SHOULD (validator warns)

1. **Test Edge Cases** - null, empty, boundary values
   ```javascript
   // Always consider:
   describe('validateEmail', () => {
       test('returns false for null', () => { ... })
       test('returns false for undefined', () => { ... })
       test('returns false for empty string', () => { ... })
       test('returns false for whitespace only', () => { ... })
       test('returns true for valid email', () => { ... })
       test('returns false for missing @', () => { ... })
       test('returns false for missing domain', () => { ... })
   })
   ```
   ```
   Edge case checklist:
   - null / undefined / None / nil
   - Empty: "", [], {}, 0
   - Whitespace: "   ", "\t\n"
   - Boundaries: MAX_INT, MIN_INT, 0, -1
   - Single vs many: [x] vs [x, y, z, ...]
   - Unicode / special characters
   ```

2. **Test Error Paths** - Not just happy path
   ```javascript
   // BAD - only tests success
   test('login works', () => {
       expect(login('user', 'pass')).toBeTruthy()
   })

   // GOOD - tests failures too
   test('login succeeds with valid credentials', () => { ... })
   test('login throws AuthError for wrong password', () => {
       expect(() => login('user', 'wrong')).toThrow(AuthError)
   })
   test('login throws AuthError for unknown user', () => {
       expect(() => login('unknown', 'pass')).toThrow(AuthError)
   })
   test('login throws RateLimitError after 5 attempts', () => { ... })
   ```

3. **No Logic in Tests** - Avoid if/for/while in test body
   ```javascript
   // BAD - logic obscures what's being tested
   test('validates all items', () => {
       for (const item of items) {
           if (item.type === 'special') {
               expect(validate(item)).toBe(true)
           }
       }
   })

   // GOOD - explicit, readable test cases
   test('validates special item', () => {
       expect(validate(specialItem)).toBe(true)
   })

   test('validates regular item', () => {
       expect(validate(regularItem)).toBe(true)
   })

   // OK - parameterized tests (explicit cases)
   test.each([
       ['valid@email.com', true],
       ['invalid', false],
       ['', false],
   ])('validateEmail(%s) returns %s', (input, expected) => {
       expect(validateEmail(input)).toBe(expected)
   })
   ```

4. **Keep Tests Fast** - Unit tests < 100ms each
   ```
   Slow test causes:
   - Real database instead of mock
   - Real network calls
   - Hardcoded sleeps
   - Testing too much in one test
   - Missing test isolation (cleanup)

   If tests are slow, check:
   - Are you mocking external dependencies?
   - Are you using in-memory alternatives?
   - Is beforeAll/afterAll sharing setup?
   ```

5. **Test File Location Mirrors Source** - Easy to find tests for any file
   ```
   Pattern: source path → test path

   src/user/service.ts      → src/user/service.test.ts
   src/utils/format.js      → src/utils/format.test.js
   lib/auth/token.py        → lib/auth/token_test.py
   pkg/user/service.go      → pkg/user/service_test.go

   Benefits:
   - Instantly find tests for any file
   - Know if a file has tests (check for .test sibling)
   - Tests stay close to implementation
   - Easier code reviews (changes paired with tests)
   ```

### GUIDANCE (not mechanically checked)

1. **Test Behavior, Not Implementation**
   ```
   BAD: Tests break when you refactor internals
   - Testing private method order
   - Asserting on internal state
   - Checking mock call counts excessively

   GOOD: Tests survive refactoring
   - Testing inputs → outputs
   - Testing observable side effects
   - Testing public API contracts
   ```

2. **Treat Test Code as Production Code**
   ```
   Apply same standards:
   - Meaningful names (no data, result, temp)
   - No copy-paste (extract helpers)
   - Clear structure (AAA pattern)
   - No magic numbers
   ```

3. **If Testing is Hard, Design Needs Work**
   ```
   Hard to test usually means:
   - Too many dependencies (high coupling)
   - Mixed concerns (needs splitting)
   - Hidden dependencies (global state)
   - Complex setup (missing abstraction)

   The test is your first "user" of the code.
   If it's painful, real usage will be too.
   ```

4. **Tests are Documentation**
   ```
   Good tests answer:
   - What does this code do?
   - What are the edge cases?
   - What errors can occur?
   - How is it supposed to be used?

   Someone should understand the system
   by reading only the tests.
   ```

---

## Patterns

### Test Structure Template
```javascript
describe('ComponentOrModule', () => {
    // Setup shared across tests in this block
    let dependency;

    beforeEach(() => {
        dependency = createMockDependency()
    })

    afterEach(() => {
        cleanup()
    })

    describe('methodName', () => {
        test('should [expected behavior] when [condition]', () => {
            // Arrange
            const input = createInput()

            // Act
            const result = methodName(input)

            // Assert
            expect(result).toEqual(expected)
        })

        test('should throw [Error] when [condition]', () => {
            // Arrange
            const invalidInput = createInvalidInput()

            // Act & Assert
            expect(() => methodName(invalidInput))
                .toThrow(ExpectedError)
        })
    })
})
```

### Test Naming Convention
```
Pattern: [unit]_[scenario]_[expected]

Examples:
- UserService_GetById_ReturnsUser_WhenExists
- UserService_GetById_ReturnsNull_WhenNotFound
- UserService_Create_ThrowsValidationError_WhenEmailInvalid

Or BDD style:
- should return user when ID exists
- should return null when ID not found
- should throw ValidationError when email invalid
```

### Mocking Decision Tree
```
Should I mock this dependency?

Is it external? (DB, HTTP, filesystem, time)
  → YES: Mock it

Is it slow? (> 10ms)
  → Probably: Mock it

Is it non-deterministic? (random, time-based)
  → YES: Mock it

Is it the thing I'm testing?
  → NO: Never mock the SUT

Is it a simple value object or pure function?
  → NO: Use the real thing

Everything else?
  → Probably use real implementation
```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Enumerated Names | test1, test2 | Descriptive names |
| Empty Test | No assertions | Add expect/assert |
| Hardcoded Sleep | `sleep(1000)` | Wait for condition |
| Testing Privates | `obj._method()` | Test public API |
| Shared State | Mutable `beforeAll` state | Fresh state per test |
| Mocking SUT | Mock the thing you're testing | Mock dependencies only |
| Unawaited Async | `.then(expect(...))` not awaited | `await` or `return` promise |
| Try-Catch Swallow | `catch` hides assertion failure | Use `expect().toThrow()` |
| Giant Test | 100+ lines, many assertions | Split by behavior |
| Free Ride | Unrelated assertions together | One behavior per test |
| Inspector | Tests internal implementation | Test behavior |
| Mockery | More mocks than real code | Reduce dependencies |
| Local Hero | Works on your machine only | Mock externals |
| Generous Leftovers | Tests depend on order | Independent tests |
| Logic in Tests | if/for in test body | Explicit test cases |

---

## Research Sources

- [IBM Unit Testing Best Practices](https://www.ibm.com/think/insights/unit-testing-best-practices)
- [Unit Testing Anti-Patterns Full List](https://www.yegor256.com/2018/12/11/unit-testing-anti-patterns.html)
- [AAA Pattern - Semaphore](https://semaphore.io/blog/aaa-pattern-test-automation)
- [Software Testing Anti-patterns](https://blog.codepipes.com/testing/software-testing-antipatterns.html)
