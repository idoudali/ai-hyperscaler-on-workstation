"""Nox configuration for ai-how project."""

from __future__ import annotations

from nox import Session, options
from nox_uv import session

options.default_venv_backend = "uv"


@session(python=["3.11"])
def test(s: Session) -> None:
    """Run the test suite."""
    s.install(".[dev]")
    s.run("python", "-m", "pytest", *s.posargs)


@session(python=["3.11"])
def lint(s: Session) -> None:
    """Run linting and formatting checks."""
    s.install(".[dev]")
    # Check if --fix flag is passed
    if "--fix" in s.posargs:
        s.run("ruff", "check", "--fix", "src", "tests")
        s.run("ruff", "format", "src", "tests")
        s.run("black", "src", "tests")
    else:
        s.run("ruff", "check", "src", "tests")
        s.run("ruff", "format", "--check", "src", "tests")
        s.run("black", "--check", "src", "tests")
    s.run("mypy", "src")


@session(python=["3.11"])
def lint_fix(s: Session) -> None:
    """Automatically fix linting and formatting issues."""
    s.install(".[dev]")
    s.run("ruff", "check", "--fix", "src", "tests")
    s.run("ruff", "format", "src", "tests")
    s.run("black", "src", "tests")
    s.run("mypy", "src")


@session(python=["3.11"])
def format(s: Session) -> None:
    """Format code with ruff and black."""
    s.install(".[dev]")
    s.run("ruff", "format", "src", "tests")
    s.run("black", "src", "tests")


@session(python=["3.11"])
def docs(s: Session) -> None:
    """Build the documentation."""
    s.install(".[docs]")
    s.run("mkdocs", "build")


@session(python=["3.11"])
def docs_serve(s: Session) -> None:
    """Serve the documentation locally."""
    s.install(".[docs]")
    s.run("mkdocs", "serve")


@session(python=["3.11"])
def clean(s: Session) -> None:
    """Clean up build artifacts."""
    s.run(
        "rm",
        "-rf",
        ".pytest_cache",
        ".coverage",
        "htmlcov",
        "dist",
        "build",
        external=True,
    )
    s.run("rm", "-rf", "*.egg-info", external=True)
