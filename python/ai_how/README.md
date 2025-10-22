# AI-HOW CLI

Self-contained Python package providing a CLI to manage the Hyperscaler on
Workstation clusters.

## Prerequisites

- Python 3.11+
- [Uv](https://github.com/astral-sh/uv) package manager

## Installation

### Using Uv (Recommended)

```bash
# Clone and install in development mode
git clone <repository>
cd ai_how
uv sync --dev
uv run ai-how --help
```

### Traditional Installation

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e .
```

## Development

This project uses [Nox](https://nox.thea.codes/) with
**nox-uv** for fast and reliable testing and
development workflows.

### Quick Start with Nox

```bash
# Install development dependencies (includes nox and nox-uv)
uv sync --dev

# List available nox sessions
uv run nox --list

# Run tests
uv run nox --session test

# Run linting
uv run nox --session lint

# Format code
uv run nox --session format

# Build documentation
uv run nox --session docs

# Serve documentation locally
uv run nox --session docs_serve

# Clean build artifacts
uv run nox --session clean
```

### Nox with nox-uv Integration

This project leverages `nox-uv` for seamless integration between Nox and uv,
providing:

- **Ultra-fast dependency resolution**: Uses uv's Rust-based resolver for
  lightning-fast package installation
- **Automatic dependency installation**: Each session automatically installs the
  required dependencies
- **Better caching**: Aggressive caching reduces repeated downloads and
  environment creation time
- **Lock file compatibility**: Full integration with `uv.lock` for reproducible
  builds

All Nox sessions automatically install the required dependencies using
`s.install(".[dev]")` or `s.install(".[docs]")` for development and
documentation dependencies respectively.

## Usage

```bash
ai-how --help
```

## Project Structure

```plain
ai_how/
├── src/ai_how/          # Source code
├── tests/               # Test suite
├── docs/                # Documentation
├── pyproject.toml       # Project configuration
├── uv.lock             # Locked dependencies
├── noxfile.py          # Nox configuration
└── README.md           # This file
```
