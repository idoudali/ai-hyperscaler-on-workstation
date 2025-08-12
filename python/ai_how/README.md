# AI-HOW CLI

Self-contained Python package providing a CLI to manage the Hyperscaler on Workstation clusters.

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

```bash
# Install development dependencies
uv sync --dev

# Run tests
uv run nox -s test

# Run linting
uv run nox -s lint

# Format code
uv run nox -s format

# Build documentation
uv run nox -s docs
```

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
└── README.md           # This file
```
