// Test file: transmute mentioned in comments and strings only
// This should NOT trigger N2 violation (AST query ignores comments/strings)

// This file discusses mem::transmute but doesn't actually use it
// mem::transmute is dangerous and should be avoided
// std::mem::transmute::<T, U> can cause undefined behavior

fn safe_function() {
    // Comments about mem::transmute should not trigger
    let x = "mem::transmute is mentioned in a string";
    println!("{}", x);

    // Another comment: transmute::<u8, i8> is dangerous
    let y = "std::mem::transmute::<u64, i64> in a string literal";
    println!("{}", y);

    // Use safe alternatives instead of transmute
    let bytes: [u8; 4] = [0, 0, 0, 0];
    let num = u32::from_ne_bytes(bytes); // Safe alternative!
    println!("{}", num);
}

fn another_safe_function() {
    /* Block comment mentioning mem::transmute */
    /* transmute::<T, U> should not be used */
    let z = 42;
    println!("{}", z);
}
