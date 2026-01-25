// SQL with violations

// N1: SELECT *
const allUsers = "SELECT * FROM users";

// N2: String interpolation in SQL
function badQuery(userId) {
  return db.query("SELECT * FROM users WHERE id = " + userId);
}

// N3: UPDATE without WHERE
const dangerousUpdate = "UPDATE users SET active = false";

// N4: DELETE without WHERE  
const dangerousDelete = "DELETE FROM sessions";

// N5: LIKE with leading wildcard
const slowSearch = "SELECT * FROM products WHERE name LIKE '%search%'";

// Good query for pass count
const goodQuery = "SELECT id, name FROM users WHERE id = ?";
