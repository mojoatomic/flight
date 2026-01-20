// Test file: unsafe block without SAFETY comment
// This should trigger N1 violation

fn risky() {
    unsafe {
        // No SAFETY comment above - should flag as violation
        let ptr = std::ptr::null::<i32>();
        let _ = ptr;
    }
}

fn also_risky() {
    // This comment is not a SAFETY comment
    unsafe {
        let raw: *const u8 = &42u8;
        let _ = raw;
    }
}
