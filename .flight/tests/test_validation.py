"""Tests for validate_spec() function."""

import pytest
from pathlib import Path

# Import from compiler module (loaded in conftest.py)
from flight_domain_compile import validate_spec


class TestValidateSpecRequiredFields:
    """Tests for required field validation."""

    def test_returns_error_when_domain_missing(self, load_yaml, invalid_fixtures_dir: Path):
        """Validate spec returns error when domain field is missing."""
        spec_data = load_yaml(invalid_fixtures_dir / "missing-domain.flight")
        errors, warnings = validate_spec(spec_data, "missing-domain")

        assert len(errors) > 0
        assert any("domain" in err.lower() for err in errors)

    def test_returns_error_when_rules_missing(self, load_yaml, invalid_fixtures_dir: Path):
        """Validate spec returns error when rules field is missing."""
        spec_data = load_yaml(invalid_fixtures_dir / "missing-rules.flight")
        errors, warnings = validate_spec(spec_data, "missing-rules")

        assert len(errors) > 0
        assert any("rules" in err.lower() for err in errors)

    def test_returns_no_errors_for_valid_minimal_spec(self, load_yaml, valid_fixtures_dir: Path):
        """Validate spec returns no errors for valid minimal spec."""
        spec_data = load_yaml(valid_fixtures_dir / "minimal.flight")
        errors, warnings = validate_spec(spec_data, "minimal")

        assert len(errors) == 0


class TestValidateSpecCheckTypes:
    """Tests for check type validation."""

    def test_returns_error_for_unknown_check_type(self, load_yaml, invalid_fixtures_dir: Path):
        """Validate spec returns error for unknown check type."""
        spec_data = load_yaml(invalid_fixtures_dir / "unknown-type.flight")
        errors, warnings = validate_spec(spec_data, "unknown-type")

        assert len(errors) > 0
        assert any("unknown" in err.lower() or "type" in err.lower() for err in errors)

    def test_returns_error_when_ast_check_missing_query(self, load_yaml, invalid_fixtures_dir: Path):
        """Validate spec returns error when AST check has no query field."""
        spec_data = load_yaml(invalid_fixtures_dir / "ast-missing-query.flight")
        errors, warnings = validate_spec(spec_data, "ast-missing-query")

        assert len(errors) > 0
        assert any("query" in err.lower() for err in errors)

    def test_accepts_grep_check_type(self, load_yaml, valid_fixtures_dir: Path):
        """Validate spec accepts grep check type."""
        spec_data = load_yaml(valid_fixtures_dir / "grep-only.flight")
        errors, warnings = validate_spec(spec_data, "grep-only")

        assert len(errors) == 0

    def test_accepts_ast_check_type_with_query(self, load_yaml, valid_fixtures_dir: Path):
        """Validate spec accepts ast check type with query."""
        spec_data = load_yaml(valid_fixtures_dir / "ast-only.flight")
        errors, warnings = validate_spec(spec_data, "ast-only")

        assert len(errors) == 0

    def test_accepts_mixed_check_types(self, load_yaml, valid_fixtures_dir: Path):
        """Validate spec accepts mix of grep and ast check types."""
        spec_data = load_yaml(valid_fixtures_dir / "mixed-types.flight")
        errors, warnings = validate_spec(spec_data, "mixed-types")

        assert len(errors) == 0
