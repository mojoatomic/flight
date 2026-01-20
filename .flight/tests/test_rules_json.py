"""Tests for generate_rules_json() and convert_check_to_rule() functions."""

import json
import pytest
from pathlib import Path

from flight_domain_compile import (
    parse_domain_spec,
    generate_rules_json,
    convert_check_to_rule,
    Rule,
)


class TestConvertCheckToRule:
    """Tests for convert_check_to_rule() function."""

    def test_returns_none_for_non_mechanical_rule(self):
        """Convert check returns None for non-mechanical rules."""
        rule = Rule(
            id="G1",
            title="Guidance Rule",
            severity="GUIDANCE",
            mechanical=False,
            description="This is guidance only.",
        )

        json_rule = convert_check_to_rule(rule)

        assert json_rule is None

    def test_grep_rule_has_pattern_and_null_query(self):
        """Convert check returns pattern and null query for grep rules."""
        rule = Rule(
            id="N1",
            title="No eval",
            severity="NEVER",
            mechanical=True,
            description="No eval allowed.",
            check={"type": "grep", "pattern": r"eval\("},
        )

        json_rule = convert_check_to_rule(rule)

        assert json_rule is not None
        assert json_rule["type"] == "grep"
        assert json_rule["pattern"] == r"eval\("
        assert json_rule["query"] is None

    def test_ast_rule_has_query_and_null_pattern(self):
        """Convert check returns query and null pattern for ast rules."""
        query = '(call_expression function: (identifier) @fn (#eq? @fn "eval"))'
        rule = Rule(
            id="N1",
            title="No eval",
            severity="NEVER",
            mechanical=True,
            description="No eval allowed.",
            check={"type": "ast", "query": query},
        )

        json_rule = convert_check_to_rule(rule)

        assert json_rule is not None
        assert json_rule["type"] == "ast"
        assert json_rule["query"] == query
        assert json_rule["pattern"] is None

    def test_preserves_rule_metadata(self):
        """Convert check preserves id, title, severity, and message."""
        rule = Rule(
            id="N1",
            title="No eval",
            severity="NEVER",
            mechanical=True,
            description="Do not use eval().",
            check={"type": "grep", "pattern": "eval"},
        )

        json_rule = convert_check_to_rule(rule)

        assert json_rule["id"] == "N1"
        assert json_rule["title"] == "No eval"
        assert json_rule["severity"] == "NEVER"
        assert json_rule["message"] == "Do not use eval()."

    def test_defaults_to_grep_when_type_not_specified(self):
        """Convert check defaults to grep type when not specified."""
        rule = Rule(
            id="N1",
            title="Test Rule",
            severity="NEVER",
            mechanical=True,
            description="Test description.",
            check={"pattern": "test_pattern"},
        )

        json_rule = convert_check_to_rule(rule)

        assert json_rule is not None
        assert json_rule["type"] == "grep"


class TestGenerateRulesJson:
    """Tests for generate_rules_json() function."""

    def test_generates_valid_json(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON produces valid JSON string."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)

        # Should not raise
        parsed = json.loads(json_str)
        assert isinstance(parsed, dict)

    def test_includes_domain_metadata(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON includes domain name and version."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        assert parsed["domain"] == spec.domain
        assert parsed["version"] == spec.version

    def test_includes_file_patterns(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON includes file patterns."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        assert "file_patterns" in parsed
        assert len(parsed["file_patterns"]) > 0

    def test_excludes_non_mechanical_rules(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON excludes non-mechanical rules."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        # G1 is non-mechanical, should not be in JSON
        rule_ids = [r["id"] for r in parsed["rules"]]
        assert "G1" not in rule_ids

    def test_mixed_types_have_correct_structure(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON handles mixed grep and ast check types."""
        spec_data = load_yaml(valid_fixtures_dir / "mixed-types.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        grep_rules = [r for r in parsed["rules"] if r["type"] == "grep"]
        ast_rules = [r for r in parsed["rules"] if r["type"] == "ast"]

        # Should have both types
        assert len(grep_rules) > 0
        assert len(ast_rules) > 0

        # Grep rules: pattern set, query null
        for rule in grep_rules:
            assert rule["pattern"] is not None
            assert rule["query"] is None

        # AST rules: query set, pattern null
        for rule in ast_rules:
            assert rule["query"] is not None
            assert rule["pattern"] is None

    def test_rules_sorted_by_id(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON sorts rules by ID."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        rule_ids = [r["id"] for r in parsed["rules"]]
        assert rule_ids == sorted(rule_ids)


class TestProvenanceInJson:
    """Tests for provenance metadata in generated JSON."""

    def test_includes_domain_provenance(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON includes domain-level provenance."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        assert "provenance" in parsed
        assert "last_full_audit" in parsed["provenance"]

    def test_includes_rule_provenance(self, load_yaml, valid_fixtures_dir: Path):
        """Generate rules JSON includes rule-level provenance."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        json_str = generate_rules_json(spec)
        parsed = json.loads(json_str)

        # Find rules with provenance
        rules_with_prov = [r for r in parsed["rules"] if "provenance" in r]
        assert len(rules_with_prov) > 0

        # Check provenance fields
        rule_prov = rules_with_prov[0]["provenance"]
        assert "last_verified" in rule_prov or "confidence" in rule_prov
