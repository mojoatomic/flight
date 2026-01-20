// Test file: unsafe blocks WITH SAFETY comments
// This should NOT trigger N1 violation (but with simple AST query it will)
// Note: The AST query flags ALL unsafe blocks. SAFETY comment checking
// would require flight-lint enhancement to check sibling nodes.

// For now, this file demonstrates the pattern we want to eventually allow.
// The current implementation will still flag these as violations.

fn safe_usage() {
    // SAFETY: ptr::null returns a valid null pointer that is safe to create
    // (but not dereference). We only use it for comparison.
    unsafe {
        let ptr = std::ptr::null::<i32>();
        let _ = ptr;
    }
}

fn another_safe_usage() {
    // SAFETY: We are reading from a valid, aligned pointer.
    // The slice is guaranteed to have at least one element.
    unsafe {
        let arr = [1, 2, 3];
        let ptr = arr.as_ptr();
        let first = *ptr;
        let _ = first;
    }
}
