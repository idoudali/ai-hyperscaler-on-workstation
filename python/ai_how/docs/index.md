# AI-HOW Documentation

Welcome to the AI-HOW documentation! AI-HOW is a Python CLI orchestrator for
managing the Hyperscaler on Workstation clusters.

## What is AI-HOW?

AI-HOW (AI Hyperscaler on Workstation) is a command-line interface tool designed
to simplify the management and orchestration of hyperscaler infrastructure
running on workstation environments. It provides a unified interface for common
cluster management tasks.

## Features

- **CLI Interface**: Simple command-line interface built with Typer
- **Configuration Validation**: JSON Schema-based validation for configuration
  files
- **Rich Output**: Beautiful terminal output with Rich library
- **YAML Support**: Native support for YAML configuration files
- **Extensible**: Plugin-based architecture for adding new functionality

## Quick Start

### Installation

```bash
# Install from source
git clone <repository-url>
cd ai-how
pip install -e .

# Or install with docs support
pip install -e ".[docs]"
```

### Basic Usage

```bash
# Get help
ai-how --help

# Validate a configuration file
ai-how validate config.yaml

# Run a specific command
ai-how <command> [options]
```

## Documentation Structure

- **[API Reference](api/ai_how.md)**: Complete API documentation
- **[Examples](examples.md)**: Usage examples and common patterns
- **[Development](development.md)**: Contributing and development guide

## Getting Help

If you encounter any issues or have questions:

1. Check the [examples](examples.md) for common use cases
2. Review the [API reference](api/ai_how.md) for detailed information
3. Open an issue on the GitHub repository
4. Check the project README for additional information

## Contributing

We welcome contributions! Please see the [development guide](development.md) for
information on how to contribute to the project.
