# Task 008: Compiler Test Suite

## Depends On
- 006-compiler-rules-json
- 007-ast-check-format

## Delivers
- Test suite for `flight-domain-compile.py`
- Test fixtures in `.flight/test-fixtures/`
- CI integration for compiler tests
- Edge case coverage

## NOT In Scope
- `flight-lint` tests (handled in flight-lint tasks)
- Integration tests with actual tree-sitter (Task 011)
- Performance testing (future enhancement)

## Acceptance Criteria
- [ ] `python3 -m pytest .flight/tests/` passes
- [ ] Tests cover: valid input, invalid input, edge cases
- [ ] Test fixtures for grep and AST check types
- [ ] JSON schema validation tests
- [ ] Provenance handling tests
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- python.md

## Context

The compiler now generates both `.md` and `.rules.json` files. This task adds a comprehensive test suite to ensure reliability.

## Technical Notes

### Directory Structure

```
.flight/
├── bin/
│   └── flight-domain-compile.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_compiler.py
│   ├── test_rules_json.py
│   └── test_validation.py
└── test-fixtures/
    ├── valid/
    │   ├── minimal.flight
    │   ├── grep-only.flight
    │   ├── ast-only.flight
    │   ├── mixed-types.flight
    │   └── with-provenance.flight
    ├── invalid/
    │   ├── missing-domain.flight
    │   ├── missing-id.flight
    │   ├── unknown-type.flight
    │   └── invalid-yaml.flight
    └── expected/
        ├── minimal.rules.json
        ├── grep-only.rules.json
        └── ast-only.rules.json
```

### Test Fixtures

**`.flight/test-fixtures/valid/minimal.flight`**
```yaml
domain: minimal
version: "1.0.0"
language: javascript
file_patterns:
  - "**/*.js"

checks:
  NEVER:
    - id: N1
      title: Test Rule
      pattern: 'test'
      message: Test message
```

**`.flight/test-fixtures/valid/mixed-types.flight`**
```yaml
domain: mixed
version: "1.0.0"
language: javascript
file_patterns:
  - "**/*.js"

checks:
  NEVER:
    - id: N1
      title: Grep Rule
      type: grep
      pattern: 'eval\('
      message: No eval

    - id: N2
      title: AST Rule
      type: ast
      query: |
        (call_expression
          function: (identifier) @match
          (#eq? @match "eval"))
      message: No eval (AST)
```

### Test File: `.flight/tests/test_compiler.py`

```python
import pytest
import json
import tempfile
from pathlib import Path
import sys

# Add bin directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'bin'))

from flight_domain_compile import compile_domain, parse_flight_file

FIXTURES_DIR = Path(__file__).parent.parent / 'test-fixtures'


class TestParseFlightFile:
    def test_parses_minimal_file(self):
        path = FIXTURES_DIR / 'valid' / 'minimal.flight'
        data = parse_flight_file(str(path))

        assert data['domain'] == 'minimal'
        assert data['version'] == '1.0.0'
        assert data['language'] == 'javascript'
        assert len(data['checks']) >= 1

    def test_parses_mixed_types(self):
        path = FIXTURES_DIR / 'valid' / 'mixed-types.flight'
        data = parse_flight_file(str(path))

        checks = data['checks']
        grep_check = next(c for c in checks if c['type'] == 'grep')
        ast_check = next(c for c in checks if c['type'] == 'ast')

        assert grep_check['pattern'] == 'eval\\('
        assert 'call_expression' in ast_check['query']

    def test_rejects_missing_domain(self):
        path = FIXTURES_DIR / 'invalid' / 'missing-domain.flight'
        with pytest.raises(ValueError, match='domain'):
            parse_flight_file(str(path))

    def test_rejects_invalid_yaml(self):
        path = FIXTURES_DIR / 'invalid' / 'invalid-yaml.flight'
        with pytest.raises(Exception):
            parse_flight_file(str(path))


class TestCompileDomain:
    def test_generates_both_outputs(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'minimal.flight'
            compile_domain(str(input_path), tmpdir)

            md_path = Path(tmpdir) / 'minimal.md'
            json_path = Path(tmpdir) / 'minimal.rules.json'

            assert md_path.exists()
            assert json_path.exists()

    def test_json_only_mode(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'minimal.flight'
            compile_domain(str(input_path), tmpdir, json_only=True)

            md_path = Path(tmpdir) / 'minimal.md'
            json_path = Path(tmpdir) / 'minimal.rules.json'

            assert not md_path.exists()
            assert json_path.exists()

    def test_generated_json_is_valid(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'minimal.flight'
            compile_domain(str(input_path), tmpdir)

            json_path = Path(tmpdir) / 'minimal.rules.json'
            with open(json_path) as f:
                data = json.load(f)

            assert data['domain'] == 'minimal'
            assert isinstance(data['rules'], list)


class TestRulesJsonGeneration:
    def test_grep_rule_has_pattern(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'grep-only.flight'
            compile_domain(str(input_path), tmpdir)

            json_path = Path(tmpdir) / 'grep-only.rules.json'
            with open(json_path) as f:
                data = json.load(f)

            rule = data['rules'][0]
            assert rule['type'] == 'grep'
            assert rule['pattern'] is not None
            assert rule['query'] is None

    def test_ast_rule_has_query(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'ast-only.flight'
            compile_domain(str(input_path), tmpdir)

            json_path = Path(tmpdir) / 'ast-only.rules.json'
            with open(json_path) as f:
                data = json.load(f)

            rule = data['rules'][0]
            assert rule['type'] == 'ast'
            assert rule['query'] is not None
            assert rule['pattern'] is None

    def test_provenance_included(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = FIXTURES_DIR / 'valid' / 'with-provenance.flight'
            compile_domain(str(input_path), tmpdir)

            json_path = Path(tmpdir) / 'with-provenance.rules.json'
            with open(json_path) as f:
                data = json.load(f)

            assert 'provenance' in data
            assert 'last_full_audit' in data['provenance']
```

### conftest.py

```python
import pytest
from pathlib import Path

@pytest.fixture
def fixtures_dir():
    return Path(__file__).parent.parent / 'test-fixtures'

@pytest.fixture
def valid_fixtures(fixtures_dir):
    return fixtures_dir / 'valid'

@pytest.fixture
def invalid_fixtures(fixtures_dir):
    return fixtures_dir / 'invalid'
```

### requirements-test.txt

```
pytest>=7.0.0
pytest-cov>=4.0.0
```

## Validation
Run after implementing:
```bash
# Install test dependencies
pip install -r .flight/requirements-test.txt

# Run tests
python3 -m pytest .flight/tests/ -v

# Run with coverage
python3 -m pytest .flight/tests/ --cov=.flight/bin --cov-report=html

# Verify existing validation
.flight/validate-all.sh
```
