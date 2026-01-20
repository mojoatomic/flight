# Task 006: Compiler .rules.json Generation

## Depends On
- 001-flight-lint-scaffold (for schema understanding)
- 003-rules-loader (for types)

## Delivers
- Updated `flight-domain-compile.py` to generate `.rules.json`
- JSON schema validation for generated files
- Provenance metadata in output
- Both `.md` and `.rules.json` generated from single `.flight` file

## NOT In Scope
- New check types (Task 007)
- tree-sitter queries (Task 009)
- Migration of existing domains (Tasks 009-011)

## Acceptance Criteria
- [ ] `flight-domain-compile domain.flight` produces `domain.md` AND `domain.rules.json`
- [ ] Generated `.rules.json` validates against schema
- [ ] Existing grep-based checks convert to `type: grep` in JSON
- [ ] Provenance from `.flight` appears in `.rules.json`
- [ ] `--json-only` flag skips `.md` generation
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- python.md

## Context

The compiler currently generates `.md` files from `.flight` YAML. This task extends it to also generate `.rules.json` files that `flight-lint` can consume.

For now, existing checks become `type: grep` rules. Task 007 will add `type: ast` support.

## Technical Notes

### .rules.json Schema (Reference)

```json
{
  "domain": "javascript",
  "version": "1.2.0",
  "language": "javascript",
  "file_patterns": ["**/*.js", "**/*.mjs"],
  "exclude_patterns": ["**/node_modules/**"],
  "provenance": {
    "last_full_audit": "2025-01-15",
    "audited_by": "team",
    "next_audit_due": "2025-07-15"
  },
  "rules": [
    {
      "id": "N1",
      "title": "No eval()",
      "severity": "NEVER",
      "type": "grep",
      "pattern": "eval\\s*\\(",
      "query": null,
      "message": "eval() executes arbitrary code",
      "provenance": {
        "last_verified": "2025-01-10",
        "confidence": "high"
      }
    }
  ]
}
```

### Compiler Changes (flight-domain-compile.py)

Add these functions to the existing compiler:

```python
import json

def generate_rules_json(domain_data: dict, output_path: str) -> None:
    """Generate .rules.json from parsed domain data."""

    rules = []
    for check in domain_data.get('checks', []):
        rule = convert_check_to_rule(check, domain_data)
        if rule:
            rules.append(rule)

    rules_json = {
        'domain': domain_data['domain'],
        'version': domain_data.get('version', '1.0.0'),
        'language': domain_data.get('language', 'unknown'),
        'file_patterns': domain_data.get('file_patterns', ['**/*']),
        'exclude_patterns': domain_data.get('exclude_patterns', []),
        'rules': rules,
    }

    # Add provenance if present
    if 'provenance' in domain_data:
        rules_json['provenance'] = domain_data['provenance']

    with open(output_path, 'w') as f:
        json.dump(rules_json, f, indent=2)

def convert_check_to_rule(check: dict, domain_data: dict) -> dict | None:
    """Convert a check definition to a rule entry."""

    check_type = check.get('type', 'grep')

    rule = {
        'id': check['id'],
        'title': check['title'],
        'severity': check['severity'],
        'type': check_type,
        'message': check.get('message', check['title']),
    }

    if check_type == 'grep':
        rule['pattern'] = check.get('pattern', '')
        rule['query'] = None
    elif check_type == 'ast':
        rule['pattern'] = None
        rule['query'] = check.get('query', '')
    else:
        # Unknown type, skip
        return None

    # Add rule-level provenance if present
    if 'provenance' in check:
        rule['provenance'] = check['provenance']

    return rule

def compile_domain(input_path: str, output_dir: str, json_only: bool = False) -> None:
    """Compile a .flight file to .md and .rules.json."""

    domain_data = parse_flight_file(input_path)

    base_name = Path(input_path).stem

    # Generate .md (unless json_only)
    if not json_only:
        md_path = Path(output_dir) / f'{base_name}.md'
        generate_markdown(domain_data, str(md_path))

    # Generate .rules.json
    json_path = Path(output_dir) / f'{base_name}.rules.json'
    generate_rules_json(domain_data, str(json_path))
```

### CLI Updates

Add `--json-only` flag to compiler:

```python
parser.add_argument(
    '--json-only',
    action='store_true',
    help='Generate only .rules.json, skip .md generation'
)
```

### Validation

After generating, validate the JSON:

```python
def validate_rules_json(json_path: str) -> bool:
    """Validate generated .rules.json against schema."""

    with open(json_path) as f:
        data = json.load(f)

    required_fields = ['domain', 'version', 'language', 'file_patterns', 'rules']
    for field in required_fields:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")

    for i, rule in enumerate(data['rules']):
        required_rule_fields = ['id', 'title', 'severity', 'type', 'message']
        for field in required_rule_fields:
            if field not in rule:
                raise ValueError(f"Rule {i} missing required field: {field}")

    return True
```

## Testing

Create test cases:

```bash
# Test basic generation
python3 .flight/bin/flight-domain-compile.py test.flight
ls -la test.md test.rules.json

# Test JSON validation
python3 -c "import json; json.load(open('test.rules.json'))"

# Test json-only mode
python3 .flight/bin/flight-domain-compile.py --json-only test.flight
```

## Validation
Run after implementing:
```bash
# Compile a domain and check both outputs
python3 .flight/bin/flight-domain-compile.py .flight/domains/javascript.flight
cat .flight/domains/javascript.rules.json | python3 -m json.tool

# Verify existing validation still works
.flight/validate-all.sh
```
