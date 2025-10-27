"""VM configuration utilities."""

from typing import Any


class AutoStartResolver:
    """Resolves auto-start configuration for VMs."""

    @staticmethod
    def should_auto_start_vm(vm_index: int, config_list: list[dict[str, Any]]) -> bool:
        """Check if VM should be auto-started based on configuration.

        Args:
            vm_index: Index of VM in configuration list (0-based)
            config_list: List of VM configurations

        Returns:
            True if VM should be auto-started, False otherwise

        Examples:
            >>> configs = [
            ...     {"cpu_cores": 4, "auto_start": True},
            ...     {"cpu_cores": 8, "auto_start": False},
            ... ]
            >>> AutoStartResolver.should_auto_start_vm(0, configs)
            True
            >>> AutoStartResolver.should_auto_start_vm(1, configs)
            False
            >>> # Default to True if config not found
            >>> AutoStartResolver.should_auto_start_vm(5, configs)
            True
        """
        if vm_index >= len(config_list):
            return True  # Default to auto-start if no config

        vm_config = config_list[vm_index]
        return vm_config.get("auto_start", True)

    @staticmethod
    def get_no_start_indices(config_list: list[dict[str, Any]]) -> set[int]:
        """Get set of indices for VMs that should not auto-start.

        Args:
            config_list: List of VM configurations

        Returns:
            Set of indices where auto_start is False

        Examples:
            >>> configs = [
            ...     {"cpu_cores": 4, "auto_start": True},
            ...     {"cpu_cores": 8, "auto_start": False},
            ...     {"cpu_cores": 16},  # defaults to True
            ...     {"cpu_cores": 32, "auto_start": False},
            ... ]
            >>> AutoStartResolver.get_no_start_indices(configs)
            {1, 3}
        """
        return {i for i, cfg in enumerate(config_list) if cfg.get("auto_start", True) is False}

    @staticmethod
    def check_single_vm_auto_start(vm_config: dict[str, Any]) -> bool:
        """Check if a single VM configuration has auto-start enabled.

        Args:
            vm_config: VM configuration dictionary

        Returns:
            True if auto_start is enabled (default), False otherwise

        Examples:
            >>> AutoStartResolver.check_single_vm_auto_start({"auto_start": True})
            True
            >>> AutoStartResolver.check_single_vm_auto_start({"auto_start": False})
            False
            >>> AutoStartResolver.check_single_vm_auto_start({})
            True
        """
        return vm_config.get("auto_start", True)
