"""Pytest configuration and fixtures for compiler tests."""

import importlib.util
import sys
from pathlib import Path

import pytest

# Load the compiler module (has hyphen in filename, can't use regular import)
BIN_DIR = Path(__file__).parent.parent / "bin"
COMPILER_PATH = BIN_DIR / "flight-domain-compile.py"

spec = importlib.util.spec_from_file_location("flight_domain_compile", COMPILER_PATH)
flight_domain_compile = importlib.util.module_from_spec(spec)
sys.modules["flight_domain_compile"] = flight_domain_compile
spec.loader.exec_module(flight_domain_compile)

FIXTURES_DIR = Path(__file__).parent.parent / "test-fixtures"


@pytest.fixture
def fixtures_dir() -> Path:
    """Return path to test fixtures directory."""
    return FIXTURES_DIR


@pytest.fixture
def valid_fixtures_dir(fixtures_dir: Path) -> Path:
    """Return path to valid test fixtures."""
    return fixtures_dir / "valid"


@pytest.fixture
def invalid_fixtures_dir(fixtures_dir: Path) -> Path:
    """Return path to invalid test fixtures."""
    return fixtures_dir / "invalid"


@pytest.fixture
def load_yaml():
    """Return a function to load YAML files."""
    import yaml

    def _load(fixture_path: Path) -> dict:
        with open(fixture_path) as f:
            return yaml.safe_load(f)

    return _load
