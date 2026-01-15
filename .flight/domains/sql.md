# Domain: SQL Design

Production SQL patterns for PostgreSQL/Supabase. Security, performance, maintainability. Covers both SQL files and source code containing SQL queries.


**Validation:** `sql.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **SELECT *** - Never use SELECT * - breaks on schema changes, wastes bandwidth. Always specify explicit column lists.

   ```
   // BAD
   SELECT * FROM users WHERE id = $1;

   // GOOD
   SELECT id, email, name, created_at FROM users WHERE id = $1;
   ```

2. **String Interpolation in SQL** - Never use string interpolation in SQL queries. SQL injection risk. Use parameterized queries with placeholders ($1, ?, :param).

   ```
   // BAD
   const query = `SELECT * FROM users WHERE id = ${userId}`;
   // BAD
   const query = "SELECT * FROM users WHERE name = " + name;
   // BAD
   query = f"SELECT * FROM users WHERE id = {user_id}"

   // GOOD
   const query = 'SELECT id, email FROM users WHERE id = $1';
   // GOOD
   await db.query(query, [userId]);
   ```

3. **UPDATE/DELETE Without WHERE** - Never run UPDATE or DELETE without a WHERE clause. This modifies or deletes ALL rows in the table, causing catastrophic data loss.

   ```
   // BAD
   UPDATE users SET status = 'inactive';
   // BAD
   DELETE FROM orders;

   // GOOD
   UPDATE users SET status = 'inactive' WHERE last_login < '2024-01-01';
   // GOOD
   DELETE FROM orders WHERE status = 'cancelled' AND created_at < '2024-01-01';
   ```

4. **LIKE with Leading Wildcard** - Never use LIKE with a leading wildcard ('%...') - it forces a full table scan and cannot use indexes. Use full text search instead.

   ```
   // BAD
   SELECT * FROM products WHERE name LIKE '%widget%';

   // GOOD
   SELECT id, name FROM products WHERE name LIKE 'widget%';
   // GOOD
   SELECT id, name FROM products WHERE to_tsvector(name) @@ to_tsquery('widget');
   ```

5. **Functions on Columns in WHERE** - Never apply functions to indexed columns in WHERE clauses. This prevents index usage and forces full table scans.

   ```
   // BAD
   SELECT * FROM orders WHERE YEAR(created_at) = 2024;
   // BAD
   SELECT * FROM users WHERE LOWER(email) = 'test@example.com';

   // GOOD
   SELECT id, total FROM orders WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
   // GOOD
   CREATE INDEX idx_users_email_lower ON users (LOWER(email));
   ```

6. **Large OFFSET Values** - Never use large OFFSET values for pagination. OFFSET scans and discards rows, getting slower as offset grows. Use cursor/keyset pagination.

   ```
   // BAD
   SELECT * FROM posts ORDER BY created_at DESC LIMIT 20 OFFSET 10000;

   // GOOD
   SELECT id, title, created_at FROM posts
   WHERE created_at < $1
   ORDER BY created_at DESC
   LIMIT 20;
   
   ```

7. **Plain Text Password Column** - Never store passwords in plain text. Use password_hash, password_digest, or hashed_password columns and store bcrypt/argon2 hashes.

   ```
   // BAD
   password varchar(255)
   // BAD
   password text NOT NULL

   // GOOD
   password_hash varchar(255) NOT NULL
   // GOOD
   password_digest text NOT NULL
   ```

8. **timestamp Without Timezone** - Never use 'timestamp' without timezone. Use 'timestamptz' or 'timestamp with time zone' to avoid timezone ambiguity.

   ```
   // BAD
   created_at timestamp NOT NULL

   // GOOD
   created_at timestamptz NOT NULL DEFAULT now()
   ```

9. **float/real for Money** - Never use float or real types for monetary values. Floating point has precision issues. Use decimal(10,2) for exact currency amounts.

   ```
   // BAD
   price float NOT NULL
   // BAD
   total real

   // GOOD
   price decimal(10,2) NOT NULL
   // GOOD
   total numeric(12,2)
   ```

### SHOULD (validator warns)

1. **Boolean Without NOT NULL DEFAULT** - Boolean columns should have NOT NULL DEFAULT to avoid three-state logic (true, false, NULL). Explicit defaults prevent bugs.

   ```
   // BAD
   is_active boolean
   // BAD
   is_verified boolean,

   // GOOD
   is_active boolean NOT NULL DEFAULT true
   // GOOD
   is_verified boolean NOT NULL DEFAULT false
   ```

2. **Missing RLS on user_id Tables** - Tables with user_id columns should have Row Level Security enabled to prevent data leakage in multi-tenant applications.

   ```
   // BAD
   CREATE TABLE documents (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id),
     content text
   );
   

   // GOOD
   CREATE TABLE documents (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id),
     content text
   );
   ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
   
   ```

3. **Missing Index on Foreign Key** - Foreign key columns should have indexes for efficient JOINs and CASCADE operations. Without indexes, these operations scan full tables.

   ```
   // BAD
   CREATE TABLE orders (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id)
   );
   

   // GOOD
   CREATE TABLE orders (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id)
   );
   CREATE INDEX idx_orders_user_id ON orders(user_id);
   
   ```

4. **N+1 Query Pattern** - Avoid executing queries inside loops (N+1 pattern). This causes excessive database round trips. Use JOINs or batch queries instead.

   ```
   // BAD
   const users = await db.query('SELECT id FROM users');
   for (const user of users) {
     const orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [user.id]);
   }
   

   // GOOD
   const result = await db.query(`
     SELECT u.id, u.name, o.id as order_id, o.total
     FROM users u
     LEFT JOIN orders o ON o.user_id = u.id
   `);
   
   ```

5. **Multiple Writes Without Transaction** - Multiple INSERT/UPDATE operations should be wrapped in a transaction to ensure atomicity. Partial failures leave data in inconsistent state.

   ```
   // BAD
   await db.query('UPDATE accounts SET balance = balance - 100 WHERE id = $1', [from]);
   await db.query('UPDATE accounts SET balance = balance + 100 WHERE id = $1', [to]);
   

   // GOOD
   await db.query('BEGIN');
   try {
     await db.query('UPDATE accounts SET balance = balance - 100 WHERE id = $1', [from]);
     await db.query('UPDATE accounts SET balance = balance + 100 WHERE id = $1', [to]);
     await db.query('COMMIT');
   } catch (e) {
     await db.query('ROLLBACK');
     throw e;
   }
   
   ```

6. **Supabase .select() Without Columns** - Supabase .select() calls should specify columns explicitly. Empty .select() returns all columns like SELECT *.

   ```
   // BAD
   const { data } = await supabase.from('users').select();

   // GOOD
   const { data } = await supabase.from('users').select('id, email, name');
   ```

### GUIDANCE (not mechanically checked)

1. **Use Parameterized Queries** - Always use parameterized queries with placeholders ($1, ?, :param). Never construct SQL strings with user input.


2. **Explicit Column Lists in INSERT** - Always name columns in INSERT statements. Positional inserts break when schema changes.


3. **Use Transactions for Related Writes** - Wrap related write operations in transactions to ensure atomicity.


4. **Add Indexes for Common Query Patterns** - Create indexes for columns used in WHERE, JOIN, and ORDER BY clauses.


5. **Enable RLS on User-Scoped Tables** - Enable Row Level Security on tables that contain user-specific data.


6. **Use EXPLAIN ANALYZE** - Use EXPLAIN ANALYZE to understand query performance and identify bottlenecks.


7. **Add NOT NULL Where Appropriate** - Use NOT NULL constraints for required fields to prevent null data issues.


8. **Use Appropriate Data Types** - Choose data types appropriate for the data: decimal for money, timestamptz for timestamps, uuid for distributed IDs.


9. **Soft Delete Pattern** - Use soft deletes when data recovery may be needed. Add deleted_at column and partial indexes for active records.


10. **Migration Structure** - Organize database migrations with clear up/down sections and consistent naming.


11. **Supabase RLS Pattern** - Standard RLS policy pattern for Supabase multi-tenant applications.


12. **Cursor Pagination Pattern** - Use cursor/keyset pagination for efficient pagination at scale.


13. **Upsert Pattern** - Use ON CONFLICT for upsert operations to handle insert-or-update atomically.


14. **Audit Trail Pattern** - Implement audit logging for tracking changes to important tables.


15. **Naming Conventions** - Follow consistent naming conventions for tables, columns, indexes, constraints, aliases, and RLS policies.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| SELECT * |  | Explicit columns |
| String interpolation |  | Parameterized queries |
| UPDATE no WHERE |  | Always filter |
| LIKE '%x%' |  | Full text search |
| WHERE YEAR(col) |  | Range comparison |
| N+1 queries |  | JOIN or batch |
| No transaction |  | BEGIN/COMMIT |
| Plain text passwords |  | Hash (bcrypt/argon2) |
| No RLS |  | Enable + policies |
| OFFSET 10000 |  | Cursor pagination |
| No FK index |  | Add index |
| Nullable boolean |  | NOT NULL DEFAULT |
| float for money |  | decimal(10,2) |
| timestamp |  | timestamptz |
