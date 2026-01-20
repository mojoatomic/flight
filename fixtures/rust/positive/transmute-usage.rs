// Test file: actual mem::transmute usage
// This should trigger N2 violation

use std::mem;

fn dangerous_simple() {
    let x: u32 = 42;
    // Simple transmute call
    let y: f32 = unsafe { mem::transmute(x) };
    let _ = y;
}

fn dangerous_qualified() {
    let a: u64 = 0;
    // Fully qualified with turbofish
    let b: i64 = unsafe { std::mem::transmute::<u64, i64>(a) };
    let _ = b;
}

fn dangerous_generic() {
    let bytes: [u8; 4] = [0, 0, 0, 0];
    // Generic transmute
    let num: u32 = unsafe { mem::transmute::<[u8; 4], u32>(bytes) };
    let _ = num;
}
