"""Inventory output formatters for different Ansible inventory formats."""

import json
from abc import ABC, abstractmethod
from typing import Any

import yaml


class BaseFormatter(ABC):
    """Base class for inventory formatters."""

    @abstractmethod
    def format(self, inventory: dict[str, Any]) -> str:
        """Format inventory data into string representation.

        Args:
            inventory: Inventory data structure

        Returns:
            Formatted inventory as string
        """
        pass


class INIFormatter(BaseFormatter):
    """Format inventory as INI file (Ansible's native format).

    Generates inventory in the classic INI format with sections for groups,
    inline host variables, and group variables.

    Example output:
        [all]
        host1 ansible_host=192.168.1.10 var1=value1

        [group1]
        host1

        [group1:vars]
        group_var=value
    """

    def format(self, inventory: dict[str, Any]) -> str:
        """Format inventory as INI.

        Args:
            inventory: Inventory data with structure:
                {
                    'groups': {
                        'group_name': {
                            'hosts': {'host1': {'var1': 'val1'}, ...},
                            'children': ['child_group'],
                            'vars': {'group_var': 'value'}
                        }
                    }
                }

        Returns:
            INI formatted inventory string
        """
        lines = []
        groups = inventory.get("groups", {})

        # First pass: Generate all host definitions in [all] section
        all_hosts: dict[str, dict[str, Any]] = {}
        for _group_name, group_data in groups.items():
            hosts = group_data.get("hosts", {})
            for host_name, host_vars in hosts.items():
                if host_name not in all_hosts:
                    all_hosts[host_name] = host_vars
                else:
                    # Merge variables from multiple groups
                    all_hosts[host_name].update(host_vars)

        # Write [all] section with full host definitions
        if all_hosts:
            lines.append("[all]")
            for host_name, host_vars in sorted(all_hosts.items()):
                host_line = self._format_host_line(host_name, host_vars)
                lines.append(host_line)
            lines.append("")

        # Collect all groups referenced as children
        referenced_groups = set()
        for group_data in groups.values():
            children = group_data.get("children", [])
            referenced_groups.update(children)

        # Second pass: Generate group sections
        for group_name, group_data in sorted(groups.items()):
            # Skip the 'all' group as it's already written
            if group_name == "all":
                continue

            # Write group hosts (or empty group if referenced as a child)
            hosts = group_data.get("hosts", {})
            if hosts or group_name in referenced_groups:
                lines.append(f"[{group_name}]")
                for host_name in sorted(hosts.keys()):
                    lines.append(host_name)
                lines.append("")

            # Write group children
            children = group_data.get("children", [])
            if children:
                lines.append(f"[{group_name}:children]")
                for child in sorted(children):
                    lines.append(child)
                lines.append("")

            # Write group vars
            group_vars = group_data.get("vars", {})
            if group_vars:
                lines.append(f"[{group_name}:vars]")
                for var_name, var_value in sorted(group_vars.items()):
                    lines.append(self._format_var_line(var_name, var_value))
                lines.append("")

        return "\n".join(lines)

    def _format_host_line(self, host_name: str, host_vars: dict[str, Any]) -> str:
        """Format a host definition line with inline variables.

        Args:
            host_name: Name of the host
            host_vars: Dictionary of host variables

        Returns:
            Formatted host line with inline variables
        """
        parts = [host_name]

        for var_name, var_value in sorted(host_vars.items()):
            var_str = self._format_var_assignment(var_name, var_value)
            parts.append(var_str)

        return " ".join(parts)

    def _format_var_line(self, var_name: str, var_value: Any) -> str:
        """Format a variable assignment line.

        Args:
            var_name: Variable name
            var_value: Variable value

        Returns:
            Formatted variable assignment
        """
        return self._format_var_assignment(var_name, var_value)

    def _format_var_assignment(self, var_name: str, var_value: Any) -> str:
        """Format a variable assignment.

        Complex types (lists, dicts) are JSON-encoded.

        Args:
            var_name: Variable name
            var_value: Variable value

        Returns:
            Formatted variable assignment string
        """
        if isinstance(var_value, dict | list):
            # JSON encode complex types for Ansible
            value_str = json.dumps(var_value, separators=(",", ":"))
        elif isinstance(var_value, bool):
            value_str = "true" if var_value else "false"
        elif var_value is None:
            value_str = ""
        else:
            value_str = str(var_value)

        return f"{var_name}={value_str}"


class YAMLFormatter(BaseFormatter):
    """Format inventory as YAML file.

    Generates inventory in YAML format following Ansible's inventory structure.

    Example output:
        all:
          children:
            group1:
              hosts:
                host1:
                  ansible_host: 192.168.1.10
              vars:
                group_var: value
    """

    def format(self, inventory: dict[str, Any]) -> str:
        """Format inventory as YAML.

        Args:
            inventory: Inventory data with structure matching INI format
                but will be converted to Ansible YAML inventory structure

        Returns:
            YAML formatted inventory string
        """
        # Convert flat groups structure to hierarchical Ansible YAML format
        yaml_inventory = {"all": {"children": {}}}

        groups = inventory.get("groups", {})

        for group_name, group_data in groups.items():
            if group_name == "all":
                # Skip the 'all' group in conversion
                continue

            group_entry: dict[str, Any] = {}

            # Add hosts
            hosts = group_data.get("hosts", {})
            if hosts:
                group_entry["hosts"] = hosts

            # Add children
            children_list = group_data.get("children", [])
            if children_list:
                group_entry["children"] = children_list

            # Add vars
            vars_dict = group_data.get("vars", {})
            if vars_dict:
                group_entry["vars"] = vars_dict

            yaml_inventory["all"]["children"][group_name] = group_entry

        return yaml.dump(
            yaml_inventory,
            default_flow_style=False,
            sort_keys=False,
            indent=2,
            allow_unicode=True,
        )
