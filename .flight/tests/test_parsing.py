"""Tests for parse_domain_spec() and related parsing functions."""

import pytest
from pathlib import Path

from flight_domain_compile import (
    parse_domain_spec,
    parse_rules,
    DomainSpec,
    Rule,
    SCHEMA_V1,
    SCHEMA_V2,
)


class TestParseDomainSpec:
    """Tests for parse_domain_spec() function."""

    def test_parses_minimal_spec_correctly(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec extracts domain name and version."""
        spec_data = load_yaml(valid_fixtures_dir / "minimal.flight")
        spec = parse_domain_spec(spec_data)

        assert isinstance(spec, DomainSpec)
        assert spec.domain == "minimal"
        assert spec.version == "1.0.0"

    def test_parses_file_patterns(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec extracts file patterns."""
        spec_data = load_yaml(valid_fixtures_dir / "minimal.flight")
        spec = parse_domain_spec(spec_data)

        assert len(spec.file_patterns) > 0
        assert "**/*.js" in spec.file_patterns

    def test_parses_rules_into_dict(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec creates rules dictionary keyed by ID."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        assert isinstance(spec.rules, dict)
        assert len(spec.rules) > 0
        assert all(isinstance(rule, Rule) for rule in spec.rules.values())

    def test_parses_rule_check_config(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec extracts check configuration from rules."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        spec = parse_domain_spec(spec_data)

        rule = spec.rules.get("N1")
        assert rule is not None
        assert rule.check.get("type") == "grep"
        assert rule.check.get("pattern") is not None


class TestSchemaVersionHandling:
    """Tests for schema version detection and handling."""

    def test_defaults_to_schema_v1_when_not_specified(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec defaults to schema v1 when not specified."""
        spec_data = load_yaml(valid_fixtures_dir / "minimal.flight")
        spec = parse_domain_spec(spec_data)

        assert spec.schema_version == SCHEMA_V1

    def test_parses_schema_v2_when_specified(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec uses schema v2 when explicitly set."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        assert spec.schema_version == SCHEMA_V2


class TestProvenanceParsing:
    """Tests for provenance metadata parsing."""

    def test_parses_domain_level_provenance(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec extracts domain-level provenance."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        assert spec.provenance is not None
        assert spec.provenance.last_full_audit is not None
        assert spec.provenance.audited_by == "test-suite"

    def test_parses_rule_level_provenance(self, load_yaml, valid_fixtures_dir: Path):
        """Parse domain spec extracts rule-level provenance."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        # Find a rule with provenance
        rules_with_provenance = [r for r in spec.rules.values() if r.provenance]
        assert len(rules_with_provenance) > 0

        rule = rules_with_provenance[0]
        assert rule.provenance.confidence in ("high", "medium", "low")

    def test_non_mechanical_rules_have_no_provenance_requirement(
        self, load_yaml, valid_fixtures_dir: Path
    ):
        """Non-mechanical rules (GUIDANCE) don't require provenance."""
        spec_data = load_yaml(valid_fixtures_dir / "with-provenance.flight")
        spec = parse_domain_spec(spec_data)

        guidance_rule = spec.rules.get("G1")
        assert guidance_rule is not None
        assert guidance_rule.mechanical is False
