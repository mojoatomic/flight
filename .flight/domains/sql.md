# Domain: SQL

Production SQL patterns for PostgreSQL/Supabase. Security, performance, maintainability.

---

## Invariants

### NEVER

1. **`SELECT *`** - Breaks on schema changes, wastes bandwidth
   ```sql
   -- BAD
   SELECT * FROM users WHERE id = $1;
   
   -- GOOD
   SELECT id, email, name, created_at FROM users WHERE id = $1;
   ```

2. **String Interpolation in Queries** - SQL injection
   ```javascript
   // BAD
   const query = `SELECT * FROM users WHERE id = '${userId}'`;
   const query = "SELECT * FROM users WHERE name = '" + name + "'";
   
   // GOOD
   const query = 'SELECT id, email FROM users WHERE id = $1';
   await db.query(query, [userId]);
   
   // GOOD - Supabase
   const { data } = await supabase
     .from('users')
     .select('id, email')
     .eq('id', userId);
   ```

3. **Missing WHERE on UPDATE/DELETE** - Destroys data
   ```sql
   -- BAD (updates ALL rows)
   UPDATE users SET status = 'inactive';
   
   -- BAD (deletes ALL rows)
   DELETE FROM orders;
   
   -- GOOD
   UPDATE users SET status = 'inactive' WHERE last_login < '2024-01-01';
   DELETE FROM orders WHERE status = 'cancelled' AND created_at < '2024-01-01';
   ```

4. **LIKE with Leading Wildcard** - Can't use index
   ```sql
   -- BAD - full table scan
   SELECT * FROM products WHERE name LIKE '%widget%';
   
   -- GOOD - can use index
   SELECT id, name FROM products WHERE name LIKE 'widget%';
   
   -- GOOD - use full text search for contains
   SELECT id, name FROM products WHERE to_tsvector(name) @@ to_tsquery('widget');
   ```

5. **Functions on Indexed Columns in WHERE** - Kills index
   ```sql
   -- BAD - can't use index on created_at
   SELECT * FROM orders WHERE YEAR(created_at) = 2024;
   SELECT * FROM users WHERE LOWER(email) = 'test@example.com';
   
   -- GOOD - index usable
   SELECT id, total FROM orders 
   WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
   
   -- GOOD - use generated column or functional index
   CREATE INDEX idx_users_email_lower ON users (LOWER(email));
   ```

6. **N+1 Queries** - Death by a thousand cuts
   ```javascript
   // BAD - N+1 queries
   const users = await db.query('SELECT id FROM users');
   for (const user of users) {
     const orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [user.id]);
   }
   
   // GOOD - single query with JOIN
   const result = await db.query(`
     SELECT u.id, u.name, o.id as order_id, o.total
     FROM users u
     LEFT JOIN orders o ON o.user_id = u.id
   `);
   
   // GOOD - Supabase
   const { data } = await supabase
     .from('users')
     .select('id, name, orders(id, total)');
   ```

7. **Missing Transactions for Multi-Step Operations**
   ```javascript
   // BAD - partial failure leaves bad state
   await db.query('UPDATE accounts SET balance = balance - 100 WHERE id = $1', [from]);
   await db.query('UPDATE accounts SET balance = balance + 100 WHERE id = $1', [to]);
   
   // GOOD - atomic
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

8. **Storing Passwords in Plain Text**
   ```sql
   -- BAD
   INSERT INTO users (email, password) VALUES ($1, $2);
   
   -- GOOD - hash in application layer
   INSERT INTO users (email, password_hash) VALUES ($1, $2);
   -- where $2 is bcrypt/argon2 hash
   ```

9. **No Row Level Security on Multi-Tenant Tables**
   ```sql
   -- BAD - any user can see all data
   CREATE TABLE documents (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id),
     content text
   );
   
   -- GOOD - RLS enforced
   CREATE TABLE documents (
     id uuid PRIMARY KEY,
     user_id uuid REFERENCES users(id),
     content text
   );
   
   ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
   
   CREATE POLICY documents_user_policy ON documents
     FOR ALL
     USING (user_id = auth.uid());
   ```

10. **OFFSET for Pagination** - Gets slower as offset grows
    ```sql
    -- BAD - scans and discards offset rows
    SELECT * FROM posts ORDER BY created_at DESC LIMIT 20 OFFSET 10000;
    
    -- GOOD - cursor/keyset pagination
    SELECT id, title, created_at FROM posts 
    WHERE created_at < $1  -- cursor from last item
    ORDER BY created_at DESC 
    LIMIT 20;
    ```

11. **Missing Indexes on Foreign Keys**
    ```sql
    -- BAD - JOINs and cascades will be slow
    CREATE TABLE orders (
      id uuid PRIMARY KEY,
      user_id uuid REFERENCES users(id)
    );
    
    -- GOOD
    CREATE TABLE orders (
      id uuid PRIMARY KEY,
      user_id uuid REFERENCES users(id)
    );
    CREATE INDEX idx_orders_user_id ON orders(user_id);
    ```

12. **NULL in Boolean/Status Columns**
    ```sql
    -- BAD - three-state boolean
    CREATE TABLE users (
      is_active boolean  -- can be true, false, or NULL
    );
    
    -- GOOD - explicit default, not null
    CREATE TABLE users (
      is_active boolean NOT NULL DEFAULT true
    );
    ```

13. **VARCHAR Without Limit for User Input**
    ```sql
    -- BAD - unbounded, potential DoS
    CREATE TABLE posts (
      title varchar,
      body text
    );
    
    -- GOOD - bounded
    CREATE TABLE posts (
      title varchar(200) NOT NULL,
      body text CHECK (length(body) <= 50000)
    );
    ```

14. **Implicit Type Coercion**
    ```sql
    -- BAD - string compared to integer, full scan
    SELECT * FROM users WHERE id = '123';
    
    -- GOOD - types match
    SELECT id, email FROM users WHERE id = 123;
    SELECT id, email FROM users WHERE id = $1::integer;
    ```

### MUST

1. **Use Parameterized Queries**
   ```javascript
   // Always use placeholders
   await db.query('SELECT id, email FROM users WHERE id = $1', [userId]);
   await db.query('INSERT INTO logs (action, user_id) VALUES ($1, $2)', [action, userId]);
   ```

2. **Explicit Column Lists in INSERT**
   ```sql
   -- Always name columns
   INSERT INTO users (email, name, created_at) 
   VALUES ($1, $2, NOW());
   
   -- Not positional
   INSERT INTO users VALUES ($1, $2, $3);  -- BAD
   ```

3. **Use Transactions for Related Writes**
   ```sql
   BEGIN;
   INSERT INTO orders (id, user_id, total) VALUES ($1, $2, $3);
   INSERT INTO order_items (order_id, product_id, qty) VALUES ($1, $4, $5);
   UPDATE inventory SET quantity = quantity - $5 WHERE product_id = $4;
   COMMIT;
   ```

4. **Add Indexes for Common Query Patterns**
   ```sql
   -- Columns in WHERE clauses
   CREATE INDEX idx_orders_status ON orders(status);
   
   -- Columns in JOIN conditions
   CREATE INDEX idx_order_items_order_id ON order_items(order_id);
   
   -- Columns in ORDER BY with LIMIT
   CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
   
   -- Composite for multi-column filters
   CREATE INDEX idx_orders_user_status ON orders(user_id, status);
   ```

5. **Enable RLS on User-Scoped Tables**
   ```sql
   ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
   ALTER TABLE documents FORCE ROW LEVEL SECURITY;
   
   CREATE POLICY documents_select ON documents
     FOR SELECT USING (user_id = auth.uid());
     
   CREATE POLICY documents_insert ON documents
     FOR INSERT WITH CHECK (user_id = auth.uid());
     
   CREATE POLICY documents_update ON documents
     FOR UPDATE USING (user_id = auth.uid());
     
   CREATE POLICY documents_delete ON documents
     FOR DELETE USING (user_id = auth.uid());
   ```

6. **Use EXPLAIN ANALYZE for Slow Queries**
   ```sql
   EXPLAIN ANALYZE
   SELECT u.name, COUNT(o.id) as order_count
   FROM users u
   LEFT JOIN orders o ON o.user_id = u.id
   WHERE u.created_at > '2024-01-01'
   GROUP BY u.id;
   ```

7. **Add NOT NULL Where Appropriate**
   ```sql
   CREATE TABLE orders (
     id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id uuid NOT NULL REFERENCES users(id),
     status varchar(20) NOT NULL DEFAULT 'pending',
     total decimal(10,2) NOT NULL,
     created_at timestamptz NOT NULL DEFAULT now()
   );
   ```

8. **Use Appropriate Data Types**
   ```sql
   -- Money
   total decimal(10,2) NOT NULL  -- not float
   
   -- Timestamps
   created_at timestamptz NOT NULL  -- not timestamp (no timezone)
   
   -- UUIDs
   id uuid PRIMARY KEY DEFAULT gen_random_uuid()  -- not serial for distributed
   
   -- Enums or check constraints for status
   status varchar(20) NOT NULL CHECK (status IN ('pending', 'active', 'complete'))
   ```

9. **Soft Delete Pattern When Needed**
   ```sql
   CREATE TABLE documents (
     id uuid PRIMARY KEY,
     -- ... other columns
     deleted_at timestamptz,  -- NULL = not deleted
     
     -- Partial index for active records
     CONSTRAINT documents_unique_name UNIQUE (name) WHERE deleted_at IS NULL
   );
   
   CREATE INDEX idx_documents_active ON documents(id) WHERE deleted_at IS NULL;
   
   -- RLS policy excludes deleted
   CREATE POLICY documents_select ON documents
     FOR SELECT USING (user_id = auth.uid() AND deleted_at IS NULL);
   ```

---

## Patterns

### Migration Structure
```sql
-- migrations/001_create_users.sql

-- Up
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(255) NOT NULL UNIQUE,
  name varchar(100) NOT NULL,
  password_hash varchar(255) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Down
DROP TABLE users;
```

### Supabase RLS Pattern
```sql
-- Enable RLS
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Users can only see their own documents
CREATE POLICY "Users can view own documents" ON documents
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only insert documents for themselves
CREATE POLICY "Users can create own documents" ON documents
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only update their own documents
CREATE POLICY "Users can update own documents" ON documents
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own documents
CREATE POLICY "Users can delete own documents" ON documents
  FOR DELETE
  USING (auth.uid() = user_id);

-- Service role bypasses RLS (for admin operations)
-- Use supabase.auth.admin or service_role key
```

### Cursor Pagination
```sql
-- First page
SELECT id, title, created_at 
FROM posts 
WHERE user_id = $1
ORDER BY created_at DESC, id DESC 
LIMIT 21;  -- fetch n+1 to check if more exist

-- Next page (pass last item's created_at and id)
SELECT id, title, created_at 
FROM posts 
WHERE user_id = $1
  AND (created_at, id) < ($2, $3)  -- cursor
ORDER BY created_at DESC, id DESC 
LIMIT 21;
```

### Upsert Pattern
```sql
INSERT INTO user_settings (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key) 
DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = now();
```

### Audit Trail
```sql
CREATE TABLE audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name varchar(100) NOT NULL,
  record_id uuid NOT NULL,
  action varchar(20) NOT NULL,  -- INSERT, UPDATE, DELETE
  old_data jsonb,
  new_data jsonb,
  user_id uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- Trigger function
CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, user_id)
  VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    CASE WHEN TG_OP != 'INSERT' THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP != 'DELETE' THEN to_jsonb(NEW) END,
    auth.uid()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `SELECT *` | Schema changes break code | Explicit columns |
| String interpolation | SQL injection | Parameterized queries |
| `UPDATE` no `WHERE` | Updates all rows | Always filter |
| `LIKE '%x%'` | Full table scan | Full text search |
| `WHERE YEAR(col)` | Can't use index | Range comparison |
| N+1 queries | Death by latency | JOIN or batch |
| No transaction | Partial failure | BEGIN/COMMIT |
| Plain text passwords | Security breach | Hash (bcrypt/argon2) |
| No RLS | Data leakage | Enable + policies |
| `OFFSET 10000` | Scans 10k rows | Cursor pagination |
| No FK index | Slow JOINs | Add index |
| Nullable boolean | Three states | NOT NULL DEFAULT |
| `float` for money | Precision loss | `decimal(10,2)` |
| `timestamp` | No timezone | `timestamptz` |
