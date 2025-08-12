from __future__ import annotations

import importlib.resources
import sys
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console

from ai_how.validation import validate_config

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
    config: Annotated[
        Path,
        typer.Option(
            exists=False,
            dir_okay=False,
            readable=True,
            help="Path to cluster.yaml",
        ),
    ] = DEFAULT_CONFIG,
    state: Annotated[
        Path,
        typer.Option(exists=False, dir_okay=False, help="Path to CLI state file"),
    ] = DEFAULT_STATE,
) -> None:
    ctx.obj = {"config": config, "state": state}


@app.command()
def validate(ctx: typer.Context) -> None:  # noqa: ARG001
    """Validate cluster.yaml against schema and semantic rules."""
    console.print(f"Validating {ctx.obj['config']}...")

    try:
        schema_resource = importlib.resources.files("ai_how.schemas").joinpath(
            CLUSTER_SCHEMA_FILENAME
        )
        with importlib.resources.as_file(schema_resource) as schema_path:
            if not validate_config(ctx.obj["config"], schema_path):
                raise typer.Exit(code=1)
    except (FileNotFoundError, ModuleNotFoundError) as e:
        console.print(f"[red]Error:[/red] Could not locate schema file: {e}")
        raise typer.Exit(code=1)  # noqa: B904


hpc = typer.Typer(help="HPC cluster lifecycle")
cloud = typer.Typer(help="Cloud (K8s) cluster lifecycle")
app.add_typer(hpc, name="hpc")
app.add_typer(cloud, name="cloud")


@hpc.command()
def hpc_start(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("hpc start")


@hpc.command()
def hpc_stop(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("hpc stop")


@hpc.command()
def hpc_status(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("hpc status")


@hpc.command()
def hpc_destroy(ctx: typer.Context) -> None:  # noqa: ARG001
    abort_not_implemented("hpc destroy")


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


if __name__ == "__main__":
    try:
        app()
    except typer.Exit as exit_exc:
        sys.exit(exit_exc.exit_code)
