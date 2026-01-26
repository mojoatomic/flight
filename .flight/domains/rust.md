# Domain: RUST Design

Rust development patterns covering error handling, ownership, memory safety, concurrency, and idiomatic code. Catches common AI mistakes and anti-patterns.


**Validation:** `rust.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Unsafe Block Without Safety Comment** - All unsafe blocks must have a SAFETY comment explaining why the unsafe code is sound. Document what invariants must be upheld.

   ```
   // BAD
   unsafe {
       ptr::write(dest, value);
   }
   

   // GOOD
   // SAFETY: dest is valid and properly aligned, checked in caller
   unsafe {
       ptr::write(dest, value);
   }
   
   ```

2. **mem::transmute Usage** - Avoid mem::transmute - it's extremely dangerous and almost never needed. Use safer alternatives like from_ne_bytes, as casts, or pointer casts.

   ```
   // BAD
   let x: u32 = unsafe { mem::transmute(bytes) };
   // BAD
   let ptr: *const T = mem::transmute(ref_t);

   // GOOD
   let x = u32::from_ne_bytes(bytes);
   // GOOD
   let ptr: *const T = ref_t as *const T;
   // GOOD
   let ptr = ptr.cast::<T>();
   ```

3. **Panic in Library Code** - Libraries should not panic on recoverable errors. Return Result or Option instead. Panics should only occur for programmer errors (invariant violations).

   ```
   // BAD
   panic!("invalid input: {}", x);
   // BAD
   panic!("file not found");
   // BAD
   todo!("implement later");  // in production code

   // GOOD
   return Err(Error::InvalidInput(x));
   // GOOD
   return None;
   // GOOD
   unreachable!("checked above")  // OK for true invariants
   ```

4. **.unwrap() in Production Code** - Do not use .unwrap() in production code. Use ?, .expect() with a message, or proper error handling. Unwrap hides the failure reason.

   ```
   // BAD
   let value = map.get("key").unwrap();
   // BAD
   let file = File::open(path).unwrap();
   // BAD
   let num: i32 = s.parse().unwrap();

   // GOOD
   let value = map.get("key").ok_or(Error::KeyNotFound)?;
   // GOOD
   let file = File::open(path)?;
   // GOOD
   let num: i32 = s.parse().expect("validated above");
   ```

5. **.expect() Without Descriptive Message** - When using .expect(), always provide a descriptive message explaining why the value should be present. Empty or generic messages defeat the purpose.

   ```
   // BAD
   .expect("")
   // BAD
   .expect("failed")
   // BAD
   .expect("error")

   // GOOD
   .expect("config file validated during startup")
   // GOOD
   .expect("mutex poisoned - concurrent panic occurred")
   // GOOD
   .expect("internal invariant: queue always has at least one item")
   ```

6. **Raw Pointer Arithmetic Without Bounds Check** - Raw pointer arithmetic (offset, add, sub) requires bounds checking. Going out of bounds is undefined behavior even without dereferencing.

   ```
   // BAD
   unsafe {
       let ptr = arr.as_ptr().add(index);  // No bounds check!
   }
   

   // GOOD
   assert!(index < arr.len());
   // SAFETY: bounds checked above
   unsafe {
       let ptr = arr.as_ptr().add(index);
   }
   
   ```

7. **mem::forget Without Clear Justification** - mem::forget prevents destructors from running, causing resource leaks. Almost always indicates a design problem. Use ManuallyDrop if needed.

   ```
   // BAD
   mem::forget(mutex_guard);  // Keeps lock held forever!
   // BAD
   mem::forget(file);  // File descriptor leaked

   // GOOD
   let _ = ManuallyDrop::new(value);  // Explicit, searchable
   // GOOD
   std::mem::forget(std::mem::ManuallyDrop::new(value));  // If truly needed
   ```

8. **Mutex Held Across Await Point** - Holding a std::sync::Mutex guard across an .await causes deadlocks. Use tokio::sync::Mutex for async code or restructure to drop before await.


   > std::sync::Mutex is not async-aware. If a task yields while holding the lock,
it blocks the executor thread, preventing other tasks from releasing the lock.

   ```
   // BAD
   let guard = mutex.lock().unwrap();
   some_async_fn().await;  // Deadlock risk!
   drop(guard);
   

   // GOOD
   {
       let guard = mutex.lock().unwrap();
       // Use guard
   }  // Dropped here
   some_async_fn().await;
   
   // GOOD
   let guard = async_mutex.lock().await;  // Use tokio::sync::Mutex
   
   ```

### MUST (validator will reject)

1. **Use ? Operator for Error Propagation** - Prefer the ? operator over match/unwrap chains for error propagation. It's more concise and idiomatic.

   ```
   // BAD
   let file = match File::open(path) {
       Ok(f) => f,
       Err(e) => return Err(e),
   };
   

   // GOOD
   let file = File::open(path)?;
   ```

2. **Clone Abuse - Cloning to Satisfy Borrow Checker** - Do not clone just to satisfy the borrow checker. This indicates a design issue. Restructure code, use references, or use Rc/Arc if shared ownership is needed.

   ```
   // BAD
   process(&data.clone());  // Clone then borrow - wasteful
   // BAD
   vec.push(item.clone());  // When item could be moved

   // GOOD
   process(&data);
   // GOOD
   vec.push(item);  // Move instead of clone
   // GOOD
   let shared = Arc::new(data);  // If truly needs sharing
   ```

3. **String Parameter When &str Would Work** - Function parameters should use &str instead of String or &String when the function only reads the string. This accepts both String and &str.

   ```
   // BAD
   fn greet(name: &String) { ... }
   // BAD
   fn greet(name: String) { println!("{}", name); }  // Only reads

   // GOOD
   fn greet(name: &str) { ... }
   // GOOD
   fn take_ownership(name: String) { self.name = name; }  // Stores it
   ```

4. **Vec Parameter When Slice Would Work** - Function parameters should use &[T] instead of &Vec<T> when the function only reads the vector. Slices are more general.

   ```
   // BAD
   fn sum(numbers: &Vec<i32>) -> i32 { ... }

   // GOOD
   fn sum(numbers: &[i32]) -> i32 { ... }
   ```

5. **Box<T> When T Would Work** - Avoid unnecessary Box<T> allocations. Use Box only for recursive types, trait objects, or when you need stable addresses.

   ```
   // BAD
   let names: Box<Vec<String>> = Box::new(vec![]);
   // BAD
   struct Foo { data: Box<String> }

   // GOOD
   let names: Vec<String> = vec![];
   // GOOD
   struct Foo { data: String }
   ```

6. **println! in Library Code** - Libraries should not use println!/print!/eprintln! for output. Use the log or tracing crate for configurable logging.

   ```
   // BAD
   println!("Processing item: {}", item);
   // BAD
   eprintln!("Warning: {}", msg);

   // GOOD
   log::info!("Processing item: {}", item);
   // GOOD
   tracing::warn!("Warning: {}", msg);
   // GOOD
   debug!("Debug info: {:?}", data);
   ```

7. **Blocking Operations in Async Context** - Do not perform blocking I/O or CPU-intensive work in async functions. Use spawn_blocking or async alternatives.


   > Blocking operations in async code block the entire executor thread,
preventing other tasks from making progress.

   ```
   // BAD
   async fn read_file(path: &str) -> String {
       std::fs::read_to_string(path).unwrap()  // Blocks!
   }
   

   // GOOD
   async fn read_file(path: &str) -> String {
       tokio::fs::read_to_string(path).await.unwrap()
   }
   
   // GOOD
   async fn heavy_compute() -> Result<()> {
       tokio::task::spawn_blocking(|| cpu_intensive_work()).await?
   }
   
   ```

8. **Missing** - Functions that return values that should not be ignored (Results, important computations) should be marked #[must_use].


   > #[must_use] generates a warning when the return value is discarded.
Essential for Result-returning functions and pure functions.

   ```
   // BAD
   pub fn validate(input: &str) -> bool {
       // Caller might forget to check return value
   }
   

   // GOOD
   #[must_use]
   pub fn validate(input: &str) -> bool {
       // Compiler warns if result is ignored
   }
   
   ```

9. **Derive Common Traits** - Public types should derive common traits: Debug, Clone, PartialEq where appropriate. At minimum, all public types should implement Debug.


   > From Rust API Guidelines (C-COMMON-TRAITS): Types should eagerly implement
common traits like Debug, Clone, Eq, PartialEq, Hash, Default.

   ```
   // BAD
   pub struct Config {
       pub name: String,
   }
   

   // GOOD
   #[derive(Debug, Clone, PartialEq)]
   pub struct Config {
       pub name: String,
   }
   
   ```

### SHOULD (validator warns)

1. **Use Iterators Over Manual Loops** - Prefer iterator methods (map, filter, fold) over manual for loops when appropriate. They're often more readable and optimizable.

   ```
   // BAD
   let mut result = Vec::new();
   for i in 0..items.len() {
       result.push(items[i] * 2);
   }
   

   // GOOD
   let result: Vec<_> = items.iter().map(|x| x * 2).collect();
   
   ```

2. **Use if let for Single-Arm Matches** - Use if let instead of match when you only care about one pattern. It's more concise and clearly expresses intent.

   ```
   // BAD
   match option {
       Some(x) => do_something(x),
       _ => {},
   }
   

   // GOOD
   if let Some(x) = option {
       do_something(x);
   }
   
   ```

3. **Implement Default for Types with Obvious Defaults** - Types with sensible default values should implement the Default trait. This enables ..Default::default() syntax and integration with serde.


   > From Rust API Guidelines: Types should implement Default when there's
an obvious default value. Use #[derive(Default)] when possible.

   ```
   // BAD
   impl Config {
       pub fn new() -> Self {
           Config { timeout: 30, retries: 3 }
       }
   }
   

   // GOOD
   #[derive(Default)]
   struct Config {
       timeout: u32,
       retries: u32,
   }
   // Or implement Default if non-trivial defaults needed
   
   ```

4. **Use Builder Pattern for Complex Construction** - For types with many optional parameters, use the builder pattern instead of constructors with many arguments.


   > From Rust API Guidelines (C-BUILDER): Builders enable construction of
complex values without remembering argument order or providing dummy values.

   ```
   // BAD
   Server::new("localhost", 8080, true, false, 30, None, Some(logger))
   

   // GOOD
   Server::builder()
       .host("localhost")
       .port(8080)
       .tls(true)
       .timeout(30)
       .logger(logger)
       .build()
   
   ```

5. **Avoid Wildcard Imports** - Avoid use foo::* imports in production code. They make it unclear where names come from and can cause conflicts when dependencies update.

   ```
   // BAD
   use std::collections::*;
   // BAD
   use crate::models::*;

   // GOOD
   use std::collections::{HashMap, HashSet};
   // GOOD
   use crate::models::{User, Post};
   // GOOD
   use crate::prelude::*;  // OK for curated preludes
   ```

6. **Use snake_case for Functions and Variables** - Rust conventions require snake_case for functions, methods, variables, and modules. CamelCase is for types and traits only.

   ```
   // BAD
   let userName = "alice";
   // BAD
   fn getUserById(id: i32) -> User

   // GOOD
   let user_name = "alice";
   // GOOD
   fn get_user_by_id(id: i32) -> User
   ```

7. **Avoid Large Stack Allocations** - Avoid large structs (>1KB) on the stack. Use Box for large data to prevent stack overflow in deeply recursive code.

   ```
   // BAD
   let buffer: [u8; 1_000_000] = [0; 1_000_000];

   // GOOD
   let buffer: Box<[u8; 1_000_000]> = Box::new([0; 1_000_000]);
   // GOOD
   let buffer: Vec<u8> = vec![0; 1_000_000];
   ```

8. **Prefer From/Into Over as for Type Conversions** - Use From/Into traits for type conversions instead of 'as' casts when possible. From/Into are checked and more explicit about conversion intent.

   ```
   // BAD
   let small = big_number as u8;  // Silently truncates

   // GOOD
   let small: u8 = big_number.try_into()?;
   // GOOD
   let small = u8::try_from(big_number).map_err(|_| Error::Overflow)?;
   ```

9. **Return Result from Functions That Can Fail** - Functions that can fail should return Result, not panic or return sentinel values. Let callers decide how to handle failures.


   > Rust's error handling is based on Result. Functions should return Result
for recoverable errors, making error handling explicit.

   ```
   // BAD
   fn parse_config(path: &str) -> Config {
       // Returns default on error - hides failures
       fs::read_to_string(path)
           .map(|s| toml::from_str(&s).unwrap_or_default())
           .unwrap_or_default()
   }
   

   // GOOD
   fn parse_config(path: &str) -> Result<Config, ConfigError> {
       let content = fs::read_to_string(path)?;
       let config = toml::from_str(&content)?;
       Ok(config)
   }
   
   ```

10. **Use Cow for Flexible String/Slice Ownership** - Use Cow<str> or Cow<[T]> when a function might need to either borrow or own data, avoiding unnecessary clones.


   > Cow (Clone-on-Write) lets you return borrowed data when possible and
only allocate when necessary. Useful for optimization.

   ```
   // BAD
   fn process(s: &str) -> String {
       if s.contains("bad") {
           s.replace("bad", "good")  // Always allocates
       } else {
           s.to_string()  // Unnecessary allocation
       }
   }
   

   // GOOD
   fn process(s: &str) -> Cow<str> {
       if s.contains("bad") {
           Cow::Owned(s.replace("bad", "good"))
       } else {
           Cow::Borrowed(s)  // No allocation
       }
   }
   
   ```

### GUIDANCE (not mechanically checked)

1. **Error Type Design - thiserror vs anyhow** - Libraries should define structured error types using thiserror. Applications can use anyhow for convenient error handling. Don't mix them incorrectly.


   > thiserror: For libraries. Creates typed errors that callers can match on.
anyhow: For applications. Convenient context addition, no typing overhead.
Never use anyhow::Error in a library's public API.

   ```
   // Library (using thiserror)
   #[derive(Debug, thiserror::Error)]
   pub enum ParseError {
       #[error("invalid syntax at line {line}")]
       Syntax { line: usize },
       #[error("io error: {0}")]
       Io(#[from] std::io::Error),
   }
   // Application (using anyhow)
   use anyhow::{Context, Result};
   
   fn main() -> Result<()> {
       let config = load_config()
           .context("failed to load config")?;
       Ok(())
   }
   ```

2. **Prefer Composition Over Inheritance** - Rust doesn't have inheritance. Use composition, traits, and generics instead of trying to simulate inheritance patterns.


   > Compose types by including them as fields. Use traits for shared behavior.
Avoid DerefMut abuse to simulate inheritance.

   ```
   // BAD
   // Don't try to simulate inheritance
   struct Child {
       parent: Parent,
   }
   impl Deref for Child {
       type Target = Parent;
       fn deref(&self) -> &Parent { &self.parent }
   }
   

   // GOOD
   // Use traits for shared behavior
   trait Drawable {
       fn draw(&self);
   }
   
   struct Circle { radius: f64 }
   impl Drawable for Circle {
       fn draw(&self) { /* ... */ }
   }
   
   ```

3. **Make Invalid States Unrepresentable** - Design types so that invalid states cannot be constructed. Use enums and newtypes to enforce invariants at compile time.


   > Type safety is Rust's superpower. Encode invariants in types rather
than relying on runtime checks.

   ```
   // BAD
   struct EmailMessage {
       to: Option<String>,
       body: Option<String>,
       sent: bool,  // Can be true even if to/body are None!
   }
   

   // GOOD
   enum EmailMessage {
       Draft { to: Option<String>, body: Option<String> },
       Ready { to: String, body: String },
       Sent { to: String, body: String, sent_at: DateTime },
   }
   
   ```

4. **Prefer Small, Focused Crates** - Split large crates into smaller, focused ones. This improves compile times, enables better code reuse, and clarifies dependencies.


   > Rust's compilation unit is the crate. Smaller crates mean faster incremental
builds and clearer dependency graphs.

   ```
   // Instead of one monolithic crate:
   myapp/
   ├── myapp-core/      # Core types, no IO
   ├── myapp-db/        # Database layer
   ├── myapp-api/       # HTTP API
   └── myapp/           # Binary, ties it together
   ```

5. **Use Type State Pattern for Compile-Time State Machines** - For state machines, encode states as types. This prevents invalid state transitions at compile time rather than runtime.


   > The typestate pattern uses generics to track state at compile time.
Invalid transitions become type errors.

   ```
   struct Connection<State> {
       inner: TcpStream,
       _state: PhantomData<State>,
   }
   
   struct Disconnected;
   struct Connected;
   struct Authenticated;
   
   impl Connection<Disconnected> {
       fn connect(self) -> Result<Connection<Connected>> { /* ... */ }
   }
   
   impl Connection<Connected> {
       fn authenticate(self, creds: &Credentials) -> Result<Connection<Authenticated>> { /* ... */ }
   }
   
   impl Connection<Authenticated> {
       fn query(&self, sql: &str) -> Result<Rows> { /* ... */ }
   }
   
   // This won't compile:
   // let conn = Connection::<Disconnected>::new();
   // conn.query("SELECT 1");  // Error: no method query on Disconnected
   ```

6. **Avoid Arc<Mutex<T>> When Possible** - Arc<Mutex<T>> is often overused. Consider channels, actors, or restructuring to avoid shared mutable state.


   > Shared mutable state adds complexity. Message passing (channels) or
actor patterns often produce cleaner, more testable code.

   ```
   // BAD
   // Shared state everywhere
   let state = Arc::new(Mutex::new(AppState::new()));
   // Clone Arc for every handler
   

   // GOOD
   // Use channels for communication
   let (tx, rx) = mpsc::channel();
   // State manager owns the state, receives commands via channel
   
   ```

7. **Document Safety Requirements for Public Unsafe Functions** - Public unsafe functions must document their safety requirements. What invariants must the caller uphold?


   > From Rust API Guidelines: unsafe functions should have a # Safety section
documenting what the caller must guarantee.

   ```
   /// Converts a byte slice to a string without checking UTF-8 validity.
   ///
   /// # Safety
   ///
   /// The bytes must be valid UTF-8. If this constraint is violated,
   /// undefined behavior results.
   pub unsafe fn from_utf8_unchecked(bytes: &[u8]) -> &str {
       // ...
   }
   ```

8. **Use Cargo Features for Optional Functionality** - Use Cargo features to make dependencies and functionality optional. This reduces compile times and binary size for users who don't need everything.


   > Features should be additive. Enabling a feature should never remove functionality
or change behavior in breaking ways.

   ```
   # Cargo.toml
   [features]
   default = ["json"]
   json = ["dep:serde_json"]
   yaml = ["dep:serde_yaml"]
   full = ["json", "yaml", "toml"]
   
   [dependencies]
   serde_json = { version = "1", optional = true }
   serde_yaml = { version = "0.9", optional = true }
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Unsafe without SAFETY comment | unsafe { ptr.read() } | Add // SAFETY: explanation |
| mem::transmute | mem::transmute::<&T, &U>(x) | Use from_ne_bytes, as, or ptr casts |
| .unwrap() in production | file.read().unwrap() | Use ? or .expect("reason") |
| panic! in library | panic!("bad input") | Return Result or Option |
| Clone to satisfy borrow checker | process(&data.clone()) | Restructure or use Arc/Rc |
| &String parameter | fn f(s: &String) | fn f(s: &str) |
| &Vec<T> parameter | fn f(v: &Vec<T>) | fn f(v: &[T]) |
| Blocking in async | async { std::fs::read() } | Use tokio::fs or spawn_blocking |
| Mutex across await | let g = m.lock(); f.await | Drop before await or use async Mutex |
| println! in library | println!("debug: {}", x) | Use log::debug! or tracing |
| Missing Debug derive | pub struct Foo { ... } | #[derive(Debug)] pub struct Foo |
| Wildcard imports | use std::collections::* | use std::collections::{HashMap, HashSet} |
| Large stack allocation | let arr: [u8; 10_000_000] | Use Box or Vec |
| anyhow in library API | pub fn f() -> anyhow::Result<T> | Define error type with thiserror |
