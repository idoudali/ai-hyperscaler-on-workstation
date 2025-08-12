import json
from pathlib import Path

import pytest
import yaml

from ai_how.validation import validate_config


@pytest.fixture
def schema_file(tmp_path: Path) -> Path:
    """Create a temporary schema file for testing."""
    schema_content = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "count": {"type": "integer"},
        },
        "required": ["name"],
    }
    schema_path = tmp_path / "schema.json"
    schema_path.write_text(json.dumps(schema_content))
    return schema_path


def test_validate_config_valid(schema_file: Path, tmp_path: Path):
    """Test that a valid configuration file passes validation."""
    valid_config = {"name": "test-cluster", "count": 5}
    config_path = tmp_path / "valid_config.yaml"
    config_path.write_text(yaml.dump(valid_config))

    assert validate_config(config_path, schema_file) is True


def test_validate_config_invalid_missing_required(schema_file: Path, tmp_path: Path):
    """Test that a config missing a required property fails validation."""
    invalid_config = {"count": 10}  # Missing 'name'
    config_path = tmp_path / "invalid_config.yaml"
    config_path.write_text(yaml.dump(invalid_config))

    assert validate_config(config_path, schema_file) is False


def test_validate_config_invalid_wrong_type(schema_file: Path, tmp_path: Path):
    """Test that a config with a wrong data type fails validation."""
    invalid_config = {"name": "test-cluster", "count": "five"}  # 'count' should be an integer
    config_path = tmp_path / "invalid_config.yaml"
    config_path.write_text(yaml.dump(invalid_config))

    assert validate_config(config_path, schema_file) is False


def test_validate_config_file_not_found(schema_file: Path):
    """Test that a non-existent config file fails validation."""
    non_existent_config = Path("non_existent_config.yaml")
    assert validate_config(non_existent_config, schema_file) is False


def test_validate_schema_file_not_found(tmp_path: Path):
    """Test that a non-existent schema file fails validation."""
    config_path = tmp_path / "config.yaml"
    config_path.touch()
    non_existent_schema = Path("non_existent_schema.json")
    assert validate_config(config_path, non_existent_schema) is False


def test_validate_config_invalid_yaml(schema_file: Path, tmp_path: Path):
    """Test that a malformed YAML config file fails validation."""
    config_path = tmp_path / "invalid.yaml"
    config_path.write_text(
        "name: 'cluster\ncount: 2"
    )  # Malformed YAML: missing closing quote for 'cluster'
    assert validate_config(config_path, schema_file) is False


def test_validate_schema_invalid_json(tmp_path: Path):
    """Test that a malformed JSON schema file fails validation."""
    config_path = tmp_path / "config.yaml"
    config_path.write_text(yaml.dump({"name": "test"}))
    schema_path = tmp_path / "invalid_schema.json"
    schema_path.write_text('{"type": "object", "properties": }')  # Malformed JSON
    assert validate_config(config_path, schema_path) is False
