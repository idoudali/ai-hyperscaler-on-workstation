"""Configuration processing and variable expansion using expandvars."""

import os
from pathlib import Path
from typing import Any

import yaml
from expandvars import UnboundVariable, expandvars  # type: ignore[import-untyped]


class ConfigProcessor:
    """Processes cluster configuration with bash-compatible variable expansion."""

    def __init__(self, template_path: Path, output_path: Path | None = None):
        """Initialize config processor.

        Args:
            template_path: Path to the template configuration file
            output_path: Path to write processed configuration (optional)
        """
        self.template_path = template_path
        self.output_path = output_path or template_path.parent / f"{template_path.stem}.yaml"
        self.project_root = self._find_project_root()

    def _find_project_root(self) -> Path:
        """Find the project root directory by looking for project indicators."""
        current_path = self.template_path.parent

        # Look up the directory tree for project indicators
        for _ in range(10):  # Limit search depth
            # Look for common project root indicators
            if any((current_path / indicator).exists() for indicator in [".git"]):
                return current_path
            if current_path.parent == current_path:  # Reached filesystem root
                break
            current_path = current_path.parent

        # Fallback to template file directory
        return self.template_path.parent

    def _expand_variables(self, value: Any) -> Any:
        """Recursively expand variables in configuration values.

        Args:
            value: Configuration value (string, dict, list, etc.)

        Returns:
            Value with variables expanded

        Raises:
            UnboundVariable: If a required variable is not defined
        """
        if isinstance(value, str):
            return self._expand_string_variables(value)
        elif isinstance(value, dict):
            return {k: self._expand_variables(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [self._expand_variables(item) for item in value]
        else:
            return value

    def _expand_string_variables(self, text: str) -> str:
        """Expand bash-compatible variables in a string.

        Supports bash variable expansion syntax:
        - $VAR or ${VAR}: Basic variable expansion
        - ${VAR:-default}: Use default value if VAR is not set
        - ${VAR:=default}: Use default value and set VAR if not set
        - ${VAR:?error}: Raise error if VAR is not set
        - ${VAR:+value}: Use value if VAR is set, empty if not
        - $$: Literal dollar sign

        Args:
            text: String that may contain variables

        Returns:
            String with variables expanded

        Raises:
            UnboundVariable: If a required variable is not defined
        """
        try:
            # Set up custom environment variables
            original_tot = os.environ.get("TOT")
            original_pwd = os.environ.get("PWD")

            # Set project-specific variables
            os.environ["TOT"] = str(self.project_root.absolute())  # Top of tree (project root)
            os.environ["PWD"] = str(Path.cwd())  # Current working directory

            try:
                # Use expandvars with strict mode for better error handling
                return expandvars(text, nounset=True)
            finally:
                # Restore original environment variables
                if original_tot is not None:
                    os.environ["TOT"] = original_tot
                elif "TOT" in os.environ:
                    del os.environ["TOT"]

                if original_pwd is not None:
                    os.environ["PWD"] = original_pwd
                elif "PWD" in os.environ:
                    del os.environ["PWD"]

        except UnboundVariable as e:
            # Provide more helpful error messages
            error_str = str(e)
            if "'" in error_str and ": " in error_str:
                # Extract variable name from "'VAR_NAME: unbound variable'"
                var_name = error_str.split("'")[1].split(": ")[0]
            elif "'" in error_str:
                var_name = error_str.split("'")[1]
            elif ": " in error_str:
                var_name = error_str.split(": ")[0]
            else:
                var_name = "unknown"
            raise UnboundVariable(
                f"Required variable '{var_name}' is not defined in template: {self.template_path}\n"
                f"Available variables: TOT, PWD, HOME, USER, and all system environment variables\n"
                f"Use ${{{var_name}:-default}} to provide a default value"
            ) from e

    def process_config(self) -> dict[str, Any]:
        """Process template configuration with variable expansion.

        Returns:
            Processed configuration dictionary

        Raises:
            UnboundVariable: If a required variable is not defined
            yaml.YAMLError: If template YAML is invalid
            FileNotFoundError: If template file doesn't exist
        """
        # Load template configuration
        with open(self.template_path, encoding="utf-8") as f:
            template_config = yaml.safe_load(f)

        if template_config is None:
            raise yaml.YAMLError(f"Template file is empty or invalid: {self.template_path}")

        # Expand variables in the configuration
        processed_config = self._expand_variables(template_config)

        # Write processed configuration
        with open(self.output_path, "w", encoding="utf-8") as f:
            yaml.dump(processed_config, f, default_flow_style=False, sort_keys=False)

        return processed_config

    def get_variables_found(self, config: dict[str, Any]) -> dict[str, int]:
        """Count variables found in the configuration.

        Args:
            config: Configuration dictionary to analyze

        Returns:
            Dictionary mapping variable names to their count
        """
        import re

        variables_found: dict[str, int] = {}

        def count_variables(value: Any) -> None:
            if isinstance(value, str):
                # Find all bash-style variables in the string
                # Pattern matches: $VAR, ${VAR}, ${VAR:-default}, ${VAR:?error}, etc.
                pattern = r"\$\{([^}:]+)(?::[^}]*)?\}|\$([A-Za-z_][A-Za-z0-9_]*)"
                matches = re.findall(pattern, value)
                for match in matches:
                    var_name = match[0] or match[1]
                    variables_found[var_name] = variables_found.get(var_name, 0) + 1
            elif isinstance(value, dict):
                for v in value.values():
                    count_variables(v)
            elif isinstance(value, list):
                for item in value:
                    count_variables(item)

        count_variables(config)
        return variables_found

    def validate_template(self) -> dict[str, Any]:
        """Validate template without processing it.

        Returns:
            Dictionary with validation results

        Raises:
            yaml.YAMLError: If template YAML is invalid
            FileNotFoundError: If template file doesn't exist
        """
        # Load template configuration
        with open(self.template_path, encoding="utf-8") as f:
            template_config = yaml.safe_load(f)

        if template_config is None:
            raise yaml.YAMLError(f"Template file is empty or invalid: {self.template_path}")

        # Count variables without expanding them
        variables_found = self.get_variables_found(template_config)

        return {
            "template_path": str(self.template_path),
            "variables_found": variables_found,
            "total_variables": sum(variables_found.values()),
            "unique_variables": len(variables_found),
            "is_valid_yaml": True,
        }
