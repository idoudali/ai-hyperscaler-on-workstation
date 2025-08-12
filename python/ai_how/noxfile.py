"""Nox configuration for ai-how project."""

import nox

nox.options.default_venv_backend = "uv"


@nox.session(python=["3.11"])
def test(session):
    """Run the test suite."""
    session.install(".[dev]")
    session.run("pytest", *session.posargs)


@nox.session(python=["3.11"])
def lint(session):
    """Run linting and formatting checks."""
    session.install(".[dev]")
    session.run("ruff", "check", "src", "tests")
    session.run("ruff", "format", "--check", "src", "tests")
    session.run("black", "--check", "src", "tests")
    session.run("mypy", "src")


@nox.session(python=["3.11"])
def format(session):
    """Format code with ruff and black."""
    session.install(".[dev]")
    session.run("ruff", "format", "src", "tests")
    session.run("black", "src", "tests")


@nox.session(python=["3.11"])
def docs(session):
    """Build the documentation."""
    session.install(".[docs]")
    session.run("mkdocs", "build")


@nox.session(python=["3.11"])
def docs_serve(session):
    """Serve the documentation locally."""
    session.install(".[docs]")
    session.run("mkdocs", "serve")


@nox.session(python=["3.11"])
def clean(session):
    """Clean up build artifacts."""
    session.run(
        "rm",
        "-rf",
        ".pytest_cache",
        ".coverage",
        "htmlcov",
        "dist",
        "build",
        external=True,
    )
    session.run("rm", "-rf", "*.egg-info", external=True)
