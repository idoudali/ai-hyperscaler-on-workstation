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
from ai_how.utils.logging import configure_logging
from ai_how.validation import validate_config
from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError

app = typer.Typer(help="AI-HOW CLI for managing HPC and Cloud clusters")
console = Console()


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
            if not validate_config(config, schema_path):
                raise typer.Exit(code=1)

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
            help="Output path for rendered configuration (default: template_name.yaml)",
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
    variables and saves the rendered configuration with all variables expanded.

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
        # Render template to default output location
        ai-how render config/cluster.template.yaml

        # Render template to specific output location
        ai-how render config/cluster.template.yaml -o config/cluster.yaml

        # Show which variables were expanded
        ai-how render config/cluster.template.yaml --show-variables

        # Validate template without rendering (useful for CI/CD)
        ai-how render config/cluster.template.yaml --validate-only
    """
    try:
        console.print(f"🔧 [cyan]Processing template:[/cyan] {template}")

        # Initialize processor
        processor = ConfigProcessor(template, output)

        if validate_only:
            # Only validate the template
            console.print("🔍 [cyan]Validating template (no rendering)...[/cyan]")
            validation_result = processor.validate_template()

            console.print("[green]✅ Template validation successful![/green]")
            console.print(f"📁 Template: {validation_result['template_path']}")
            console.print(
                f"🔢 Variables found: {validation_result['total_variables']} total, "
                f"{validation_result['unique_variables']} unique"
            )

            if show_variables and validation_result["variables_found"]:
                console.print("\n🔍 [cyan]Variables detected:[/cyan]")
                for var_name, count in validation_result["variables_found"].items():
                    console.print(f"  - ${var_name}: {count} occurrence{'s' if count > 1 else ''}")

            return

        # Process the configuration
        config_data = processor.process_config()

        # Show success message
        console.print("[green]✅ Template rendered successfully![/green]")
        console.print(f"📁 Input template: {template}")
        console.print(f"📁 Output config: {processor.output_path}")

        # Show variables if requested
        if show_variables:
            variables_found = processor.get_variables_found(config_data)
            if variables_found:
                console.print("\n🔍 [cyan]Variables expanded:[/cyan]")
                for var_name, count in variables_found.items():
                    console.print(f"  - ${var_name}: {count} occurrence{'s' if count > 1 else ''}")
            else:
                console.print("\nℹ️  [yellow]No variables found in template[/yellow]")

        # Show file size info
        input_size = template.stat().st_size
        output_size = processor.output_path.stat().st_size
        console.print("\n📊 [cyan]File info:[/cyan]")
        console.print(f"  - Template size: {input_size:,} bytes")
        console.print(f"  - Rendered size: {output_size:,} bytes")

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


@cloud.command()
def cloud_start(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("cloud start")


@cloud.command()
def cloud_stop(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("cloud stop")


@cloud.command()
def cloud_status(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("cloud status")


@cloud.command()
def cloud_destroy(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("cloud destroy")


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


def _display_cluster_status(status: dict) -> None:
    """Display cluster status information in a formatted table."""
    if status.get("status") == "not_configured":
        console.print("[yellow]Cluster not configured[/yellow]")
        return

    if status.get("status") == "error":
        console.print(
            f"[red]Error getting cluster status:[/red] {status.get('message', 'Unknown error')}"
        )
        return

    # Create status table
    table = Table(title="HPC Cluster Status")
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
        vm_table.add_column("IP Address", style="white")
        vm_table.add_column("GPU", style="white")

        for vm in status["vms"]:
            state_color = "green" if vm["state"] == "running" else "yellow"

            # Format GPU information
            gpu_info = vm.get("gpu_assigned")
            gpu_display = f"[green]{gpu_info}[/green]" if gpu_info else "[dim]None[/dim]"

            vm_table.add_row(
                vm["name"],
                f"[{state_color}]{vm['state']}[/{state_color}]",
                str(vm.get("cpu_cores", "N/A")),
                str(vm.get("memory_gb", "N/A")),
                vm.get("ip_address", "N/A"),
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


if __name__ == "__main__":
    try:
        app()
    except typer.Exit as exit_exc:
        sys.exit(exit_exc.exit_code)
