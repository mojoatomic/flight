# Domain: GO Design

Go (Golang) development patterns. Covers error handling, naming, concurrency, and common footguns.

**Validation:** `go.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings

Add `// flight:ok` comment on the same line to suppress a specific check.
Use sparingly. Document why the suppression is acceptable.

```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Ignored Errors** - Do not discard errors using _ variables. Handle, return, or log them.
   ```
   // BAD
   result, _ := SomeFunction()
   // BAD
   _ = file.Close()
   // BAD
   data, _ = json.Marshal(obj)

   // GOOD
   result, err := SomeFunction()
   if err != nil {
       return fmt.Errorf("SomeFunction: %w", err)
   }
   
   // GOOD
   if err := file.Close(); err != nil {
       log.Printf("close file: %v", err)
   }
   
   ```

2. **Panic for Normal Error Handling** - Don't use panic for normal error handling. Use error returns.
   ```
   // BAD
   panic(err)
   // BAD
   panic(fmt.Errorf("invalid input: %v", x))
   // BAD
   panic("validation failed")

   // GOOD
   return fmt.Errorf("invalid input: %w", err)
   // GOOD
   if err != nil { return nil, err }
   ```

3. **math/rand for Security** - Do not use math/rand for cryptographic purposes. Use crypto/rand.
   ```
   // BAD
   import "math/rand"
   // BAD
   rand.Intn(100) // for token generation

   // GOOD
   import "crypto/rand"
   // GOOD
   rand.Read(bytes)
   // GOOD
   rand.Text()
   ```

4. **Defer in Loop** - Defer in loops can cause resource leaks - defers don't run until function returns
   ```
   // BAD
   for _, file := range files {
       f, _ := os.Open(file)
       defer f.Close()  // Won't close until function returns!
   }
   

   // GOOD
   for _, file := range files {
       func() {
           f, _ := os.Open(file)
           defer f.Close()
       }()
   }
   
   // GOOD
   for _, file := range files {
       f, _ := os.Open(file)
       // ... use f ...
       f.Close()
   }
   
   ```

5. **Goroutine without Lifetime Management** - Goroutines must have clear termination conditions to prevent leaks
   ```
   // BAD
   go func() {
       for {
           doWork()  // Runs forever, no way to stop
       }
   }()
   

   // GOOD
   go func() {
       for {
           select {
           case <-ctx.Done():
               return
           case work := <-workChan:
               process(work)
           }
       }
   }()
   
   ```

6. **Unbuffered Channel in Select with Default** - Sending to unbuffered channel in select with default may silently drop messages
   ```
   // BAD
   select {
   case ch <- msg:  // May be skipped!
   default:
       // Message silently dropped
   }
   

   // GOOD
   select {
   case ch <- msg:
   case <-ctx.Done():
       return ctx.Err()
   }
   
   ```

7. **Nil Map Write** - Writing to a nil map causes a panic
   ```
   // BAD
   var m map[string]int
   m["key"] = 1  // panic: assignment to entry in nil map
   

   // GOOD
   var m map[string]int = make(map[string]int)
   // GOOD
   m := make(map[string]int)
   // GOOD
   m := map[string]int{}
   ```

8. **Range Loop Variable Capture (Pre-Go 1.22)** - Loop variable capture in goroutines/closures - all share the same variable
   ```
   // BAD
   for _, v := range values {
       go func() {
           fmt.Println(v)  // All goroutines see the same v!
       }()
   }
   

   // GOOD
   for _, v := range values {
       v := v  // Shadow the variable (pre-1.22 fix)
       go func() {
           fmt.Println(v)
       }()
   }
   
   // GOOD
   for _, v := range values {
       go func(val string) {
           fmt.Println(val)
       }(v)
   }
   
   ```

### MUST (validator will reject)

1. **MixedCaps Naming** - Go uses MixedCaps or mixedCaps, not underscores
   ```
   // BAD
   func get_user_name() string
   // BAD
   var user_count int
   // BAD
   const max_size = 100

   // GOOD
   func getUserName() string
   // GOOD
   var userCount int
   // GOOD
   const maxSize = 100
   ```

2. **Initialisms Must Be Consistent Case** - Initialisms like URL, HTTP, ID should be all caps or all lower
   ```
   // BAD
   type HttpClient struct
   // BAD
   func GetUserId() int
   // BAD
   var xmlHttpRequest

   // GOOD
   type HTTPClient struct
   // GOOD
   func GetUserID() int
   // GOOD
   var xmlHTTPRequest
   ```

3. **Exported Names Must Have Doc Comments** - All exported names should have doc comments
   ```
   // BAD
   func ProcessData(d []byte) error {
   

   // GOOD
   // ProcessData validates and transforms the input bytes.
   func ProcessData(d []byte) error {
   
   ```

4. **Context as First Parameter** - Functions using Context should accept it as their first parameter
   ```
   // BAD
   func DoWork(id int, ctx context.Context) error
   // BAD
   func Process(data []byte, ctx context.Context, opts Options) error

   // GOOD
   func DoWork(ctx context.Context, id int) error
   // GOOD
   func Process(ctx context.Context, data []byte, opts Options) error
   ```

5. **Error Variable Naming** - Error variables should be named err or have Err prefix for package-level
   ```
   // BAD
   var NotFoundError = errors.New("not found")
   // BAD
   var ValidationError = errors.New("invalid")

   // GOOD
   var ErrNotFound = errors.New("not found")
   // GOOD
   var ErrValidation = errors.New("invalid")
   ```

6. **Package Names Must Be Lowercase** - Package names should be lowercase, single words without underscores
   ```
   // BAD
   package myPackage
   // BAD
   package my_utils
   // BAD
   package MyService

   // GOOD
   package mypackage
   // GOOD
   package utils
   // GOOD
   package service
   ```

7. **Receiver Name Consistency** - Receiver names should be short and consistent across methods
   ```
   // BAD
   func (this *Client) Connect() error
   // BAD
   func (self *Server) Listen() error
   // BAD
   func (me User) Name() string

   // GOOD
   func (c *Client) Connect() error
   // GOOD
   func (s *Server) Listen() error
   // GOOD
   func (u User) Name() string
   ```

8. **Error Strings Lowercase** - Error strings should not be capitalized or end with punctuation
   ```
   // BAD
   errors.New("Something bad happened.")
   // BAD
   fmt.Errorf("Invalid input: %v", x)

   // GOOD
   errors.New("something bad happened")
   // GOOD
   fmt.Errorf("invalid input: %v", x)
   ```

9. **Interface in Consumer Package** - Interfaces belong in the package that uses them, not the implementing package

   > From Go Code Review Comments: "Go interfaces generally belong in the package
that uses values of the interface type, not the package that implements those values."

   ```
   // BAD
   // In package producer
   type Thinger interface { Thing() bool }
   type defaultThinger struct{}
   func NewThinger() Thinger { return defaultThinger{} }
   

   // GOOD
   // In package producer - return concrete type
   type Thinger struct{}
   func NewThinger() *Thinger { return &Thinger{} }
   
   // In package consumer - define interface there
   type ThingDoer interface { Thing() bool }
   
   ```

### SHOULD (validator warns)

1. **Wrap Errors with Context** - Errors should be wrapped with context using fmt.Errorf and %w
   ```
   // BAD
   if err != nil {
       return err  // No context
   }
   

   // GOOD
   if err != nil {
       return fmt.Errorf("process user %d: %w", id, err)
   }
   
   ```

2. **Table-Driven Tests** - Use table-driven tests for multiple test cases
   ```
   func TestAdd(t *testing.T) {
       tests := []struct {
           name     string
           a, b     int
           expected int
       }{
           {"positive", 1, 2, 3},
           {"negative", -1, -2, -3},
           {"zero", 0, 0, 0},
       }
       for _, tt := range tests {
           t.Run(tt.name, func(t *testing.T) {
               if got := Add(tt.a, tt.b); got != tt.expected {
                   t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, got, tt.expected)
               }
           })
       }
   }
   ```

3. **Prefer var for Zero Values** - Use var declaration for zero-value slices and maps
   ```
   // BAD
   t := []string{}
   // BAD
   s := make([]int, 0)

   // GOOD
   var t []string
   // GOOD
   s := make([]int, 0, expectedSize)  // OK if capacity needed
   ```

4. **Synchronous Functions Preferred** - Prefer synchronous functions over asynchronous ones
   ```
   // BAD
   func Process(data []byte, result chan<- Result) {
       go func() {
           // process...
           result <- res
       }()
   }
   

   // GOOD
   func Process(data []byte) (Result, error) {
       // process...
       return res, nil
   }
   // Caller adds concurrency if needed:
   go func() { result <- Process(data) }()
   
   ```

5. **Project Structure** - Follow standard Go project layout conventions
   ```
   myproject/
     cmd/
       myapp/
         main.go
     internal/
       server/
         server.go
       database/
         db.go
     go.mod
   ```

6. **Use t.Helper in Test Helpers** - Test helper functions should call t.Helper()
   ```
   // BAD
   func assertEqual(t *testing.T, got, want int) {
       if got != want {
           t.Errorf("got %d; want %d", got, want)
       }
   }
   

   // GOOD
   func assertEqual(t *testing.T, got, want int) {
       t.Helper()
       if got != want {
           t.Errorf("got %d; want %d", got, want)
       }
   }
   
   ```

7. **Avoid Global State** - Avoid package-level variables; pass dependencies explicitly
   ```
   // BAD
   var db *sql.DB
   var config Config
   
   func GetUser(id int) (*User, error) {
       return db.Query(...)  // Uses global
   }
   

   // GOOD
   type Service struct {
       db     *sql.DB
       config Config
   }
   
   func (s *Service) GetUser(id int) (*User, error) {
       return s.db.Query(...)
   }
   
   ```

8. **Mutex Field Naming** - Mutex fields should be named mu and placed above the fields they protect
   ```
   // BAD
   type Cache struct {
       data map[string]string
       lock sync.Mutex
   }
   

   // GOOD
   type Cache struct {
       mu   sync.Mutex
       data map[string]string  // protected by mu
   }
   
   ```

9. **Check Errors Before Using Defer** - Check resource creation errors before deferring cleanup
   ```
   // BAD
   f, _ := os.Open(path)
   defer f.Close()  // May panic if f is nil
   

   // GOOD
   f, err := os.Open(path)
   if err != nil {
       return err
   }
   defer f.Close()
   
   ```

10. **Indent Error Flow** - Keep normal code path at minimal indentation, handle errors first
   ```
   // BAD
   if err == nil {
       // normal code
   } else {
       return err
   }
   

   // GOOD
   if err != nil {
       return err
   }
   // normal code
   
   ```

11. **Avoid Init Functions** - Prefer explicit initialization over init() functions
   ```
   // BAD
   func init() {
       db = connectDB()
       config = loadConfig()
   }
   

   // GOOD
   func main() {
       db, err := connectDB()
       config, err := loadConfig()
   }
   
   ```

12. **Use Meaningful Test Names** - Test names should describe what is being tested
   ```
   // BAD
   func TestProcess(t *testing.T)
   // BAD
   func Test1(t *testing.T)

   // GOOD
   func TestProcess_ValidInput_ReturnsSuccess(t *testing.T)
   // GOOD
   func TestProcess_EmptyInput_ReturnsError(t *testing.T)
   ```

### GUIDANCE (not mechanically checked)

1. **Accept Interfaces, Return Structs** - Functions should accept interfaces and return concrete types

   > This pattern maximizes flexibility for callers while keeping the API
simple. New methods can be added to returned types without breaking changes.

   ```
   // BAD
   func NewUserService() UserServiceInterface {
       return &userService{}
   }
   

   // GOOD
   func NewUserService() *UserService {
       return &UserService{}
   }
   
   // Consumer defines the interface they need
   type UserFinder interface {
       FindUser(id int) (*User, error)
   }
   
   ```

2. **Small, Focused Packages** - Packages should be small and focused on a single responsibility

   > Avoid utility/common/misc packages. Each package should have a clear purpose
that can be explained in one sentence.

   ```
   // BAD
   package utils  // What does this do?
   // BAD
   package common  // Too vague
   // BAD
   package helpers  // No clear purpose

   // GOOD
   package auth  // Authentication logic
   // GOOD
   package cache  // Caching functionality
   // GOOD
   package httputil  // HTTP utilities
   ```

3. **Make Zero Values Useful** - Design types so their zero value is immediately useful

   > From Effective Go: "The zero value of a sync.Mutex is a valid, unlocked mutex.
This means you can use mutexes without explicit initialization."

   ```
   type Counter struct {
       mu    sync.Mutex
       count int  // zero value (0) is valid
   }
   
   func (c *Counter) Increment() {
       c.mu.Lock()  // Works without initialization
       c.count++
       c.mu.Unlock()
   }
   ```

4. **Don't Stutter** - Avoid repeating the package name in type/function names

   > From Effective Go: "Since everything in a package is imported with the
package name, don't repeat it in identifiers."

   ```
   // BAD
   chubby.ChubbyFile
   // BAD
   http.HTTPClient
   // BAD
   user.UserService

   // GOOD
   chubby.File
   // GOOD
   http.Client
   // GOOD
   user.Service
   ```

5. **Keep Concurrency Localized** - Hide concurrency details inside packages; expose synchronous APIs

   > Let callers add concurrency if needed. It's easier to add concurrency
at the call site than to remove it from a library.

   ```
   // BAD
   // Library forces concurrency on callers
   func ProcessAll(items []Item, resultCh chan<- Result) {
       for _, item := range items {
           go process(item, resultCh)
       }
   }
   

   // GOOD
   // Library is synchronous
   func Process(item Item) (Result, error) {
       // ...
   }
   
   // Caller adds concurrency if needed
   for _, item := range items {
       go func(i Item) {
           result, _ := Process(i)
           resultCh <- result
       }(item)
   }
   
   ```

6. **Use Functional Options for Complex APIs** - Use functional options pattern for APIs with many optional parameters

   > Functional options provide a clean API that's easy to extend without
breaking changes.

   ```
   type Option func(*Server)
   
   func WithTimeout(d time.Duration) Option {
       return func(s *Server) { s.timeout = d }
   }
   
   func WithLogger(l Logger) Option {
       return func(s *Server) { s.logger = l }
   }
   
   func NewServer(addr string, opts ...Option) *Server {
       s := &Server{addr: addr}
       for _, opt := range opts {
           opt(s)
       }
       return s
   }
   
   // Usage
   srv := NewServer(":8080",
       WithTimeout(30*time.Second),
       WithLogger(logger),
   )
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Ignored errors | result, _ := Foo() | Handle, return, or log all errors |
| Panic for errors | panic(err) | Return errors instead |
| math/rand for crypto | import "math/rand" | Use crypto/rand for security |
| Defer in loop | for { defer f.Close() } | Use closure or explicit close |
| Goroutine leak | go func() { for {} }() | Use context for cancellation |
| snake_case names | func get_user() | Use MixedCaps: getUser |
| this/self receiver | func (this *T) | Use short name: func (t *T) |
| Global state | var db *sql.DB | Pass dependencies explicitly |
| Bare error returns | return err | return fmt.Errorf("context: %w", err) |
| Empty slice literal | s := []int{} | var s []int |
| Interface in producer | func New() Interface | func New() *ConcreteType |
| Stuttering names | user.UserService | user.Service |
