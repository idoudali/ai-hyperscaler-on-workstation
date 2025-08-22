from __future__ import annotations

import importlib.resources
import logging
import sys
from pathlib import Path
from typing import Annotated, Union

import typer
import yaml
from rich.console import Console
from rich.table import Table

from ai_how.utils.logging import configure_logging
from ai_how.validation import validate_config
from ai_how.vm_management.hpc_manager import HPCClusterManager, HPCManagerError

app = typer.Typer(help="AI-HOW CLI for managing HPC and Cloud clusters")
console = Console()


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

    configure_logging(
        level=actual_log_level,
        log_file=actual_log_file,
        console_output=True,
        include_timestamps=(actual_log_level == "DEBUG"),
    )

    # Get logger for this module
    logger = logging.getLogger(__name__)
    logger.debug(f"CLI initialized with state={state}, log_level={actual_log_level}")

    ctx.obj = {
        "state": state,
        "log_level": actual_log_level,
        "log_file": actual_log_file,
    }


@app.command()
def validate(ctx: typer.Context) -> None:  # noqa: ARG001
    """Validate cluster.yaml against schema and semantic rules."""
    console.print(f"Validating {DEFAULT_CONFIG}...")

    try:
        schema_resource = importlib.resources.files("ai_how.schemas").joinpath(
            CLUSTER_SCHEMA_FILENAME
        )
        with importlib.resources.as_file(schema_resource) as schema_path:
            if not validate_config(DEFAULT_CONFIG, schema_path):
                raise typer.Exit(code=1)
    except (FileNotFoundError, ModuleNotFoundError) as e:
        console.print(f"[red]Error:[/red] Could not locate schema file: {e}")
        raise typer.Exit(code=1)  # noqa: B904


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
        # Load and validate configuration
        logger.debug(f"Loading configuration from: {config}")
        with open(config, encoding="utf-8") as f:
            config_data = yaml.safe_load(f)
        logger.debug("Configuration loaded successfully")

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
        # Load configuration
        with open(config, encoding="utf-8") as f:
            config_data = yaml.safe_load(f)

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
        # Load configuration
        with open(config, encoding="utf-8") as f:
            config_data = yaml.safe_load(f)

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
        # Load configuration
        with open(config, encoding="utf-8") as f:
            config_data = yaml.safe_load(f)

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


inventory = typer.Typer(help="Host and device inventory")
app.add_typer(inventory, name="inventory")


@inventory.command("gpu")
def inventory_gpu(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("inventory gpu")


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
            vm_table.add_row(
                vm["name"],
                f"[{state_color}]{vm['state']}[/{state_color}]",
                str(vm.get("cpu_cores", "N/A")),
                str(vm.get("memory_gb", "N/A")),
                vm.get("ip_address", "N/A"),
                f"{vm.get('gpu_assigned', 'None')}",
            )

        console.print(vm_table)


if __name__ == "__main__":
    try:
        app()
    except typer.Exit as exit_exc:
        sys.exit(exit_exc.exit_code)
