from __future__ import annotations

import importlib.resources
import json
import logging
import sys
from pathlib import Path
from typing import Annotated, Any, Union

import typer
import yaml
from expandvars import UnboundVariable  # type: ignore[import-untyped]
from rich.console import Console
from rich.table import Table

from ai_how.config import ConfigProcessor
from ai_how.pcie_validation.pcie_passthrough import PCIePassthroughValidator
from ai_how.resource_management.gpu_allocator import GPUResourceAllocator
from ai_how.state.cluster_state import ClusterStateManager, VMState
from ai_how.system_manager import SystemClusterManager, SystemManagerError
from ai_how.utils.logging import configure_logging
from ai_how.utils.virsh_utils import get_domain_ip
from ai_how.validation import validate_config
from ai_how.vm_management.cloud_manager import CloudClusterManager, CloudManagerError
from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError
from ai_how.vm_management.libvirt_client import LibvirtClient
from ai_how.vm_management.vm_lifecycle import VMLifecycleError, VMLifecycleManager

app = typer.Typer(help="AI-HOW CLI for managing HPC and Cloud clusters")
console = Console()
console_err = Console(file=sys.stderr)


def load_and_render_config(config_path: Path) -> dict[str, Any]:
    """Load and render configuration template with variable expansion.

    Args:
        config_path: Path to the configuration file

    Returns:
        Rendered configuration dictionary

    Raises:
        UnboundVariable: If a required variable is not defined
        yaml.YAMLError: If configuration YAML is invalid
        FileNotFoundError: If configuration file doesn't exist
    """
    # Check if the file is a template (contains variables)
    with open(config_path, encoding="utf-8") as f:
        content = f.read()

    # If the file contains variables, render it
    if "${" in content:
        # Create a temporary output path to avoid overwriting the original
        import tempfile

        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as temp_file:
            temp_output_path = Path(temp_file.name)

        try:
            processor = ConfigProcessor(config_path, temp_output_path)
            result = processor.process_config()
            # Clean up the temporary file
            temp_output_path.unlink()
            return result
        except Exception:
            # Clean up the temporary file on error
            if temp_output_path.exists():
                temp_output_path.unlink()
            raise
    else:
        # No variables, load directly
        with open(config_path, encoding="utf-8") as f:
            return yaml.safe_load(f)


def validate_config_against_schema(config_path: Path) -> bool:
    """Validate configuration against JSON schema.

    Args:
        config_path: Path to the configuration file

    Returns:
        True if validation passes, False otherwise
    """
    # Get logger for this module
    logger = logging.getLogger(__name__)

    try:
        # Load schema
        schema_resource = importlib.resources.files("ai_how.schemas").joinpath(
            CLUSTER_SCHEMA_FILENAME
        )
        with importlib.resources.as_file(schema_resource) as schema_path:
            # Load and render config first
            config_data = load_and_render_config(config_path)

            # Write to temporary file for validation
            import tempfile

            with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as temp_file:
                yaml.dump(config_data, temp_file)
                temp_config_path = Path(temp_file.name)

            try:
                # Validate using the validation module
                if not validate_config(temp_config_path, schema_path, console):
                    logger.error("Configuration validation failed")
                    return False
                return True
            finally:
                # Clean up temp file
                if temp_config_path.exists():
                    temp_config_path.unlink()

    except Exception as e:
        logger.error(f"Validation error: {e}")
        console.print(f"[red]Error during validation:[/red] {e}")
        return False


def abort_not_implemented(feature: str) -> None:
    console.print(f"[yellow]Not implemented:[/yellow] {feature}")
    raise typer.Exit(code=2)


DEFAULT_CONFIG: Path = Path("config/cluster.yaml")
DEFAULT_STATE: Path = Path("output/state.json")
CLUSTER_SCHEMA_FILENAME: str = "cluster.schema.json"


@app.callback()
def main(
    ctx: typer.Context,
    state: Annotated[
        Path,
        typer.Option(exists=False, dir_okay=False, help="Path to CLI state file"),
    ] = DEFAULT_STATE,
    log_level: Annotated[
        str,
        typer.Option(
            "--log-level",
            help="Set logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)",
        ),
    ] = "INFO",
    log_file: Annotated[
        Union[Path, None],  # noqa: UP007
        typer.Option(
            "--log-file",
            exists=False,
            dir_okay=False,
            help="Path to log file (optional)",
        ),
    ] = None,
    verbose: Annotated[
        bool,
        typer.Option(
            "--verbose",
            "-v",
            help="Enable verbose output (equivalent to --log-level DEBUG)",
        ),
    ] = False,
) -> None:
    """AI-HOW CLI for managing HPC and Cloud clusters."""
    # Configure logging based on options
    actual_log_level = "DEBUG" if verbose else log_level.upper()

    # Create default log file if not specified but debug level requested
    actual_log_file = log_file
    if actual_log_level == "DEBUG" and log_file is None:
        actual_log_file = Path("output/ai-how.log")

    # Check if this is a JSON output command by examining Typer context
    is_json_output = False
    # Try to detect if the current command is 'plan clusters' and --format/-f is 'json'
    command_path = ctx.command_path if hasattr(ctx, "command_path") else ""
    params = ctx.params if hasattr(ctx, "params") else {}
    if "plan clusters" in command_path and params.get("format", None) == "json":
        is_json_output = True

    configure_logging(
        level=actual_log_level,
        log_file=actual_log_file,
        console_output=not is_json_output,  # Disable console output for JSON commands
        include_timestamps=(actual_log_level == "DEBUG"),
        silent=is_json_output,  # Silent for JSON output
    )

    # Get logger for this module
    logger = logging.getLogger(__name__)
    if not is_json_output:
        logger.debug(f"CLI initialized with state={state}, log_level={actual_log_level}")

    ctx.obj = {
        "state": state,
        "log_level": actual_log_level,
        "log_file": actual_log_file,
    }


@app.command()
def validate(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
    skip_pcie_validation: Annotated[
        bool,
        typer.Option(
            "--skip-pcie-validation",
            help="Skip PCIe passthrough validation (use only for basic schema validation)",
        ),
    ] = False,
) -> None:  # noqa: ARG001
    """Validate cluster.yaml against schema and semantic rules.

    This command performs comprehensive validation including:
    - JSON schema validation
    - PCIe passthrough configuration validation
    - System readiness checks for VFIO and IOMMU
    """
    # Get logger for this module to show that logging is working
    logger = logging.getLogger(__name__)
    logger.info(f"Starting validation with log level: {ctx.obj.get('log_level', 'INFO')}")

    console.print(f"Validating {config}...")

    try:
        # Load and render configuration for validation
        config_data = load_and_render_config(config)

        # Step 1: Schema validation
        console.print("🔍 [cyan]Step 1:[/cyan] Schema validation...")
        schema_resource = importlib.resources.files("ai_how.schemas").joinpath(
            CLUSTER_SCHEMA_FILENAME
        )
        with importlib.resources.as_file(schema_resource) as schema_path:
            # Write rendered config to temp file for validation
            import tempfile

            with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as temp_file:
                yaml.dump(config_data, temp_file)
                temp_config_path = Path(temp_file.name)

            try:
                if not validate_config(temp_config_path, schema_path):
                    raise typer.Exit(code=1)
            finally:
                # Clean up temp file
                if temp_config_path.exists():
                    temp_config_path.unlink()

        console.print("[green]✅ Schema validation passed[/green]")

        # Step 2: PCIe passthrough validation (if not skipped)
        if not skip_pcie_validation:
            console.print("🔍 [cyan]Step 2:[/cyan] PCIe passthrough validation...")

            try:
                pcie_validator = PCIePassthroughValidator()
                pcie_validator.validate_pcie_passthrough_config(config_data)
                console.print("[green]✅ PCIe passthrough validation passed[/green]")

                # Show PCIe device status summary
                _display_pcie_validation_summary(pcie_validator, config_data)

            except ValueError as e:
                console.print(f"[red]❌ PCIe passthrough validation failed:[/red] {e}")
                console.print("\n[yellow]To fix PCIe passthrough issues:[/yellow]")
                console.print("1. Ensure IOMMU is enabled in BIOS (Intel VT-d or AMD IOMMU)")
                console.print("2. Add kernel parameters: intel_iommu=on or amd_iommu=on")
                console.print("3. Load VFIO modules: modprobe vfio vfio_iommu_type1 vfio_pci")
                console.print("4. Bind GPU devices to VFIO driver instead of NVIDIA driver")
                console.print("5. Use --skip-pcie-validation to bypass this check if needed")
                raise typer.Exit(code=1) from None
        else:
            console.print("[yellow]⚠️  PCIe passthrough validation skipped[/yellow]")

        console.print(f"\n[green]🎉 All validations passed for {config}[/green]")

    except FileNotFoundError:
        logger.error(f"Configuration file not found: {config}")
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except yaml.YAMLError as e:
        logger.error(f"Invalid YAML in config file: {e}")
        console.print(f"[red]Error:[/red] Invalid YAML in config file: {e}")
        raise typer.Exit(code=1) from e
    except ModuleNotFoundError as e:
        console.print(f"[red]Error:[/red] Could not locate schema file: {e}")
        raise typer.Exit(code=1) from e


@app.command()
def render(
    template: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to template configuration file with bash variables",
        ),
    ],
    output: Annotated[
        Path | None,
        typer.Option(
            "--output",
            "-o",
            help="Output path for rendered configuration (default: stdout)",
        ),
    ] = None,
    show_variables: Annotated[
        bool,
        typer.Option(
            "--show-variables",
            help="Show which variables were found and expanded",
        ),
    ] = False,
    validate_only: Annotated[
        bool,
        typer.Option(
            "--validate-only",
            help="Only validate template without rendering (useful for CI/CD)",
        ),
    ] = False,
) -> None:
    """Render template configuration with bash-compatible variable expansion.

    This command processes a template configuration file that contains bash-style
    variables and outputs the rendered configuration with all variables expanded.

    If no output file is specified with -o, the rendered configuration is printed
    to stdout (useful for piping to other commands or reviewing before saving).

    Supported variable syntax:
    - $VAR or ${VAR}: Basic variable expansion
    - ${VAR:-default}: Use default value if VAR is not set
    - ${VAR:=default}: Use default value and set VAR if not set
    - ${VAR:?error}: Raise error if VAR is not set
    - ${VAR:+value}: Use value if VAR is set, empty if not
    - $$: Literal dollar sign

    Special variables:
    - $TOT: Project root directory (top of tree)
    - $PWD: Current working directory
    - $HOME: User home directory
    - $USER: Username
    - All system environment variables

    Examples:
        # Render template and print to stdout
        ai-how render config/cluster.template.yaml

        # Render template and save to file
        ai-how render config/cluster.template.yaml -o config/cluster.yaml

        # Show which variables were expanded
        ai-how render config/cluster.template.yaml --show-variables

        # Validate template without rendering (useful for CI/CD)
        ai-how render config/cluster.template.yaml --validate-only
    """
    try:
        console_err.print(f"🔧 [cyan]Processing template:[/cyan] {template}")

        # Use a temporary file for processing
        import tempfile

        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as temp_file:
            temp_path = Path(temp_file.name)

        try:
            # Initialize processor with temporary file
            processor = ConfigProcessor(template, temp_path)

            if validate_only:
                # Only validate the template
                console_err.print("🔍 [cyan]Validating template (no rendering)...[/cyan]")
                validation_result = processor.validate_template()

                console_err.print("[green]✅ Template validation successful![/green]")
                console_err.print(f"📁 Template: {validation_result['template_path']}")
                console_err.print(
                    f"🔢 Variables found: {validation_result['total_variables']} total, "
                    f"{validation_result['unique_variables']} unique"
                )

                if show_variables and validation_result["variables_found"]:
                    console_err.print("\n🔍 [cyan]Variables detected:[/cyan]")
                    for var_name, count in validation_result["variables_found"].items():
                        console_err.print(
                            f"  - ${var_name}: {count} occurrence{'s' if count > 1 else ''}"
                        )

                return

            # Process the configuration
            config_data = processor.process_config()

            if output is None:
                # Print rendered template to stdout
                with open(temp_path, encoding="utf-8") as f:
                    rendered_content = f.read()
                    # Print to stdout directly (not stderr)
                    print(rendered_content)

                # Show metadata on stderr
                if show_variables:
                    variables_found = processor.get_variables_found(config_data)
                    if variables_found:
                        console_err.print("\n🔍 [cyan]Variables expanded:[/cyan]")
                        for var_name, count in variables_found.items():
                            console_err.print(
                                f"  - ${var_name}: {count} occurrence{'s' if count > 1 else ''}"
                            )

            else:
                # Write to specified output file
                output.parent.mkdir(parents=True, exist_ok=True)
                with (
                    open(temp_path, encoding="utf-8") as src,
                    open(output, "w", encoding="utf-8") as dst,
                ):
                    dst.write(src.read())

                console_err.print("[green]✅ Template rendered successfully![/green]")
                console_err.print(f"📁 Input template: {template}")
                console_err.print(f"📁 Output config: {output}")

                # Show variables if requested
                if show_variables:
                    variables_found = processor.get_variables_found(config_data)
                    if variables_found:
                        console_err.print("\n🔍 [cyan]Variables expanded:[/cyan]")
                        for var_name, count in variables_found.items():
                            console_err.print(
                                f"  - ${var_name}: {count} occurrence{'s' if count > 1 else ''}"
                            )
                    else:
                        console_err.print("\nℹ️  [yellow]No variables found in template[/yellow]")

                # Show file size info
                input_size = template.stat().st_size
                output_size = output.stat().st_size
                console_err.print("\n📊 [cyan]File info:[/cyan]")
                console_err.print(f"  - Template size: {input_size:,} bytes")
                console_err.print(f"  - Rendered size: {output_size:,} bytes")

        finally:
            # Clean up temporary file
            if temp_path.exists():
                temp_path.unlink()

    except UnboundVariable as e:
        console.print("[red]❌ Variable expansion error:[/red]")
        console.print(f"   {e}")
        console.print("\n[yellow]💡 Tips:[/yellow]")
        console.print(f"   - Use ${'{VAR:-default}'} to provide default values")
        console.print(f"   - Use ${'{VAR:?error message}'} for required variables")
        console.print("   - Check that all required environment variables are set")
        raise typer.Exit(code=1) from e
    except FileNotFoundError as e:
        console.print(f"[red]❌ Template file not found:[/red] {e}")
        raise typer.Exit(code=1) from e
    except yaml.YAMLError as e:
        console.print(f"[red]❌ Invalid YAML in template:[/red] {e}")
        console.print("\n[yellow]💡 Check your YAML syntax and indentation[/yellow]")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]❌ Unexpected error processing template:[/red] {e}")
        console.print("\n[yellow]💡 Check template file and try again[/yellow]")
        raise typer.Exit(code=1) from e


hpc = typer.Typer(help="HPC cluster lifecycle")
cloud = typer.Typer(help="Cloud (K8s) cluster lifecycle")
app.add_typer(hpc, name="hpc")
app.add_typer(cloud, name="cloud")


@hpc.command()
def start(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ],
) -> None:
    """Start the HPC cluster with full lifecycle management.

    This command will:
    - Validate cluster configuration
    - Create VM disks from base images
    - Generate and apply libvirt XML definitions
    - Start all cluster VMs (controller + compute nodes)
    - Track cluster state for management

    Use --verbose for detailed operation logging.
    """
    state_path = ctx.obj["state"]

    # Get logger for CLI operations
    logger = logging.getLogger(__name__)
    logger.info(f"Starting HPC cluster using config: {config}")

    console.print(f"Starting HPC cluster using config: {config}")

    try:
        # Validate configuration against schema
        console.print("🔍 [cyan]Validating configuration...[/cyan]")
        if not validate_config_against_schema(config):
            console.print(
                "[red]❌ Configuration validation failed. Please fix the errors above.[/red]"
            )
            raise typer.Exit(code=1)

        # Load and render configuration
        logger.debug(f"Loading and rendering configuration from: {config}")
        config_data = load_and_render_config(config)
        logger.debug("Configuration loaded and rendered successfully")

        # Initialize HPC manager
        logger.debug("Initializing HPC cluster manager")
        hpc_manager = HPCClusterManager(config_data, state_path)

        # Start the cluster
        logger.info("Beginning cluster startup process")
        success = hpc_manager.start_cluster()

        if success:
            console.print("[green]✅ HPC cluster started successfully![/green]")
            logger.info("HPC cluster startup completed successfully")

            # Show cluster status
            status = hpc_manager.status_cluster()
            _display_cluster_status(status)
        else:
            console.print("[red]❌ Failed to start HPC cluster[/red]")
            logger.error("HPC cluster startup failed")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        logger.error(f"Configuration file not found: {config}")
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except yaml.YAMLError as e:
        logger.error(f"Invalid YAML in config file: {e}")
        console.print(f"[red]Error:[/red] Invalid YAML in config file: {e}")
        raise typer.Exit(code=1) from e
    except HPCManagerError as e:
        logger.error(f"HPC management error: {e}")
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    # except Exception as e:
    #     logger.error(f"Unexpected error during cluster start: {e}")
    #     console.print(f"[red]Unexpected error:[/red] {e}")
    #     raise typer.Exit(code=1) from e


@hpc.command()
def stop(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ],
) -> None:
    """Stop the HPC cluster gracefully."""
    state_path = ctx.obj["state"]

    console.print("Stopping HPC cluster...")

    try:
        # Load and render configuration
        config_data = load_and_render_config(config)

        # Initialize HPC manager
        hpc_manager = HPCClusterManager(config_data, state_path)

        # Stop the cluster
        success = hpc_manager.stop_cluster()

        if success:
            console.print("[green]✅ HPC cluster stopped successfully![/green]")
        else:
            console.print("[red]❌ Failed to stop HPC cluster[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except HPCManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@hpc.command()
def status(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ],
) -> None:
    """Show HPC cluster status."""
    state_path = ctx.obj["state"]

    try:
        # Load and render configuration
        config_data = load_and_render_config(config)

        # Initialize HPC manager
        hpc_manager = HPCClusterManager(config_data, state_path)

        # Get cluster status
        status_data = hpc_manager.status_cluster()
        _display_cluster_status(status_data)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except HPCManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@hpc.command()
def destroy(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ],
    force: Annotated[bool, typer.Option("--force", help="Skip confirmation prompt")] = False,
) -> None:
    """Destroy the HPC cluster and clean up all resources."""
    state_path = ctx.obj["state"]

    if not force:
        confirm = typer.confirm(
            "This will permanently destroy the HPC cluster and all its data. "
            "Are you sure you want to continue?"
        )
        if not confirm:
            console.print("Operation cancelled.")
            return

    console.print("Destroying HPC cluster...")

    try:
        # Load and render configuration
        config_data = load_and_render_config(config)

        # Initialize HPC manager
        hpc_manager = HPCClusterManager(config_data, state_path)

        # Destroy the cluster
        success = hpc_manager.destroy_cluster()

        if success:
            console.print("[green]✅ HPC cluster destroyed successfully![/green]")
        else:
            console.print("[red]❌ Failed to destroy HPC cluster[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except HPCManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@cloud.command("start")
def cloud_start(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Start the Cloud cluster with GPU resource management."""
    state_path = ctx.obj["state"]

    console.print(f"Starting Cloud cluster using config: {config}")

    try:
        # Validate configuration against schema
        console.print("🔍 [cyan]Validating configuration...[/cyan]")
        if not validate_config_against_schema(config):
            console.print(
                "[red]❌ Configuration validation failed. Please fix the errors above.[/red]"
            )
            raise typer.Exit(code=1)

        # Load and render configuration
        config_data = load_and_render_config(config)

        # Initialize Cloud manager
        cloud_manager = CloudClusterManager(config_data, state_path)

        # Start the cluster
        success = cloud_manager.start_cluster()

        if success:
            console.print("[green]✅ Cloud cluster started successfully![/green]")
        else:
            console.print("[red]❌ Failed to start Cloud cluster[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except CloudManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@cloud.command("stop")
def cloud_stop(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Stop the Cloud cluster."""
    state_path = ctx.obj["state"]

    console.print("Stopping Cloud cluster...")

    try:
        # Load configuration
        config_data = load_and_render_config(config)

        # Initialize Cloud manager
        cloud_manager = CloudClusterManager(config_data, state_path)

        # Stop the cluster
        success = cloud_manager.stop_cluster()

        if success:
            console.print("[green]✅ Cloud cluster stopped successfully![/green]")
        else:
            console.print("[red]❌ Failed to stop Cloud cluster[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except CloudManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@cloud.command("status")
def cloud_status(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Show Cloud cluster status."""
    state_path = ctx.obj["state"]

    try:
        # Load configuration
        config_data = load_and_render_config(config)

        # Initialize Cloud manager
        cloud_manager = CloudClusterManager(config_data, state_path)

        # Get status
        status = cloud_manager.status()

        # Display status
        table = Table(title="Cloud Cluster Status")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        for key, value in status.items():
            table.add_row(str(key), str(value))

        console.print(table)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except CloudManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@cloud.command("destroy")
def cloud_destroy(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
    force: Annotated[bool, typer.Option("--force", help="Skip confirmation prompt")] = False,
) -> None:
    """Destroy the Cloud cluster and clean up all resources."""
    state_path = ctx.obj["state"]

    if not force:
        confirm = typer.confirm(
            "This will permanently destroy the Cloud cluster and all its data. "
            "Are you sure you want to continue?"
        )
        if not confirm:
            console.print("Operation cancelled.")
            return

    console.print("Destroying Cloud cluster...")

    try:
        # Load configuration
        config_data = load_and_render_config(config)

        # Initialize Cloud manager
        cloud_manager = CloudClusterManager(config_data, state_path)

        # Destroy the cluster
        success = cloud_manager.destroy_cluster(force=force)

        if success:
            console.print("[green]✅ Cloud cluster destroyed successfully![/green]")
        else:
            console.print("[red]❌ Failed to destroy Cloud cluster[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError:
        console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        raise typer.Exit(code=1) from None
    except CloudManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


vm_app = typer.Typer(help="Individual VM lifecycle management")
app.add_typer(vm_app, name="vm")


@vm_app.command("stop")
def vm_stop(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to stop")],
    force: Annotated[bool, typer.Option("--force", help="Force stop the VM")] = False,
) -> None:
    """Stop an individual VM with GPU resource release."""
    state_path = ctx.obj["state"]

    console.print(f"Stopping VM: {vm_name}")

    try:
        # Load state to determine which cluster the VM belongs to
        state_manager = ClusterStateManager(state_path)
        cluster_state = state_manager.get_state()

        if not cluster_state:
            console.print("[red]Error:[/red] No cluster state found")
            raise typer.Exit(code=1)

        vm_info = cluster_state.get_vm_by_name(vm_name)
        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager with state manager and GPU allocator
        libvirt_client = LibvirtClient()
        gpu_allocator = GPUResourceAllocator(state_path.parent / "global-state.json")
        vm_lifecycle = VMLifecycleManager(
            libvirt_client, state_manager=state_manager, gpu_allocator=gpu_allocator
        )

        # Stop VM with GPU release
        success = vm_lifecycle.stop_vm_with_gpu_release(vm_name, force=force)

        if success:
            # Update VM state
            cluster_state.update_vm_state(vm_name, VMState.SHUTOFF)
            state_manager.save_state(cluster_state)
            console.print(f"[green]✅ VM '{vm_name}' stopped successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to stop VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except VMLifecycleError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("start")
def vm_start(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to start")],
    no_wait: Annotated[bool, typer.Option("--no-wait", help="Don't wait for boot")] = False,
) -> None:
    """Start an individual VM with GPU resource allocation."""
    state_path = ctx.obj["state"]

    console.print(f"Starting VM: {vm_name}")

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        cluster_state = state_manager.get_state()

        if not cluster_state:
            console.print("[red]Error:[/red] No cluster state found")
            raise typer.Exit(code=1)

        vm_info = cluster_state.get_vm_by_name(vm_name)
        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager
        libvirt_client = LibvirtClient()
        gpu_allocator = GPUResourceAllocator(state_path.parent / "global-state.json")
        vm_lifecycle = VMLifecycleManager(
            libvirt_client, state_manager=state_manager, gpu_allocator=gpu_allocator
        )

        # Start VM with GPU allocation
        success = vm_lifecycle.start_vm_with_gpu_allocation(vm_name, wait_for_boot=not no_wait)

        if success:
            # Update VM state
            cluster_state.update_vm_state(vm_name, VMState.RUNNING)
            state_manager.save_state(cluster_state)
            console.print(f"[green]✅ VM '{vm_name}' started successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to start VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except VMLifecycleError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("restart")
def vm_restart(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM to restart")],
    no_wait: Annotated[bool, typer.Option("--no-wait", help="Don't wait for boot")] = False,
) -> None:
    """Restart an individual VM with GPU resource management."""
    state_path = ctx.obj["state"]

    console.print(f"Restarting VM: {vm_name}")

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        cluster_state = state_manager.get_state()

        if not cluster_state:
            console.print("[red]Error:[/red] No cluster state found")
            raise typer.Exit(code=1)

        vm_info = cluster_state.get_vm_by_name(vm_name)
        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Initialize lifecycle manager
        libvirt_client = LibvirtClient()
        gpu_allocator = GPUResourceAllocator(state_path.parent / "global-state.json")
        vm_lifecycle = VMLifecycleManager(
            libvirt_client, state_manager=state_manager, gpu_allocator=gpu_allocator
        )

        # Restart VM
        success = vm_lifecycle.restart_vm(vm_name, wait_for_boot=not no_wait)

        if success:
            console.print(f"[green]✅ VM '{vm_name}' restarted successfully[/green]")
        else:
            console.print(f"[red]❌ Failed to restart VM '{vm_name}'[/red]")
            raise typer.Exit(code=1)

    except VMLifecycleError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


@vm_app.command("status")
def vm_status(
    ctx: typer.Context,
    vm_name: Annotated[str, typer.Argument(help="Name of the VM")],
) -> None:
    """Show detailed status of an individual VM."""
    state_path = ctx.obj["state"]

    try:
        # Load state
        state_manager = ClusterStateManager(state_path)
        cluster_state = state_manager.get_state()

        if not cluster_state:
            console.print("[red]Error:[/red] No cluster state found")
            raise typer.Exit(code=1)

        vm_info = cluster_state.get_vm_by_name(vm_name)

        if not vm_info:
            console.print(f"[red]Error:[/red] VM '{vm_name}' not found in state")
            raise typer.Exit(code=1)

        # Get current libvirt state
        libvirt_client = LibvirtClient()
        vm_lifecycle = VMLifecycleManager(libvirt_client)
        current_state = vm_lifecycle.get_vm_state(vm_name)

        # Display status
        table = Table(title=f"VM Status: {vm_name}")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        table.add_row("Name", vm_name)
        table.add_row("UUID", vm_info.domain_uuid)
        table.add_row("Type", vm_info.vm_type)
        table.add_row(
            "State",
            f"[{'green' if current_state == VMState.RUNNING else 'yellow'}]"
            f"{current_state.value}[/]",
        )
        table.add_row("CPU Cores", str(vm_info.cpu_cores))
        table.add_row("Memory (GB)", str(vm_info.memory_gb))
        table.add_row("Volume Path", str(vm_info.volume_path))
        table.add_row("IP Address", vm_info.ip_address or "Not assigned")
        table.add_row("GPU", vm_info.gpu_assigned or "None")

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


plan_app = typer.Typer(help="Planning and inventory utilities")
app.add_typer(plan_app, name="plan")


@plan_app.command("show")
def plan_show(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("plan show")


@plan_app.command("clusters")
def plan_clusters(
    ctx: typer.Context,  # noqa: ARG001
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml configuration file",
        ),
    ] = DEFAULT_CONFIG,
    output_format: Annotated[
        str,
        typer.Option(
            "--format",
            "-f",
            help="Output format: text, json, or markdown",
        ),
    ] = "text",
    output_file: Annotated[
        Path | None,
        typer.Option(
            "--output-file",
            "-o",
            help="Write output to file instead of stdout",
        ),
    ] = None,
) -> None:
    """Show planned clusters and VMs from configuration file.

    This command parses the cluster configuration and displays:
    - All clusters (HPC and Cloud) that will be created
    - All VMs within each cluster with their specifications
    - Network configuration and resource allocation

    Output formats:
    - text: Human-readable formatted output (default)
    - json: Machine-readable JSON output
    - markdown: Markdown table format

    Options:
    - --output-file, -o: Write output to specified file instead of stdout
    """
    # Get logger for this module
    logger = logging.getLogger(__name__)

    # Log info for non-JSON output
    if output_format.lower() != "json":
        logger.info(f"Planning clusters from config: {config}, format: {output_format}")

    try:
        # Load and render configuration
        config_data = load_and_render_config(config)

        # Parse cluster configuration
        planned_data = _parse_cluster_config(config_data)

        # Output based on format and destination
        if output_file:
            # Create parent directories if they don't exist
            output_file.parent.mkdir(parents=True, exist_ok=True)

            with open(output_file, "w", encoding="utf-8") as f:
                if output_format.lower() == "json":
                    _output_json(planned_data, file=f)
                elif output_format.lower() == "markdown":
                    _output_markdown(planned_data, file=f)
                else:  # text format (default)
                    _output_text(planned_data, file=f)

            if output_format.lower() != "json":
                console.print(f"[green]Output written to: {output_file}[/green]")
        else:
            # Output to stdout (original behavior)
            if output_format.lower() == "json":
                _output_json(planned_data)
            elif output_format.lower() == "markdown":
                _output_markdown(planned_data)
            else:  # text format (default)
                _output_text(planned_data)

    except FileNotFoundError:
        if output_format.lower() != "json":
            logger.error(f"Configuration file not found: {config}")
            console.print(f"[red]Error:[/red] Configuration file not found: {config}")
        else:
            # For JSON output, print error to stderr
            print(f'{{"error": "Configuration file not found: {config}"}}', file=sys.stderr)
        raise typer.Exit(code=1) from None
    except yaml.YAMLError as e:
        if output_format.lower() != "json":
            logger.error(f"Invalid YAML in config file: {e}")
            console.print(f"[red]Error:[/red] Invalid YAML in config file: {e}")
        else:
            # For JSON output, print error to stderr
            print(f'{{"error": "Invalid YAML in config file: {e}"}}', file=sys.stderr)
        raise typer.Exit(code=1) from e
    except Exception as e:
        if output_format.lower() != "json":
            logger.error(f"Unexpected error: {e}")
            console.print(f"[red]Unexpected error:[/red] {e}")
        else:
            # For JSON output, print error to stderr
            print(f'{{"error": "Unexpected error: {e}"}}', file=sys.stderr)
        raise typer.Exit(code=1) from e


inventory = typer.Typer(help="Host and device inventory")
app.add_typer(inventory, name="inventory")


@inventory.command("gpu")
def inventory_gpu(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("inventory gpu")


@inventory.command("pcie")
def inventory_pcie(ctx: typer.Context) -> None:  # noqa: ARG001
    """Show detailed PCIe device inventory and driver binding status."""
    console.print("[bold]PCIe Device Inventory[/bold]")

    try:
        validator = PCIePassthroughValidator()
        devices = validator.list_pcie_devices()

        if not devices:
            console.print("[yellow]No PCIe devices found[/yellow]")
            return

        # Create detailed inventory table
        inventory_table = Table(title="PCIe Device Inventory")
        inventory_table.add_column("PCI Address", style="cyan")
        inventory_table.add_column("Class", style="white")
        inventory_table.add_column("Driver", style="white")
        inventory_table.add_column("VFIO", style="white")
        inventory_table.add_column("Conflicting", style="white")
        inventory_table.add_column("IOMMU Group", style="white")

        for device in devices:
            # Color code the driver status
            driver_text: str = str(device["driver"])
            if device["is_vfio"]:
                driver_text = f"[green]{driver_text}[/green]"
            elif device["is_conflicting"]:
                driver_text = f"[red]{driver_text}[/red]"
            elif device["driver"] != "unknown":
                driver_text = f"[yellow]{driver_text}[/yellow]"

            # Color code VFIO status
            vfio_text = "[green]Yes[/green]" if device["is_vfio"] else "[red]No[/red]"

            # Color code conflicting status
            conflicting_text = "[red]Yes[/red]" if device["is_conflicting"] else "[green]No[/green]"

            inventory_table.add_row(
                str(device["pci_address"]),
                str(device.get("device_class", "unknown")),
                driver_text,
                vfio_text,
                conflicting_text,
                str(device["iommu_group"]),
            )

        console.print(inventory_table)

        # Show summary statistics
        total_devices = len(devices)
        vfio_devices = sum(1 for d in devices if d["is_vfio"])
        conflicting_devices = sum(1 for d in devices if d["is_conflicting"])

        console.print("\n[bold]Summary:[/bold]")
        console.print(f"Total PCIe devices: {total_devices}")
        console.print(f"VFIO-bound devices: {vfio_devices}")
        console.print(f"Conflicting drivers: {conflicting_devices}")

        if conflicting_devices > 0:
            console.print(
                f"\n[yellow]⚠️  {conflicting_devices} device(s) have conflicting drivers[/yellow]"
            )
            console.print("These devices need to be bound to VFIO for PCIe passthrough to work.")

    except Exception as e:
        console.print(f"[red]Error getting PCIe inventory:[/red] {e}")
        raise typer.Exit(code=1) from e


def _display_cluster_status(status: dict, cluster_type: str = "HPC") -> None:
    """Display cluster status information in a formatted table.

    Args:
        status: Cluster status dictionary
        cluster_type: Type of cluster ("HPC" or "Cloud") for display title
    """
    if status.get("status") == "not_configured":
        console.print("[yellow]Cluster not configured[/yellow]")
        return

    if status.get("status") == "error":
        console.print(
            f"[red]Error getting cluster status:[/red] {status.get('message', 'Unknown error')}"
        )
        return

    # Create status table with dynamic title
    table = Table(title=f"{cluster_type} Cluster Status")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="white")

    table.add_row("Cluster Name", status.get("cluster_name", "Unknown"))
    table.add_row("Cluster Type", status.get("cluster_type", "Unknown"))
    table.add_row("Total VMs", str(status.get("total_vms", 0)))
    table.add_row("Running VMs", str(status.get("running_vms", 0)))
    table.add_row("Controller Status", status.get("controller_status", "Unknown"))
    table.add_row("Compute Nodes", str(status.get("compute_nodes", 0)))

    if status.get("last_modified"):
        table.add_row("Last Modified", status["last_modified"])

    console.print(table)

    # Show VM details if available
    if "vms" in status and status["vms"]:
        console.print("\n[bold]VM Details:[/bold]")

        vm_table = Table()
        vm_table.add_column("Name", style="cyan")
        vm_table.add_column("State", style="white")
        vm_table.add_column("CPU", style="white")
        vm_table.add_column("Memory (GB)", style="white")
        vm_table.add_column("IP (desired/live)", style="white")
        vm_table.add_column("GPU", style="white")

        for vm in status["vms"]:
            state_color = "green" if vm["state"] == "running" else "yellow"

            # Format GPU information
            gpu_info = vm.get("gpu_assigned")
            gpu_display = f"[green]{gpu_info}[/green]" if gpu_info else "[dim]None[/dim]"
            desired_ip = vm.get("ip_address", "N/A")
            live_ip = get_domain_ip(vm.get("name", ""))
            if live_ip and desired_ip and live_ip != desired_ip:
                ip_display = f"{desired_ip} / [red]{live_ip}[/red]"
            else:
                ip_display = f"{desired_ip} / {live_ip or 'N/A'}"

            vm_table.add_row(
                vm["name"],
                f"[{state_color}]{vm['state']}[/{state_color}]",
                str(vm.get("cpu_cores", "N/A")),
                str(vm.get("memory_gb", "N/A")),
                ip_display,
                gpu_display,
            )

        console.print(vm_table)


def _display_pcie_validation_summary(
    validator: PCIePassthroughValidator, config_data: dict
) -> None:
    """Display a summary of PCIe passthrough validation results."""
    console.print("\n[bold]PCIe Passthrough Validation Summary:[/bold]")

    # Get all PCIe devices from configuration
    pcie_devices = []
    clusters = config_data.get("clusters", {})

    for cluster_name, cluster_config in clusters.items():
        compute_nodes = cluster_config.get("compute_nodes", [])
        for node in compute_nodes:
            pcie_config = node.get("pcie_passthrough", {})
            if pcie_config.get("enabled", False):
                devices = pcie_config.get("devices", [])
                for device in devices:
                    device_info = {
                        "cluster": cluster_name,
                        "node": node.get("name", "unknown"),
                        "pci_address": device.get("pci_address"),
                        "device_type": device.get("device_type"),
                        "vendor_id": device.get("vendor_id", "N/A"),
                        "device_id": device.get("device_id", "N/A"),
                    }
                    pcie_devices.append(device_info)

    if not pcie_devices:
        console.print("[yellow]No PCIe passthrough devices configured[/yellow]")
        return

    # Create summary table
    summary_table = Table(title="Configured PCIe Passthrough Devices")
    summary_table.add_column("Cluster", style="cyan")
    summary_table.add_column("Node", style="cyan")
    summary_table.add_column("PCI Address", style="white")
    summary_table.add_column("Type", style="white")
    summary_table.add_column("Vendor:Device", style="white")
    summary_table.add_column("Status", style="white")

    for device_info in pcie_devices:
        pci_address = device_info["pci_address"]
        status = validator.get_pcie_device_status(pci_address)

        # Determine status color and text
        if not status["exists"]:
            status_text = "[red]Not Found[/red]"
        elif status["is_conflicting"]:
            status_text = "[red]Conflicting Driver[/red]"
        elif status["is_vfio"]:
            status_text = "[green]Ready[/green]"
        else:
            status_text = "[yellow]Wrong Driver[/yellow]"

        vendor_device = f"{device_info['vendor_id']}:{device_info['device_id']}"

        summary_table.add_row(
            device_info["cluster"],
            device_info["node"],
            pci_address,
            device_info["device_type"],
            vendor_device,
            status_text,
        )

    console.print(summary_table)

    # Show system status
    console.print("\n[bold]System PCIe Passthrough Status:[/bold]")

    # Check VFIO modules
    try:
        vfio_loaded = validator._validate_vfio_modules()
        vfio_status = "[green]Loaded[/green]" if vfio_loaded else "[red]Missing[/red]"
    except (FileNotFoundError, PermissionError, OSError):
        vfio_status = "[yellow]Unknown[/yellow]"

    # Check IOMMU
    try:
        iommu_enabled = validator._validate_iommu_configuration()
        iommu_status = "[green]Enabled[/green]" if iommu_enabled else "[red]Disabled[/red]"
    except (FileNotFoundError, PermissionError, OSError):
        iommu_status = "[yellow]Unknown[/yellow]"

    # Check KVM
    kvm_status = (
        "[green]Available[/green]" if Path("/dev/kvm").exists() else "[red]Not Available[/red]"
    )

    system_table = Table()
    system_table.add_column("Component", style="cyan")
    system_table.add_column("Status", style="white")

    system_table.add_row("VFIO Modules", vfio_status)
    system_table.add_row("IOMMU", iommu_status)
    system_table.add_row("KVM", kvm_status)

    console.print(system_table)


def _parse_cluster_config(config_data: dict) -> dict:
    """Parse cluster configuration and extract planned VMs and clusters.

    Args:
        config_data: Loaded YAML configuration data

    Returns:
        Dictionary containing parsed cluster and VM information
    """
    planned_data = {"metadata": config_data.get("metadata", {}), "clusters": {}}

    clusters_config = config_data.get("clusters", {})

    # Parse HPC cluster
    if "hpc" in clusters_config:
        hpc_config = clusters_config["hpc"]
        planned_data["clusters"]["hpc"] = _parse_hpc_cluster(hpc_config)

    # Parse Cloud cluster
    if "cloud" in clusters_config:
        cloud_config = clusters_config["cloud"]
        planned_data["clusters"]["cloud"] = _parse_cloud_cluster(cloud_config)

    return planned_data


def _parse_hpc_cluster(hpc_config: dict) -> dict:
    """Parse HPC cluster configuration.

    Args:
        hpc_config: HPC cluster configuration section

    Returns:
        Dictionary containing HPC cluster information
    """
    cluster_info = {
        "name": hpc_config.get("name", "unknown"),
        "type": "hpc",
        "network": hpc_config.get("network", {}),
        "base_image": hpc_config.get("base_image_path", "unknown"),
        "vms": [],
    }

    # Add controller VM
    controller_config = hpc_config.get("controller", {})
    if controller_config:
        controller_vm = {
            "name": f"{cluster_info['name']}-controller",
            "type": "controller",
            "cpu_cores": controller_config.get("cpu_cores", 0),
            "memory_gb": controller_config.get("memory_gb", 0),
            "disk_gb": controller_config.get("disk_gb", 0),
            "ip_address": controller_config.get("ip_address", "dhcp"),
            "base_image": controller_config.get("base_image_path", cluster_info["base_image"]),
            "gpu_assigned": None,
            "pcie_passthrough": controller_config.get("pcie_passthrough", {}),
        }
        cluster_info["vms"].append(controller_vm)

    # Add compute nodes
    compute_nodes = hpc_config.get("compute_nodes", [])
    for i, node_config in enumerate(compute_nodes):
        compute_vm = {
            "name": f"{cluster_info['name']}-compute-{i + 1:02d}",
            "type": "compute",
            "cpu_cores": node_config.get("cpu_cores", 0),
            "memory_gb": node_config.get("memory_gb", 0),
            "disk_gb": node_config.get("disk_gb", 0),
            "ip_address": node_config.get("ip", "dhcp"),
            "base_image": node_config.get("base_image_path", cluster_info["base_image"]),
            "gpu_assigned": _extract_gpu_info(node_config.get("pcie_passthrough", {})),
            "pcie_passthrough": node_config.get("pcie_passthrough", {}),
        }
        cluster_info["vms"].append(compute_vm)

    return cluster_info


def _parse_cloud_cluster(cloud_config: dict) -> dict:
    """Parse Cloud cluster configuration.

    Args:
        cloud_config: Cloud cluster configuration section

    Returns:
        Dictionary containing Cloud cluster information
    """
    cluster_info = {
        "name": cloud_config.get("name", "unknown"),
        "type": "cloud",
        "network": cloud_config.get("network", {}),
        "base_image": cloud_config.get("base_image_path", "unknown"),
        "vms": [],
    }

    # Add control plane VM
    control_plane_config = cloud_config.get("control_plane", {})
    if control_plane_config:
        control_plane_vm = {
            "name": f"{cluster_info['name']}-control-plane",
            "type": "control_plane",
            "cpu_cores": control_plane_config.get("cpu_cores", 0),
            "memory_gb": control_plane_config.get("memory_gb", 0),
            "disk_gb": control_plane_config.get("disk_gb", 0),
            "ip_address": control_plane_config.get("ip_address", "dhcp"),
            "base_image": control_plane_config.get("base_image_path", cluster_info["base_image"]),
            "gpu_assigned": None,
            "pcie_passthrough": control_plane_config.get("pcie_passthrough", {}),
        }
        cluster_info["vms"].append(control_plane_vm)

    # Add worker nodes
    worker_nodes = cloud_config.get("worker_nodes", {})
    for worker_type, nodes in worker_nodes.items():
        for i, node_config in enumerate(nodes):
            worker_vm = {
                "name": f"{cluster_info['name']}-{worker_type}-{i + 1:02d}",
                "type": f"worker_{worker_type}",
                "cpu_cores": node_config.get("cpu_cores", 0),
                "memory_gb": node_config.get("memory_gb", 0),
                "disk_gb": node_config.get("disk_gb", 0),
                "ip_address": node_config.get("ip", "dhcp"),
                "base_image": node_config.get("base_image_path", cluster_info["base_image"]),
                "gpu_assigned": _extract_gpu_info(node_config.get("pcie_passthrough", {})),
                "pcie_passthrough": node_config.get("pcie_passthrough", {}),
            }
            cluster_info["vms"].append(worker_vm)

    return cluster_info


def _extract_gpu_info(pcie_config: dict) -> str | None:
    """Extract GPU information from PCIe passthrough configuration.

    Args:
        pcie_config: PCIe passthrough configuration

    Returns:
        GPU device information string or None
    """
    if not pcie_config.get("enabled", False):
        return None

    devices = pcie_config.get("devices", [])
    gpu_devices = [d for d in devices if d.get("device_type") == "gpu"]

    if not gpu_devices:
        return None

    # Return the first GPU device info
    gpu = gpu_devices[0]
    pci_addr = gpu.get("pci_address", "unknown")
    vendor_id = gpu.get("vendor_id", "unknown")
    device_id = gpu.get("device_id", "unknown")
    return f"{pci_addr} ({vendor_id}:{device_id})"


def _has_gpu_conflict(
    pcie_config: dict, shared_gpus: dict[str, list[str]]
) -> tuple[bool, str | None]:
    """Check if a VM has a GPU conflict with other clusters.

    Args:
        pcie_config: PCIe passthrough configuration
        shared_gpus: Dictionary of shared GPU addresses and their clusters

    Returns:
        Tuple of (has_conflict, conflict_info)
    """
    if not pcie_config.get("enabled", False):
        return False, None

    devices = pcie_config.get("devices", [])
    gpu_devices = [d for d in devices if d.get("device_type") == "gpu"]

    for gpu in gpu_devices:
        pci_addr = gpu.get("pci_address")
        if pci_addr in shared_gpus:
            conflicting_clusters = shared_gpus[pci_addr]
            return True, f"SHARED with {', '.join(conflicting_clusters)}"

    return False, None


def _output_text(planned_data: dict, file=None) -> None:
    """Output planned data in human-readable text format.

    Args:
        planned_data: Parsed cluster configuration data
        file: File object to write to, defaults to stdout via Rich console
    """
    if file is not None:
        # For file output, create a simple text version without Rich formatting
        def write_line(text=""):
            file.write(text + "\n")

        write_line("\nCluster Planning Report")
        write_line(f"Configuration: {planned_data['metadata'].get('name', 'Unknown')}")
        write_line(f"Description: {planned_data['metadata'].get('description', 'No description')}")

        total_clusters = len(planned_data["clusters"])
        total_vms = sum(len(cluster["vms"]) for cluster in planned_data["clusters"].values())

        write_line(f"\nSummary: {total_clusters} cluster(s), {total_vms} VM(s)")

        for cluster_name, cluster_info in planned_data["clusters"].items():
            write_line(f"\nCluster: {cluster_info['name']} ({cluster_name.upper()})")
            write_line(f"  Type: {cluster_info['type'].upper()}")
            subnet = cluster_info["network"].get("subnet", "unknown")
            bridge = cluster_info["network"].get("bridge", "unknown")
            write_line(f"  Network: {subnet} ({bridge})")
            write_line(f"  Base Image: {cluster_info['base_image']}")
            write_line(f"  VMs: {len(cluster_info['vms'])}")

            # Create simple table header
            write_line(f"\n{cluster_info['name']} VMs:")
            write_line(
                "Name                | Type      | CPU | Memory (GB) | Disk (GB) | IP Address    | "
                "GPU"
            )
            write_line(
                "--------------------|-----------|-----|-------------|-----------|---------------|-----"
            )

            for vm in cluster_info["vms"]:
                gpu_display = vm["gpu_assigned"] if vm["gpu_assigned"] else "None"
                write_line(
                    f"{vm['name']:<19} | {vm['type']:<9} | {vm['cpu_cores']:<3} | "
                    f"{vm['memory_gb']:<11} | {vm['disk_gb']:<9} | {vm['ip_address']:<13} | "
                    f"{gpu_display}"
                )
    else:
        # Original Rich console output for stdout
        console.print("\n[bold blue]Cluster Planning Report[/bold blue]")
        console.print(f"Configuration: {planned_data['metadata'].get('name', 'Unknown')}")
        console.print(
            f"Description: {planned_data['metadata'].get('description', 'No description')}"
        )

        total_clusters = len(planned_data["clusters"])
        total_vms = sum(len(cluster["vms"]) for cluster in planned_data["clusters"].values())

        console.print(f"\n[bold]Summary:[/bold] {total_clusters} cluster(s), {total_vms} VM(s)")

        for cluster_name, cluster_info in planned_data["clusters"].items():
            console.print(
                f"\n[bold cyan]Cluster: {cluster_info['name']} ({cluster_name.upper()})[/bold cyan]"
            )
            console.print(f"  Type: {cluster_info['type'].upper()}")
            subnet = cluster_info["network"].get("subnet", "unknown")
            bridge = cluster_info["network"].get("bridge", "unknown")
            console.print(f"  Network: {subnet} ({bridge})")
            console.print(f"  Base Image: {cluster_info['base_image']}")
            console.print(f"  VMs: {len(cluster_info['vms'])}")

            # Create VM table
            vm_table = Table(title=f"{cluster_info['name']} VMs")
            vm_table.add_column("Name", style="cyan")
            vm_table.add_column("Type", style="white")
            vm_table.add_column("CPU", style="white")
            vm_table.add_column("Memory (GB)", style="white")
            vm_table.add_column("Disk (GB)", style="white")
            vm_table.add_column("IP Address", style="white")
            vm_table.add_column("GPU", style="white")

            for vm in cluster_info["vms"]:
                gpu_display = (
                    f"[green]{vm['gpu_assigned']}[/green]"
                    if vm["gpu_assigned"]
                    else "[dim]None[/dim]"
                )
                vm_table.add_row(
                    vm["name"],
                    vm["type"],
                    str(vm["cpu_cores"]),
                    str(vm["memory_gb"]),
                    str(vm["disk_gb"]),
                    vm["ip_address"],
                    gpu_display,
                )

            console.print(vm_table)


def _output_json(planned_data: dict, file=None) -> None:
    """Output planned data in JSON format.

    Args:
        planned_data: Parsed cluster configuration data
        file: File object to write to, defaults to stdout
    """
    if file is None:
        print(json.dumps(planned_data, indent=2))
    else:
        json.dump(planned_data, file, indent=2)


def _output_markdown(planned_data: dict, file=None) -> None:
    """Output planned data in markdown table format.

    Args:
        planned_data: Parsed cluster configuration data
        file: File object to write to, defaults to stdout
    """

    def write_line(text=""):
        if file is None:
            print(text)
        else:
            file.write(text + "\n")

    write_line("# Cluster Planning Report")
    write_line(f"**Configuration:** {planned_data['metadata'].get('name', 'Unknown')}")
    write_line(f"**Description:** {planned_data['metadata'].get('description', 'No description')}")

    total_clusters = len(planned_data["clusters"])
    total_vms = sum(len(cluster["vms"]) for cluster in planned_data["clusters"].values())
    write_line(f"\n**Summary:** {total_clusters} cluster(s), {total_vms} VM(s)\n")

    for cluster_name, cluster_info in planned_data["clusters"].items():
        write_line(f"## {cluster_info['name']} ({cluster_name.upper()})")
        write_line(f"- **Type:** {cluster_info['type'].upper()}")
        subnet = cluster_info["network"].get("subnet", "unknown")
        bridge = cluster_info["network"].get("bridge", "unknown")
        write_line(f"- **Network:** {subnet} ({bridge})")
        write_line(f"- **Base Image:** {cluster_info['base_image']}")
        write_line(f"- **VMs:** {len(cluster_info['vms'])}")
        write_line()

        # Create markdown table
        write_line("| Name | Type | CPU | Memory (GB) | Disk (GB) | IP Address | GPU |")
        write_line("|------|------|-----|-------------|-----------|------------|-----|")

        for vm in cluster_info["vms"]:
            gpu_display = vm["gpu_assigned"] if vm["gpu_assigned"] else "None"
            write_line(
                f"| {vm['name']} | {vm['type']} | {vm['cpu_cores']} | "
                f"{vm['memory_gb']} | {vm['disk_gb']} | {vm['ip_address']} | "
                f"{gpu_display} |"
            )

        write_line()


system = typer.Typer(help="Unified system management (HPC + Cloud clusters)")
app.add_typer(system, name="system")


@system.command("start")
def system_start(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to unified cluster configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Start the complete ML system (both HPC and Cloud clusters).

    This command will start both clusters in the proper order:
    1. HPC cluster starts first (training infrastructure)
    2. Cloud cluster starts second (inference infrastructure)

    The configuration file should contain both HPC and Cloud cluster
    definitions under the 'clusters' section. Both clusters are validated
    to be running before the command completes.
    """
    state_path = ctx.obj["state"]

    console.print("[cyan]Starting complete ML system...[/cyan]")
    console.print(f"Configuration: {config}")

    try:
        # Validate configuration against schema
        console.print("🔍 [cyan]Validating configuration...[/cyan]")
        if not validate_config_against_schema(config):
            console.print(
                "[red]❌ Configuration validation failed. Please fix the errors above.[/red]"
            )
            raise typer.Exit(code=1)

        # Load and render unified configuration
        config_data = load_and_render_config(config)

        # Extract HPC and Cloud cluster configurations
        clusters = config_data.get("clusters", {})
        hpc_data = clusters.get("hpc")
        cloud_data = clusters.get("cloud")

        if not hpc_data:
            console.print("[red]Error:[/red] No HPC cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add an 'hpc' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        if not cloud_data:
            console.print("[red]Error:[/red] No Cloud cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add a 'cloud' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        # Initialize state manager
        state_manager = ClusterStateManager(state_path)

        # Initialize system manager
        system_manager = SystemClusterManager(state_manager)

        # Start all clusters
        success = system_manager.start_all_clusters(hpc_data, cloud_data)

        if success:
            console.print("[green]✅ Complete ML system started successfully[/green]")
            # Display system status
            status = system_manager.get_system_status(hpc_data, cloud_data)
            _display_system_status(status)
        else:
            console.print("[red]❌ Failed to start complete ML system[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] Configuration file not found: {e}")
        raise typer.Exit(code=1) from None
    except SystemManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except KeyError as e:
        console.print(f"[red]Error:[/red] Missing required configuration section: {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@system.command("status")
def system_status(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to unified cluster configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Show status of the complete ML system.

    Displays combined status information including:
    - Overall system status (running, stopped, mixed, or error)
    - HPC cluster status and VM details
    - Cloud cluster status and VM details
    - Shared resource allocation (GPU usage)

    The configuration file should contain both HPC and Cloud cluster
    definitions under the 'clusters' section.
    """
    state_path = ctx.obj["state"]

    try:
        # Load and render unified configuration
        config_data = load_and_render_config(config)

        # Extract HPC and Cloud cluster configurations
        clusters = config_data.get("clusters", {})
        hpc_data = clusters.get("hpc")
        cloud_data = clusters.get("cloud")

        if not hpc_data:
            console.print("[red]Error:[/red] No HPC cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add an 'hpc' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        if not cloud_data:
            console.print("[red]Error:[/red] No Cloud cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add a 'cloud' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        # Initialize state manager
        state_manager = ClusterStateManager(state_path)

        # Initialize system manager
        system_manager = SystemClusterManager(state_manager)

        # Get system status
        status = system_manager.get_system_status(hpc_data, cloud_data)

        # Display status
        _display_system_status(status)

    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] Configuration file not found: {e}")
        raise typer.Exit(code=1) from None
    except SystemManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except KeyError as e:
        console.print(f"[red]Error:[/red] Missing required configuration section: {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@system.command("stop")
def system_stop(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to unified cluster configuration file",
        ),
    ] = DEFAULT_CONFIG,
) -> None:
    """Stop the complete ML system (both HPC and Cloud clusters).

    This command will stop both clusters gracefully in the proper order:
    1. Cloud cluster stops first (inference can safely stop)
    2. HPC cluster stops second (training infrastructure)
    """
    state_path = ctx.obj["state"]

    console.print("[cyan]Stopping complete ML system...[/cyan]")

    try:
        # Load and render unified configuration
        config_data = load_and_render_config(config)

        # Extract HPC and Cloud cluster configurations
        clusters = config_data.get("clusters", {})
        hpc_data = clusters.get("hpc")
        cloud_data = clusters.get("cloud")

        if not hpc_data:
            console.print("[red]Error:[/red] No HPC cluster configuration found in config file")
            raise typer.Exit(code=1)

        if not cloud_data:
            console.print("[red]Error:[/red] No Cloud cluster configuration found in config file")
            raise typer.Exit(code=1)

        # Initialize state manager
        state_manager = ClusterStateManager(state_path)

        # Initialize system manager
        system_manager = SystemClusterManager(state_manager)

        # Stop all clusters
        success = system_manager.stop_all_clusters(hpc_data, cloud_data)

        if success:
            console.print("[green]✅ Complete ML system stopped successfully[/green]")
        else:
            console.print("[red]❌ Failed to stop complete ML system[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] Configuration file not found: {e}")
        raise typer.Exit(code=1) from None
    except SystemManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except KeyError as e:
        console.print(f"[red]Error:[/red] Missing required configuration section: {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@system.command("destroy")
def system_destroy(
    ctx: typer.Context,
    config: Annotated[
        Path,
        typer.Argument(
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to unified cluster configuration file",
        ),
    ] = DEFAULT_CONFIG,
    force: Annotated[bool, typer.Option("--force", help="Skip confirmation prompt")] = False,
) -> None:
    """Destroy the complete ML system (both HPC and Cloud clusters).

    This command will permanently destroy both clusters and all their data.
    A confirmation prompt is shown unless --force is used.

    The destruction order is:
    1. Graceful stop of both clusters
    2. Cloud cluster destruction (inference infrastructure)
    3. HPC cluster destruction (training infrastructure)

    The configuration file should contain both HPC and Cloud cluster
    definitions under the 'clusters' section.
    """
    state_path = ctx.obj["state"]

    console.print("[cyan]Destroying complete ML system...[/cyan]")
    console.print(f"Configuration: {config}")

    try:
        # Load and render unified configuration
        config_data = load_and_render_config(config)

        # Extract HPC and Cloud cluster configurations
        clusters = config_data.get("clusters", {})
        hpc_data = clusters.get("hpc")
        cloud_data = clusters.get("cloud")

        if not hpc_data:
            console.print("[red]Error:[/red] No HPC cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add an 'hpc' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        if not cloud_data:
            console.print("[red]Error:[/red] No Cloud cluster configuration found in config file")
            console.print(
                "[yellow]Tip:[/yellow] Add a 'cloud' section under 'clusters' in your config"
            )
            raise typer.Exit(code=1)

        # Initialize state manager
        state_manager = ClusterStateManager(state_path)

        # Initialize system manager
        system_manager = SystemClusterManager(state_manager)

        # Show confirmation unless force is used
        if not force:
            console.print("\n[red]⚠️  WARNING: This will permanently destroy both clusters![/red]")
            console.print("[yellow]This action cannot be undone.[/yellow]")
            confirm = typer.confirm("Are you sure you want to destroy the complete ML system?")
            if not confirm:
                console.print("[yellow]Operation cancelled.[/yellow]")
                raise typer.Exit(code=0)

        # Destroy all clusters
        success = system_manager.destroy_all_clusters(hpc_data, cloud_data)

        if success:
            console.print("[green]✅ Complete ML system destroyed successfully[/green]")
        else:
            console.print("[red]❌ Failed to destroy complete ML system[/red]")
            raise typer.Exit(code=1)

    except FileNotFoundError as e:
        console.print(f"[red]Error:[/red] Configuration file not found: {e}")
        raise typer.Exit(code=1) from None
    except SystemManagerError as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e
    except KeyError as e:
        console.print(f"[red]Error:[/red] Missing required configuration section: {e}")
        raise typer.Exit(code=1) from e
    except Exception as e:
        console.print(f"[red]Unexpected error:[/red] {e}")
        raise typer.Exit(code=1) from e


@app.command()
def topology(
    ctx: typer.Context,
    config: Annotated[
        Path | None,
        typer.Option(
            "--config",
            "-c",
            exists=True,
            dir_okay=False,
            readable=True,
            help="Path to cluster configuration file or template (optional)",
        ),
    ] = None,
) -> None:
    """Show infrastructure topology from configuration or cluster state.

    If a configuration file is provided, renders it and displays the planned
    infrastructure topology. Otherwise, displays the current cluster state topology.

    Examples:
        # Show topology from cluster state
        ai-how topology

        # Show topology from configuration file
        ai-how topology --config config/cluster.yaml

        # Show topology from template (with variable expansion)
        ai-how topology -c config/cluster.template.yaml

    Displays:
        - HPC and Cloud clusters with their hierarchy
        - Networks and IP address ranges
        - VMs by role (controller, compute nodes, control plane, workers)
        - Resource allocation (CPU, memory, disk)
        - GPU assignments and passthrough devices
    """
    try:
        if config is not None:
            # Render configuration and display planned topology
            console.print(f"📋 [cyan]Loading configuration:[/cyan] {config}")

            try:
                # Load and render configuration
                config_data = load_and_render_config(config)

                # Display rendered topology
                _display_config_topology(config_data)

            except FileNotFoundError as e:
                console.print(f"[red]Error:[/red] Configuration file not found: {e}")
                raise typer.Exit(code=1) from None
            except yaml.YAMLError as e:
                console.print(f"[red]Error:[/red] Invalid YAML in config file: {e}")
                raise typer.Exit(code=1) from e
        else:
            # Display topology from current cluster state
            state_path = Path(ctx.obj["state"])
            state_manager = ClusterStateManager(state_path)
            cluster_state = state_manager.get_state()

            if not cluster_state:
                console.print("[yellow]No cluster state found[/yellow]")
                console.print(
                    "[cyan]Tip:[/cyan] Use "
                    "[bold]ai-how topology --config config/cluster.yaml[/bold] "
                    "to show planned topology"
                )
                return

            _display_topology()

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(code=1) from e


def _display_system_status(status: dict[str, Any]) -> None:
    """Display complete system status in a formatted view.

    Args:
        status: Dictionary containing system status information
    """
    if "error" in status:
        console.print(f"[red]Error:[/red] {status.get('error', 'Unknown error')}")
        return

    # Display overall system status
    system_status = status.get("system_status", "unknown")
    status_color = {
        "running": "green",
        "stopped": "yellow",
        "mixed": "yellow",
        "error": "red",
    }.get(system_status, "white")

    console.print(
        f"\n[bold]ML System Status:[/bold] [{status_color}]{system_status.upper()}[/{status_color}]"
    )

    # Display HPC cluster status
    if "hpc_cluster" in status:
        console.print("\n[bold cyan]HPC Cluster:[/bold cyan]")
        hpc = status["hpc_cluster"]
        _display_cluster_status(hpc, cluster_type="HPC")

    # Display Cloud cluster status
    if "cloud_cluster" in status:
        console.print("\n[bold cyan]Cloud Cluster:[/bold cyan]")
        cloud = status["cloud_cluster"]
        _display_cluster_status(cloud, cluster_type="Cloud")

    # Display shared resources
    if "shared_resources" in status and status["shared_resources"]:
        console.print("\n[bold]Shared Resources (GPUs):[/bold]")
        resources = status["shared_resources"]
        if resources.get("gpu_allocations"):
            gpu_table = Table()
            gpu_table.add_column("GPU Address", style="cyan")
            gpu_table.add_column("Allocated To", style="white")

            for gpu_addr, owner in resources["gpu_allocations"].items():
                gpu_table.add_row(gpu_addr, owner)

            console.print(gpu_table)
        else:
            console.print("[yellow]No GPU allocations[/yellow]")

    if status.get("timestamp"):
        console.print(f"\n[dim]Last updated: {status['timestamp']}[/dim]")


def _display_topology() -> None:
    console.print("\n[bold blue]Infrastructure Topology[/bold blue]\n")

    # Build and display tree structure
    # This is a simplified version that would expand with actual topology data
    console.print("[cyan]├── HPC Cluster[/cyan]")
    console.print("[cyan]│   ├── Network: 192.168.100.0/24[/cyan]")
    console.print("[cyan]│   ├── Controller[/cyan]")
    console.print("[cyan]│   └── Compute Nodes[/cyan]")
    console.print("[cyan]│[/cyan]")
    console.print("[cyan]└── Cloud Cluster[/cyan]")
    console.print("[cyan]    ├── Network: 192.168.200.0/24[/cyan]")
    console.print("[cyan]    ├── Control Plane[/cyan]")
    console.print("[cyan]    └── Worker Nodes[/cyan]")

    console.print("\n[bold]Legend:[/bold]")
    console.print("[green]●[/green] Running")
    console.print("[yellow]●[/yellow] Stopped")
    console.print("[red]●[/red] Error/Conflict")


def _display_config_topology(config_data: dict) -> None:
    """Display infrastructure topology from rendered configuration file.

    Args:
        config_data: Rendered configuration dictionary
    """
    console.print("\n[bold blue]Planned Infrastructure Topology[/bold blue]\n")

    clusters = config_data.get("clusters", {})

    # Detect GPU conflicts before displaying topology
    from ai_how.resource_management.shared_gpu_validator import SharedGPUValidator

    validator = SharedGPUValidator()
    shared_gpus = validator.detect_shared_gpus(config_data)

    # Display HPC cluster if present
    if "hpc" in clusters:
        hpc = clusters["hpc"]
        console.print("[cyan]├── [bold]HPC Cluster[/bold] (Training Infrastructure)[/cyan]")
        console.print(
            f"[cyan]│   ├── Network: {hpc.get('network', {}).get('subnet', 'N/A')}"
            f" ({hpc.get('network', {}).get('bridge', 'N/A')})[/cyan]"
        )

        # Controller
        if "controller" in hpc:
            controller = hpc["controller"]
            console.print("[cyan]│   ├── [green]●[/green] Controller[/cyan]")
            console.print(f"[cyan]│   │   ├── CPU: {controller.get('cpu_cores', 0)} cores[/cyan]")
            console.print(f"[cyan]│   │   ├── Memory: {controller.get('memory_gb', 0)} GB[/cyan]")
            console.print(f"[cyan]│   │   └── Disk: {controller.get('disk_gb', 0)} GB[/cyan]")

        # Compute nodes
        compute_nodes = hpc.get("compute_nodes", [])
        if compute_nodes:
            console.print(f"[cyan]│   └── Compute Nodes ({len(compute_nodes)} total)[/cyan]")
            for i, node in enumerate(compute_nodes):
                is_last = i == len(compute_nodes) - 1
                prefix = "[cyan]│       └──[/cyan]" if is_last else "[cyan]│       ├──[/cyan]"

                # Check for GPU conflicts
                has_conflict, conflict_info = _has_gpu_conflict(
                    node.get("pcie_passthrough", {}), shared_gpus
                )
                vm_indicator = "[red]⚠️[/red]" if has_conflict else "[green]●[/green]"

                console.print(f"{prefix} {vm_indicator} compute-{i + 1:02d}")
                console.print(f"[cyan]│           ├── CPU: {node.get('cpu_cores', 0)} cores[/cyan]")
                console.print(f"[cyan]│           ├── Memory: {node.get('memory_gb', 0)} GB[/cyan]")

                # GPU info with conflict highlighting
                gpu_info = _extract_gpu_info(node.get("pcie_passthrough", {}))
                if gpu_info:
                    if has_conflict:
                        console.print(
                            f"[cyan]│           └── GPU: [red]{gpu_info}[/red] "
                            f"[yellow]⚠️ GPU CONFLICT[/yellow][/cyan]"
                        )
                        console.print(
                            f"[cyan]│               └── [yellow]{conflict_info}[/yellow][/cyan]"
                        )
                    else:
                        console.print(
                            f"[cyan]│           └── GPU: [green]{gpu_info}[/green][/cyan]"
                        )

        if "cloud" in clusters:
            console.print("[cyan]│[/cyan]")

    # Display Cloud cluster if present
    if "cloud" in clusters:
        cloud = clusters["cloud"]
        console.print("[cyan]└── [bold]Cloud Cluster[/bold] (Inference Infrastructure)[/cyan]")
        console.print(
            f"[cyan]    ├── Network: {cloud.get('network', {}).get('subnet', 'N/A')}"
            f" ({cloud.get('network', {}).get('bridge', 'N/A')})[/cyan]"
        )

        # Control plane
        if "control_plane" in cloud:
            control_plane = cloud["control_plane"]
            console.print("[cyan]    ├── [green]●[/green] Control Plane[/cyan]")
            console.print(
                f"[cyan]    │   ├── CPU: {control_plane.get('cpu_cores', 0)} cores[/cyan]"
            )
            console.print(
                f"[cyan]    │   ├── Memory: {control_plane.get('memory_gb', 0)} GB[/cyan]"
            )
            console.print(f"[cyan]    │   └── Disk: {control_plane.get('disk_gb', 0)} GB[/cyan]")

        # Worker nodes
        worker_nodes = cloud.get("worker_nodes", {})
        if worker_nodes:
            total_workers = sum(len(nodes) for nodes in worker_nodes.values())
            console.print(f"[cyan]    └── Worker Nodes ({total_workers} total)[/cyan]")

            for worker_type, nodes in worker_nodes.items():
                for i, node in enumerate(nodes):
                    is_last_type = worker_type == list(worker_nodes.keys())[-1]
                    is_last_node = i == len(nodes) - 1

                    if is_last_type and is_last_node:
                        prefix = "[cyan]        └──[/cyan]"
                    else:
                        prefix = "[cyan]        ├──[/cyan]"

                    # Check for GPU conflicts
                    has_conflict, conflict_info = _has_gpu_conflict(
                        node.get("pcie_passthrough", {}), shared_gpus
                    )
                    vm_indicator = "[red]⚠️[/red]" if has_conflict else "[green]●[/green]"

                    console.print(f"{prefix} {vm_indicator} {worker_type}-{i + 1:02d}")

                    if is_last_type and is_last_node:
                        indent = "[cyan]            [/cyan]"
                    else:
                        indent = "[cyan]        │   [/cyan]"

                    console.print(f"{indent}├── CPU: {node.get('cpu_cores', 0)} cores")
                    console.print(f"{indent}├── Memory: {node.get('memory_gb', 0)} GB")

                    # GPU info with conflict highlighting
                    gpu_info = _extract_gpu_info(node.get("pcie_passthrough", {}))
                    if gpu_info:
                        if has_conflict:
                            console.print(
                                f"{indent}└── GPU: [red]{gpu_info}[/red] "
                                f"[yellow]⚠️ GPU CONFLICT[/yellow]"
                            )
                            console.print(f"{indent}    └── [yellow]{conflict_info}[/yellow]")
                        else:
                            console.print(f"{indent}└── GPU: [green]{gpu_info}[/green]")

    # Summary statistics
    console.print("\n[bold]Summary:[/bold]")
    total_hpc_vms = 1  # controller
    total_hpc_vms += len(clusters.get("hpc", {}).get("compute_nodes", []))
    total_cloud_vms = 1  # control plane
    total_cloud_vms += sum(
        len(nodes) for nodes in clusters.get("cloud", {}).get("worker_nodes", {}).values()
    )

    console.print(f"  HPC Cluster: {total_hpc_vms} VMs")
    console.print(f"  Cloud Cluster: {total_cloud_vms} VMs")
    console.print(f"  Total: {total_hpc_vms + total_cloud_vms} VMs")

    console.print("\n[bold]Legend:[/bold]")
    console.print("[green]●[/green] VM (configured)")
    console.print("[red]⚠️[/red] VM with GPU conflict")


if __name__ == "__main__":
    try:
        app()
    except typer.Exit as exit_exc:
        sys.exit(exit_exc.exit_code)
