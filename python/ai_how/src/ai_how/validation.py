#!/usr/bin/env python3
import json
import sys
from pathlib import Path

import jsonschema
import yaml
from jsonschema import exceptions as jsonschema_exceptions
from rich.console import Console

# Default console instance - can be overridden for testing
_console = Console()


def get_console() -> Console:
    """Get the console instance. Can be overridden for testing."""
    return _console


def set_console(console: Console) -> None:
    """Set the console instance. Useful for testing with mock consoles."""
    global _console
    _console = console


def find_project_root(marker_file: str = "pyproject.toml", max_depth: int = 25) -> Path:
    """
    Find the project root by looking for a marker file.

    Args:
        marker_file: Name of the marker file to search for (default: pyproject.toml)
        max_depth: Maximum number of parent directories to traverse (default: 25)

    Returns:
        Path to the project root directory

    Raises:
        FileNotFoundError: If the marker file cannot be found or max_depth is exceeded
    """
    current = Path(__file__).resolve()
    depth = 0
    while current != current.parent and depth < max_depth:
        if (current / marker_file).exists():
            return current
        current = current.parent
        depth += 1
    raise FileNotFoundError(
        f"Could not find {marker_file} in any parent directory (searched up to {max_depth} levels)"
    )


def validate_config(config_path: Path, schema_path: Path, console: Console | None = None) -> bool:
    """
    Validates a YAML configuration file against a JSON schema.

    Args:
        config_path: Path to the YAML configuration file.
        schema_path: Path to the JSON schema file.
        console: Console instance to use for output. If None, uses the default console.

    Returns:
        True if validation is successful, False otherwise.
    """
    if console is None:
        console = get_console()

    try:
        with open(config_path, encoding="utf-8") as f:
            config_data = yaml.safe_load(f)
    except FileNotFoundError:
        console.print(
            f"[red]Error:[/red] Configuration file not found at "
            f"[bold]{config_path.resolve()}[/bold]"
        )
        return False
    except yaml.YAMLError as e:
        console.print(f"[red]Error:[/red] Could not parse YAML file: {e}")
        return False

    try:
        with open(schema_path, encoding="utf-8") as f:
            schema_data = json.load(f)
    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Schema file not found at [bold]{schema_path}[/bold]")
        return False
    except json.JSONDecodeError as e:
        console.print(f"[red]Error:[/red] Could not parse JSON schema: {e}")
        return False

    try:
        validator = jsonschema.Draft7Validator(schema_data)
        errors = list(validator.iter_errors(config_data))

        if not errors:
            console.print("[green]✅ Configuration is valid.[/green]")
            return True

        # Report all validation errors
        console.print(
            f"[red]❌ Configuration validation failed with {len(errors)} error(s):[/red]\n"
        )

        for i, error in enumerate(errors, 1):
            # Build the path to the error location
            path_str = " → ".join(str(p) for p in error.path) if error.path else "root"

            console.print(f"[yellow]Error {i}:[/yellow] At [cyan]{path_str}[/cyan]")
            console.print(f"  {error.message}")

            # Show specific details for additional properties errors
            if error.validator == "additionalProperties" and isinstance(error.instance, dict):
                allowed_props = error.schema.get("properties", {}).keys()
                actual_props = set(error.instance.keys())
                extra_props = actual_props - set(allowed_props)
                if extra_props:
                    console.print(
                        f"  [red]Unexpected field(s):[/red] {', '.join(sorted(extra_props))}"
                    )
                    console.print(
                        f"  [green]Allowed fields:[/green] {', '.join(sorted(allowed_props))}"
                    )

            console.print()  # Empty line between errors

        return False
    except jsonschema_exceptions.SchemaError as e:
        console.print(f"[red]Schema error during validation:[/red]\n{e}")
        return False


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate a YAML configuration file against a JSON schema."
    )
    parser.add_argument(
        "--config",
        type=str,
        default=None,
        help="Path to the YAML configuration file (default: config/cluster.yaml at project root)",
    )
    parser.add_argument(
        "--schema",
        type=str,
        default=None,
        help="Path to the JSON schema file (default: schemas/cluster.schema.json at project root)",
    )
    args = parser.parse_args()

    try:
        project_root = find_project_root("pyproject.toml")
        config_path = Path(args.config) if args.config else project_root / "config/cluster.yaml"
        schema_path = (
            Path(args.schema) if args.schema else project_root / "schemas/cluster.schema.json"
        )

        success = validate_config(config_path, schema_path)
        if not success:
            get_console().print(
                "[yellow]You can specify alternative paths using --config and --schema.[/yellow]"
            )
            sys.exit(1)
    except FileNotFoundError as e:
        get_console().print(f"[red]Error:[/red] {e}")
        get_console().print(
            "[yellow]You can specify alternative paths using --config and --schema.[/yellow]"
        )
        sys.exit(1)
    except Exception as e:
        get_console().print(f"[red]An unexpected error occurred during validation:[/red]\n{e}")
        sys.exit(1)
