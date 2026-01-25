// Rust fixture with violations for testing
use std::mem;

// M3: String parameter when &str would work (MUST)
fn bad_string_param(name: String) -> usize {
    name.len()
}

fn bad_string_ref_param(name: &String) -> usize {
    name.len()
}

// M4: Vec parameter when slice would work (MUST)
fn bad_vec_param(items: &Vec<i32>) -> i32 {
    items.iter().sum()
}

// M5: Box<T> when T would work (MUST)
struct Container {
    data: Box<String>,
    list: Box<Vec<i32>>,
}

// N1: Unsafe block without SAFETY comment (NEVER) - AST rule
fn bad_unsafe() {
    unsafe {
        dangerous_operation();
    }
}

// N2: mem::transmute usage (NEVER) - AST rule
fn bad_transmute(x: u32) -> f32 {
    unsafe { mem::transmute(x) }
}

// N5: .expect() without descriptive message (NEVER)
fn bad_expect() {
    let value = some_option().expect("");
}

// N6: Raw pointer arithmetic (NEVER)
fn bad_pointer_arithmetic(ptr: *const u8, offset: isize) -> *const u8 {
    unsafe { ptr.offset(offset) }
}

// N7: mem::forget (NEVER)
fn bad_forget<T>(value: T) {
    mem::forget(value);
}

// S6: CamelCase for functions (SHOULD)
fn badFunction() {
    let myValue = 42;
}

// S8: as casts instead of From/Into (SHOULD)
fn bad_casts(x: u64) -> u32 {
    let a = x as u32;
    let b = 255 as u8;
    a
}

fn dangerous_operation() {}
fn some_option() -> Option<i32> { Some(1) }
