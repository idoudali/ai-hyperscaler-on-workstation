"""Unit tests for inventory formatters."""

import yaml

from ai_how.inventory.formatters import INIFormatter, YAMLFormatter


class TestINIFormatter:
    """Test INI formatter functionality."""

    def test_format_simple_inventory(self):
        """Test formatting a simple inventory with one host."""
        inventory = {
            "groups": {
                "all": {
                    "hosts": {
                        "host1": {
                            "ansible_host": "192.168.1.10",
                            "ansible_user": "admin",
                        }
                    },
                    "vars": {},
                }
            }
        }

        formatter = INIFormatter()
        result = formatter.format(inventory)

        assert "[all]" in result
        assert "host1 ansible_host=192.168.1.10 ansible_user=admin" in result

    def test_format_with_groups(self):
        """Test formatting inventory with multiple groups."""
        inventory = {
            "groups": {
                "webservers": {
                    "hosts": {
                        "web1": {"ansible_host": "10.0.0.1"},
                        "web2": {"ansible_host": "10.0.0.2"},
                    },
                    "vars": {"http_port": 80},
                },
                "databases": {
                    "hosts": {
                        "db1": {"ansible_host": "10.0.0.10"},
                    },
                    "vars": {},
                },
            }
        }

        formatter = INIFormatter()
        result = formatter.format(inventory)

        # Check group sections
        assert "[webservers]" in result
        assert "[databases]" in result

        # Check hosts in groups
        assert "web1" in result
        assert "web2" in result
        assert "db1" in result

        # Check group vars
        assert "[webservers:vars]" in result
        assert "http_port=80" in result

    def test_format_with_children(self):
        """Test formatting inventory with group children."""
        inventory = {
            "groups": {
                "production": {
                    "hosts": {},
                    "children": ["webservers", "databases"],
                    "vars": {"environment": "prod"},
                }
            }
        }

        formatter = INIFormatter()
        result = formatter.format(inventory)

        assert "[production:children]" in result
        assert "webservers" in result
        assert "databases" in result

    def test_format_complex_values(self):
        """Test formatting with complex variable types (dict, list, bool)."""
        inventory = {
            "groups": {
                "servers": {
                    "hosts": {
                        "server1": {
                            "ansible_host": "10.0.0.1",
                            "enabled": True,
                            "disabled": False,
                            "config": {"key": "value", "nested": {"deep": "val"}},
                            "tags": ["web", "api", "prod"],
                        }
                    },
                    "vars": {},
                }
            }
        }

        formatter = INIFormatter()
        result = formatter.format(inventory)

        # Check boolean formatting
        assert "enabled=true" in result
        assert "disabled=false" in result

        # Check JSON encoding of complex types
        assert "config=" in result
        assert '"key":"value"' in result

        assert "tags=" in result
        assert '["web","api","prod"]' in result

    def test_format_empty_inventory(self):
        """Test formatting an empty inventory."""
        inventory = {"groups": {}}

        formatter = INIFormatter()
        result = formatter.format(inventory)

        # Should return minimal valid inventory
        assert isinstance(result, str)

    def test_format_host_with_null_value(self):
        """Test formatting host with null/None values."""
        inventory = {
            "groups": {
                "servers": {
                    "hosts": {
                        "server1": {
                            "ansible_host": "10.0.0.1",
                            "optional_var": None,
                        }
                    },
                    "vars": {},
                }
            }
        }

        formatter = INIFormatter()
        result = formatter.format(inventory)

        assert "server1" in result
        assert "ansible_host=10.0.0.1" in result
        # None values should be empty strings
        assert "optional_var=" in result


class TestYAMLFormatter:
    """Test YAML formatter functionality."""

    def test_format_simple_inventory(self):
        """Test formatting a simple inventory to YAML."""
        inventory = {
            "groups": {
                "webservers": {
                    "hosts": {
                        "web1": {"ansible_host": "10.0.0.1"},
                    },
                    "vars": {"http_port": 80},
                }
            }
        }

        formatter = YAMLFormatter()
        result = formatter.format(inventory)

        # Parse the YAML to verify structure
        parsed = yaml.safe_load(result)

        assert "all" in parsed
        assert "children" in parsed["all"]
        assert "webservers" in parsed["all"]["children"]

        webservers = parsed["all"]["children"]["webservers"]
        assert "web1" in webservers["hosts"]
        assert webservers["hosts"]["web1"]["ansible_host"] == "10.0.0.1"
        assert webservers["vars"]["http_port"] == 80

    def test_format_with_children(self):
        """Test YAML formatting with group children."""
        inventory = {
            "groups": {
                "production": {
                    "hosts": {},
                    "children": ["webservers", "databases"],
                    "vars": {},
                }
            }
        }

        formatter = YAMLFormatter()
        result = formatter.format(inventory)

        parsed = yaml.safe_load(result)
        prod = parsed["all"]["children"]["production"]

        assert "children" in prod
        assert "webservers" in prod["children"]
        assert "databases" in prod["children"]

    def test_format_preserves_structure(self):
        """Test that YAML formatting preserves inventory structure."""
        inventory = {
            "groups": {
                "group1": {
                    "hosts": {
                        "host1": {"var1": "value1", "var2": 123},
                        "host2": {"var1": "value2"},
                    },
                    "vars": {"group_var": "group_value"},
                }
            }
        }

        formatter = YAMLFormatter()
        result = formatter.format(inventory)

        parsed = yaml.safe_load(result)
        group1 = parsed["all"]["children"]["group1"]

        assert len(group1["hosts"]) == 2
        assert group1["hosts"]["host1"]["var1"] == "value1"
        assert group1["hosts"]["host1"]["var2"] == 123
        assert group1["vars"]["group_var"] == "group_value"

    def test_yaml_output_is_valid(self):
        """Test that YAML output is valid and parseable."""
        inventory = {
            "groups": {
                "servers": {
                    "hosts": {
                        "server1": {
                            "ansible_host": "10.0.0.1",
                            "tags": ["web", "api"],
                            "config": {"nested": {"key": "value"}},
                        }
                    },
                    "vars": {},
                }
            }
        }

        formatter = YAMLFormatter()
        result = formatter.format(inventory)

        # Should not raise exception
        parsed = yaml.safe_load(result)

        # Verify complex structures are preserved
        server1 = parsed["all"]["children"]["servers"]["hosts"]["server1"]
        assert server1["tags"] == ["web", "api"]
        assert server1["config"]["nested"]["key"] == "value"

    def test_format_empty_inventory(self):
        """Test formatting an empty inventory to YAML."""
        inventory = {"groups": {}}

        formatter = YAMLFormatter()
        result = formatter.format(inventory)

        parsed = yaml.safe_load(result)
        assert "all" in parsed
        assert "children" in parsed["all"]
        assert parsed["all"]["children"] == {}
