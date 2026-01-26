# Domain: Testing Design

Universal unit test patterns. Language-agnostic, framework-agnostic. Prevents weak tests across JavaScript, Python, Go, and Java.


**Validation:** `testing.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Enumerated Test Names** - Never use enumerated test names (test1, test2, testA). They provide no information about what the test verifies. Use descriptive names that describe the behavior being tested.

   ```
   // BAD
   test('test1', () => { ... })
   // BAD
   def test1(self): ...
   // BAD
   func Test1(t *testing.T) { ... }

   // GOOD
   test('should return user when valid ID provided', () => { ... })
   // GOOD
   def test_returns_empty_list_when_no_matches(self): ...
   // GOOD
   func TestUserService_ReturnsError_WhenNotFound(t *testing.T) { ... }
   ```

2. **Enumerated Test Names (JavaScript)** - Never use enumerated test names (test1, test2, testA). They provide no information about what the test verifies.


3. **Enumerated Test Names (Python)** - Never use enumerated test names (test1, test2, testA). They provide no information about what the test verifies.


4. **Enumerated Test Names (TypeScript)** - Never use enumerated test names (test1, test2, testA). They provide no information about what the test verifies.


5. **Empty Test Bodies** - Never write tests without assertions. Empty tests pass but prove nothing. Every test must have at least one assertion.

   ```
   // BAD
   it('works', () => {})
   // BAD
   it('handles edge case', () => { doSomething() })  // no assertion!
   // BAD
   def test_something(self): pass

   // GOOD
   it('works', () => { expect(result).toBe(true) })
   // GOOD
   def test_something(self): self.assertEqual(result, expected)
   ```

6. **Empty Test Bodies (Python)** - Never write tests with only pass statement. Empty tests prove nothing.


7. **Hardcoded Sleep/Delays** - Never use hardcoded sleep/delays in tests. They make tests slow and flaky. Use waitFor, mock timers, or event-based waiting instead.

   ```
   // BAD
   await sleep(1000)
   // BAD
   time.sleep(2)
   // BAD
   Thread.sleep(500)
   // BAD
   await new Promise(r => setTimeout(r, 100))

   // GOOD
   await waitFor(() => expect(element).toBeVisible())
   // GOOD
   mock_time.advance(seconds=2)
   // GOOD
   eventually { assert condition }
   ```

8. **Sleep Function Calls (JavaScript)** - Never call sleep() directly in tests. Use waitFor or mock timers.


9. **Promise setTimeout (JavaScript)** - Never use new Promise with setTimeout for delays in tests.


10. **time.sleep Calls (Python)** - Never use time.sleep() in tests. Use mock timers or event-based waiting.


11. **Sleep Function Calls (TypeScript)** - Never call sleep() directly in tests. Use waitFor or mock timers.


12. **Promise setTimeout (TypeScript)** - Never use new Promise with setTimeout for delays in tests.


13. **Testing Private Methods Directly** - Never test private methods directly. It breaks encapsulation and couples tests to implementation. Test through the public interface.

   ```
   // BAD
   expect(obj._privateMethod()).toBe(...)
   // BAD
   expect(obj.__private_attr).toBe(...)
   // BAD
   assert obj._internal_value == expected

   // GOOD
   expect(obj.publicMethod()).toBe(...)
   // GOOD
   // Private behavior is tested implicitly through public API
   ```

14. **Testing Private Members (JavaScript)** - Never test private methods or properties (_prefixed) in expect().


15. **Testing Private Members (Python)** - Never test private methods or attributes (_prefixed) in assert.


16. **Testing Private Members (TypeScript)** - Never test private methods or properties (_prefixed) in expect().


17. **Unawaited Async Assertions** - Never leave async assertions unawaited. The promise is never awaited and the test passes even if the assertion fails. Always await or return the promise.

   ```
   // BAD
   test('fetches data', () => {
     fetchData().then(data => expect(data).toBeDefined())
   })
   

   // GOOD
   test('fetches data', async () => {
     const data = await fetchData()
     expect(data).toBeDefined()
   })
   
   // GOOD
   test('fetches data', () => {
     return fetchData().then(data => expect(data).toBeDefined())
   })
   
   ```

18. **Unawaited .then() Callbacks (JavaScript)** - Never use .then() with callback in tests - use async/await instead.


19. **Unawaited .then() Callbacks (TypeScript)** - Never use .then() with callback in tests - use async/await instead.


### SHOULD (validator warns)

1. **Shared Mutable State Between Tests** - Avoid shared mutable state between tests. Tests that modify shared state can cause order-dependent failures. Each test should own its state.


   > Detects beforeAll with top-level let variables - a common pattern for shared mutable state.
   ```
   // BAD
   let sharedUser;
   beforeAll(() => { sharedUser = createUser() })
   test('modifies user', () => { sharedUser.name = 'changed' })
   test('reads user', () => { expect(sharedUser.name).toBe('original') }) // FAILS!
   

   // GOOD
   test('test1', () => {
     const user = createUser()
     user.name = 'changed'
     expect(user.name).toBe('changed')
   })
   
   ```

2. **Try-Catch Swallowing Failures** - Avoid try-catch blocks that can swallow test failures. If no error is thrown, the catch never runs and the test passes incorrectly. Use expect().toThrow() or expect().rejects instead.

   ```
   // BAD
   test('throws error', () => {
     try {
       doThing()
     } catch (e) {
       expect(e).toBeDefined()  // never reached if no error!
     }
   })
   

   // GOOD
   test('throws error', () => {
     expect(() => doThing()).toThrow()
   })
   
   // GOOD
   test('rejects with error', async () => {
     await expect(asyncDoThing()).rejects.toThrow(Error)
   })
   
   ```

3. **Non-Descriptive Test Names** - Test names should describe the behavior being tested. Names like 'test', 'works', or 'it' provide no useful information.

   ```
   // BAD
   test('test', () => { ... })
   // BAD
   test('works', () => { ... })
   // BAD
   it('it', () => { ... })

   // GOOD
   test('should return user when valid ID provided', () => { ... })
   // GOOD
   test('calculateTotal returns zero for empty cart', () => { ... })
   ```

4. **Logic in Tests** - Avoid if/for/while logic in test bodies. Logic obscures what's being tested and can hide bugs. Use explicit test cases or parameterized tests instead.

   ```
   // BAD
   test('validates all items', () => {
     for (const item of items) {
       if (item.type === 'special') {
         expect(validate(item)).toBe(true)
       }
     }
   })
   

   // GOOD
   test('validates special item', () => {
     expect(validate(specialItem)).toBe(true)
   })
   
   // GOOD
   test.each([
     ['valid@email.com', true],
     ['invalid', false],
   ])('validateEmail(%s) returns %s', (input, expected) => {
     expect(validateEmail(input)).toBe(expected)
   })
   
   ```

5. **Logic in Tests (JavaScript)** - Avoid if/for/while in test bodies. Use test.each for parameterized tests.


6. **Logic in Tests (Python)** - Avoid if/for/while in test bodies. Use pytest.mark.parametrize.


7. **Logic in Tests (TypeScript)** - Avoid if/for/while in test bodies. Use test.each for parameterized tests.


### GUIDANCE (not mechanically checked)

1. **Follow AAA Pattern** - Follow the Arrange, Act, Assert pattern for clear test structure.


2. **One Behavior Per Test** - Test a single logical behavior per test case. Multiple unrelated assertions make it hard to identify what failed and why.


3. **Test Independence** - Tests must not depend on execution order. Use beforeEach/afterEach to ensure clean state for each test.


4. **Mock Only External Dependencies** - Mock external, slow, or non-deterministic dependencies. Don't mock the system under test or simple internal collaborators.


5. **Test Edge Cases** - Always test edge cases: null, empty, boundary values, error conditions.


6. **Test Error Paths** - Don't just test the happy path. Test error conditions, invalid inputs, and failure scenarios.


7. **Test File Location Mirrors Source** - Place test files alongside or mirroring source files for easy discovery.


8. **Test Behavior Not Implementation** - Test observable behavior, not internal implementation details. Tests should survive refactoring.


9. **Treat Test Code as Production Code** - Apply the same quality standards to test code: meaningful names, no copy-paste, clear structure, no magic numbers.


10. **If Testing is Hard, Design Needs Work** - Difficulty testing is a design smell. The test is your first "user" of the code.


11. **Tests are Documentation** - Good tests serve as executable documentation. Someone should understand the system by reading only the tests.


12. **Test Structure Template** - Standard template for organizing test files with describe blocks, setup/teardown, and clear test cases.


13. **Test Naming Convention** - Follow consistent test naming conventions that describe the unit, scenario, and expected result.


14. **Mocking Decision Tree** - Decision framework for when to mock dependencies.


15. **Async Tests Must Await or Return Promise** - Async tests must await operations or return the promise. Otherwise assertions are ignored and tests pass incorrectly.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Enumerated Names |  | Descriptive names |
| Empty Test |  | Add expect/assert |
| Hardcoded Sleep |  | Wait for condition |
| Testing Privates |  | Test public API |
| Shared State |  | Fresh state per test |
| Mocking SUT |  | Mock dependencies only |
| Unawaited Async |  | await or return promise |
| Try-Catch Swallow |  | Use expect().toThrow() |
| Giant Test |  | Split by behavior |
| Free Ride |  | One behavior per test |
| Inspector |  | Test behavior |
| Mockery |  | Reduce dependencies |
| Local Hero |  | Mock externals |
| Generous Leftovers |  | Independent tests |
| Logic in Tests |  | Explicit test cases |
