"""Tests for VM configuration utilities."""

from ai_how.utils.vm_config_utils import AutoStartResolver


class TestAutoStartResolver:
    """Test AutoStartResolver functionality."""

    def test_should_auto_start_vm_true(self):
        """Test VM should auto-start when auto_start is True."""
        configs = [{"cpu_cores": 4, "auto_start": True}]
        result = AutoStartResolver.should_auto_start_vm(0, configs)
        assert result is True

    def test_should_auto_start_vm_false(self):
        """Test VM should not auto-start when auto_start is False."""
        configs = [{"cpu_cores": 4, "auto_start": False}]
        result = AutoStartResolver.should_auto_start_vm(0, configs)
        assert result is False

    def test_should_auto_start_vm_default(self):
        """Test VM defaults to auto-start when auto_start not specified."""
        configs = [{"cpu_cores": 4}]
        result = AutoStartResolver.should_auto_start_vm(0, configs)
        assert result is True

    def test_should_auto_start_vm_out_of_range(self):
        """Test VM defaults to auto-start when index out of range."""
        configs = [{"cpu_cores": 4, "auto_start": False}]
        result = AutoStartResolver.should_auto_start_vm(5, configs)
        assert result is True

    def test_should_auto_start_vm_multiple_configs(self):
        """Test with multiple VM configurations."""
        configs = [
            {"cpu_cores": 4, "auto_start": True},
            {"cpu_cores": 8, "auto_start": False},
            {"cpu_cores": 16},  # defaults to True
        ]
        assert AutoStartResolver.should_auto_start_vm(0, configs) is True
        assert AutoStartResolver.should_auto_start_vm(1, configs) is False
        assert AutoStartResolver.should_auto_start_vm(2, configs) is True

    def test_get_no_start_indices_empty(self):
        """Test get_no_start_indices with no disabled VMs."""
        configs = [
            {"cpu_cores": 4, "auto_start": True},
            {"cpu_cores": 8, "auto_start": True},
        ]
        result = AutoStartResolver.get_no_start_indices(configs)
        assert result == set()

    def test_get_no_start_indices_some_disabled(self):
        """Test get_no_start_indices with some disabled VMs."""
        configs = [
            {"cpu_cores": 4, "auto_start": True},
            {"cpu_cores": 8, "auto_start": False},
            {"cpu_cores": 16},  # defaults to True
            {"cpu_cores": 32, "auto_start": False},
        ]
        result = AutoStartResolver.get_no_start_indices(configs)
        assert result == {1, 3}

    def test_get_no_start_indices_all_disabled(self):
        """Test get_no_start_indices with all disabled VMs."""
        configs = [
            {"cpu_cores": 4, "auto_start": False},
            {"cpu_cores": 8, "auto_start": False},
        ]
        result = AutoStartResolver.get_no_start_indices(configs)
        assert result == {0, 1}

    def test_get_no_start_indices_empty_list(self):
        """Test get_no_start_indices with empty config list."""
        result = AutoStartResolver.get_no_start_indices([])
        assert result == set()

    def test_check_single_vm_auto_start_true(self):
        """Test single VM check with auto_start True."""
        config = {"cpu_cores": 4, "auto_start": True}
        result = AutoStartResolver.check_single_vm_auto_start(config)
        assert result is True

    def test_check_single_vm_auto_start_false(self):
        """Test single VM check with auto_start False."""
        config = {"cpu_cores": 4, "auto_start": False}
        result = AutoStartResolver.check_single_vm_auto_start(config)
        assert result is False

    def test_check_single_vm_auto_start_default(self):
        """Test single VM check defaults to True."""
        config = {"cpu_cores": 4, "memory_gb": 8}
        result = AutoStartResolver.check_single_vm_auto_start(config)
        assert result is True

    def test_check_single_vm_auto_start_empty_config(self):
        """Test single VM check with empty config."""
        result = AutoStartResolver.check_single_vm_auto_start({})
        assert result is True
