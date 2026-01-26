# Domain: YAML Design

YAML syntax best practices and common footguns. Covers type coercion,
string handling, security, and structural patterns. Catches the infamous
Norway problem, sexagesimal parsing, and other YAML surprises.


**Validation:** `yaml.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

---

## Invariants

### NEVER (validator will reject)

1. **Tab Characters** - Tabs are not allowed in YAML indentation. YAML requires spaces for
indentation. Tabs will cause parse errors or unpredictable behavior.

   ```
   // BAD
   	key: value  # Tab indentation

   // GOOD
     key: value  # Space indentation
   ```

2. **Duplicate Keys** - Duplicate keys in the same mapping are invalid. The second value silently
overwrites the first, causing data loss with no warning.


   > YAML 1.2 spec states duplicate keys are an error, but many parsers
silently accept them. This causes subtle bugs when the wrong value wins.

   ```
   // BAD
   config:
     timeout: 30
     timeout: 60  # Silently overwrites!
   

   // GOOD
   config:
     timeout: 30
     retry_timeout: 60
   
   ```

3. **Unsafe YAML Load** - Never use unsafe YAML loading functions that allow arbitrary code execution.
YAML tags like !python/object can execute code during parsing.

   ```
   // BAD
   data = yaml.load(file)
   // BAD
   data = yaml.load(content)

   // GOOD
   data = yaml.safe_load(file)
   // GOOD
   data = yaml.load(content, Loader=yaml.SafeLoader)
   ```

4. **YAML Bomb (Billion Laughs)** - Exponentially expanding anchors/aliases can cause denial of service.
Never allow deeply nested anchor references from untrusted sources.

   ```
   // BAD
   a: &a ["lol","lol"]
   b: &b [*a,*a]
   c: &c [*b,*b]  # Exponential growth
   

   // GOOD
   # Flat structure without nested aliases
   items:
     - lol
     - lol
   
   ```

### MUST (validator will reject)

1. **Unquoted Norway Problem** - Country codes NO, DK, or values like "yes", "no", "on", "off" parse as
booleans in YAML 1.1. This is the infamous "Norway problem."

   ```
   // BAD
   country: NO  # Becomes false!
   // BAD
   enabled: yes  # Works but version-dependent

   // GOOD
   country: "NO"
   // GOOD
   enabled: true  # Explicit boolean
   ```

2. **Unquoted Sexagesimal Numbers** - Values like 22:22 or 4:30 are parsed as base-60 (sexagesimal) numbers
in YAML 1.1, converting to seconds. Port mappings are commonly affected.

   ```
   // BAD
   port: 22:22  # Becomes 1342 in YAML 1.1!
   // BAD
   time: 4:30   # Becomes 270

   // GOOD
   port: "22:22"
   // GOOD
   time: "4:30"
   ```

3. **Unquoted Octal Numbers** - Numbers starting with 0 are octal in YAML 1.1. The value 0777 becomes
511 decimal. File permissions are commonly affected.

   ```
   // BAD
   mode: 0755  # Becomes 493 decimal
   // BAD
   permissions: 0644

   // GOOD
   mode: "0755"
   // GOOD
   mode: 493  # If you actually want decimal
   ```

4. **Version Number Coercion** - Version strings like 1.0 or 10.23 are parsed as floats, losing precision
or format. Version 1.10 becomes 1.1, version 10.0 becomes 10.

   ```
   // BAD
   version: 1.0   # Becomes float 1.0
   // BAD
   version: 1.10  # Becomes 1.1!

   // GOOD
   version: "1.0"
   // GOOD
   version: "1.10"
   ```

5. **Unquoted Scientific Notation** - Values that look like scientific notation (1e10, 2E5) are parsed as
floats. Version numbers or identifiers can be misinterpreted.

   ```
   // BAD
   code: 1e10  # Becomes 10000000000

   // GOOD
   code: "1e10"
   ```

6. **Unquoted Special Strings** - Values null, ~, true, false, and .inf/.nan have special meaning in YAML.
They must be quoted if you want the literal string.

   ```
   // BAD
   value: null  # Becomes null, not string
   // BAD
   name: True   # Becomes boolean true

   // GOOD
   value: "null"  # String "null"
   // GOOD
   enabled: true  # If boolean intended
   ```

7. **Inconsistent Indentation** - Mixed indentation levels (e.g., 2 spaces then 4 spaces) cause parse
errors or incorrect nesting. Use consistent indentation throughout.


   > YAML is whitespace-sensitive. Pick one indentation size (2 spaces is
common) and use it consistently. Mixed indentation causes silent
misinterpretation of document structure.

   ```
   // BAD
   parent:
     child1: value  # 2 spaces
         child2: value  # 4 spaces - wrong!
   

   // GOOD
   parent:
     child1: value
     child2: value
   
   ```

8. **Trailing Whitespace in Multiline** - Trailing spaces in multiline strings can cause unexpected behavior,
especially with folded (>) or literal (|) block scalars.

   ```
   // BAD
   key: value   # trailing spaces

   // GOOD
   key: value
   ```

### SHOULD (validator warns)

1. **Prefer Explicit Document Start** - Multi-document YAML files should have explicit document start markers.
Single-document files benefit from consistency.

   ```
   // BAD
   key: value
   ...
   another: doc
   

   // GOOD
   ---
   key: value
   ...
   ---
   another: doc
   
   ```

2. **Quote Strings Starting with Special Characters** - Strings starting with @, `, *, &, !, |, >, {, [, or % should be quoted
to avoid being parsed as YAML special constructs.

   ```
   // BAD
   email: @user  # @ is reserved
   // BAD
   ref: *main    # Interpreted as alias

   // GOOD
   email: "@user"
   // GOOD
   ref: "*main"
   ```

3. **Avoid Anchors for Simple Values** - Anchors and aliases add complexity. For simple values, prefer
repetition or external templating over YAML anchors.

   ```
   // BAD
   defaults: &defaults
     timeout: 30
   production:
     <<: *defaults
   

   // GOOD
   development:
     timeout: 30
   production:
     timeout: 30
   
   ```

4. **Use Lowercase for Boolean Values** - Use lowercase true/false for booleans. Other spellings (True, TRUE,
yes, on) work in YAML 1.1 but are less portable.

   ```
   // BAD
   enabled: True
   // BAD
   enabled: TRUE
   // BAD
   enabled: yes

   // GOOD
   enabled: true
   // GOOD
   enabled: false
   ```

5. **Quote Empty Strings** - Empty values in YAML are null, not empty strings. Use explicit quotes
for empty strings. Note: This check may flag parent keys with nested
content.

   ```
   // BAD
   name:  # This is null!

   // GOOD
   name: ""  # Explicit empty string
   // GOOD
   name: null  # If null is intended
   ```

6. **Avoid Flow Style for Complex Structures** - Flow style ({}, []) is harder to read for nested structures.
Use block style for anything beyond simple lists.

   ```
   // BAD
   config: {db: {host: localhost, port: 5432}}

   // GOOD
   config:
     db:
       host: localhost
       port: 5432
   
   ```

### GUIDANCE (not mechanically checked)

1. **Prefer Flat Structures** - Deeply nested YAML is hard to read and maintain. Prefer flatter
structures where possible.


   > Deep nesting (4+ levels) makes YAML hard to:
- Read and understand at a glance
- Modify without indentation errors
- Merge and diff effectively

Consider restructuring deeply nested configs or splitting into
multiple files.

   ```
   // BAD
   app:
     config:
       database:
         connection:
           pool:
             size: 10
   

   // GOOD
   database_pool_size: 10
   # Or use dotted keys if supported
   database.connection.pool.size: 10
   
   ```

2. **Document Complex Structures** - Add comments explaining non-obvious YAML structures, especially
anchors, tags, and complex multiline strings.


   > YAML supports comments with #. Use them to explain:
- Why a value is quoted (avoiding type coercion)
- What an anchor/alias does
- Expected format of complex values
- Units or valid ranges for numbers

   ```
   # Connection timeout in seconds
   timeout: 30
   
   # Country code - quoted to avoid Norway problem
   country: "NO"
   ```

3. **Use Schema Validation** - For configuration files, use JSON Schema or similar validation
to catch type errors and invalid values early.


   > YAML's loose typing means runtime errors for bad config.
JSON Schema provides:
- Type checking (string vs number)
- Enum validation (allowed values)
- Required field checking
- Pattern matching

Tools: jsonschema, ajv, yamale, kwalify

   ```
   # $schema: ./config-schema.json
   # Or use a YAML schema directive
   apiVersion: v1
   kind: Config
   ```

4. **Consider Alternatives for Complex Data** - For complex configuration, consider TOML, JSON5, or generating
JSON from a proper programming language.


   > YAML's complexity leads to subtle bugs. Alternatives:
- TOML: Simple, explicit typing, good for config files
- JSON5: JSON + comments + trailing commas
- Generate JSON: From Python, Nix, CUE, Dhall, etc.

As the saying goes: "YAML is a superset of JSON, and that's
the only nice thing about it."

   ```
   # For simple config: TOML
   # For complex config: Generate JSON from code
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Unquoted country codes |  | Quote the value: "NO" |
| Unquoted port mappings |  | Quote the value: "22:22" |
| Unquoted version numbers |  | Quote the value: "1.10" |
| yaml.load() without SafeLoader |  | Use yaml.safe_load() or specify SafeLoader |
| Leading zero numbers |  | Quote the value: "0755" |
| Empty values for strings |  | Use explicit quotes: "" |
| Deeply nested anchors |  | Limit nesting, validate untrusted input |
| Tab indentation |  | Use spaces only |
