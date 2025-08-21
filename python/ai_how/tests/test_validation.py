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


@pytest.fixture
def cluster_schema_file(tmp_path: Path) -> Path:
    """Create a temporary cluster schema file for testing."""
    schema_content = {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object",
        "properties": {
            "version": {"type": "string", "pattern": "^1\\.0$"},
            "metadata": {
                "type": "object",
                "properties": {"name": {"type": "string"}, "description": {"type": "string"}},
                "required": ["name", "description"],
            },
            "clusters": {
                "type": "object",
                "properties": {
                    "hpc": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "base_image_path": {"type": "string"},
                            "network": {
                                "type": "object",
                                "properties": {
                                    "subnet": {"type": "string"},
                                    "bridge": {"type": "string"},
                                },
                                "required": ["subnet", "bridge"],
                            },
                        },
                        "required": ["name", "base_image_path", "network"],
                    },
                    "cloud": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "base_image_path": {"type": "string"},
                            "network": {
                                "type": "object",
                                "properties": {
                                    "subnet": {"type": "string"},
                                    "bridge": {"type": "string"},
                                },
                                "required": ["subnet", "bridge"],
                            },
                        },
                        "required": ["name", "base_image_path", "network"],
                    },
                },
                "required": ["hpc", "cloud"],
            },
        },
        "required": ["version", "metadata", "clusters"],
    }
    schema_path = tmp_path / "cluster_schema.json"
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


def test_validate_cluster_config_with_base_image_path(cluster_schema_file: Path, tmp_path: Path):
    """Test that a cluster configuration with base_image_path passes validation."""
    valid_cluster_config = {
        "version": "1.0",
        "metadata": {"name": "test-hyperscaler", "description": "Test cluster configuration"},
        "clusters": {
            "hpc": {
                "name": "hpc-cluster",
                "base_image_path": "/var/lib/libvirt/images/ubuntu-22.04-server-amd64.qcow2",
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
            },
            "cloud": {
                "name": "cloud-cluster",
                "base_image_path": "/var/lib/libvirt/images/ubuntu-22.04-server-amd64.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
            },
        },
    }
    config_path = tmp_path / "cluster_config.yaml"
    config_path.write_text(yaml.dump(valid_cluster_config))

    assert validate_config(config_path, cluster_schema_file) is True


def test_validate_cluster_config_missing_base_image_path(cluster_schema_file: Path, tmp_path: Path):
    """Test that a cluster configuration missing base_image_path fails validation."""
    invalid_cluster_config = {
        "version": "1.0",
        "metadata": {"name": "test-hyperscaler", "description": "Test cluster configuration"},
        "clusters": {
            "hpc": {
                "name": "hpc-cluster",
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
            },
            "cloud": {
                "name": "cloud-cluster",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
            },
        },
    }
    config_path = tmp_path / "cluster_config.yaml"
    config_path.write_text(yaml.dump(invalid_cluster_config))

    assert validate_config(config_path, cluster_schema_file) is False


def test_validate_cluster_config_base_image_path_wrong_type(
    cluster_schema_file: Path, tmp_path: Path
):
    """Test that a cluster configuration with wrong base_image_path type fails validation."""
    invalid_cluster_config = {
        "version": "1.0",
        "metadata": {"name": "test-hyperscaler", "description": "Test cluster configuration"},
        "clusters": {
            "hpc": {
                "name": "hpc-cluster",
                "base_image_path": 123,  # Should be a string
                "network": {"subnet": "192.168.100.0/24", "bridge": "virbr100"},
            },
            "cloud": {
                "name": "cloud-cluster",
                "base_image_path": "/var/lib/libvirt/images/ubuntu-22.04-server-amd64.qcow2",
                "network": {"subnet": "192.168.200.0/24", "bridge": "virbr200"},
            },
        },
    }
    config_path = tmp_path / "cluster_config.yaml"
    config_path.write_text(yaml.dump(invalid_cluster_config))

    assert validate_config(config_path, cluster_schema_file) is False
