# Development Guide

This guide provides information for developers who want to contribute to the
AI-HOW project.

## Development Setup

### Prerequisites

- Python 3.10 or higher
- uv (recommended) or pip
- Git

### Local Development Environment

```bash
# Clone the repository
git clone <repository-url>
cd ai-how

# Create a virtual environment and install dependencies
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install the package in development mode
uv pip install -e ".[dev]"

# Install pre-commit hooks
pre-commit install
```

### Development Dependencies

The project uses several development tools:

- **nox**: Task automation and testing
- **pytest**: Testing framework
- **ruff**: Linting and formatting
- **black**: Code formatting
- **mypy**: Type checking
- **pre-commit**: Git hooks

## Project Structure

```text
ai-how/
├── src/
│   └── ai_how/
│       ├── __init__.py
│       ├── cli.py          # Main CLI interface
│       ├── validation.py   # Configuration validation
│       └── schemas/        # JSON schemas
├── tests/                  # Test files
├── docs/                   # Documentation
├── examples/               # Example configurations
├── pyproject.toml         # Project configuration
├── noxfile.py             # Nox tasks
└── README.md              # Project overview
```

## Development Workflow

### Running Tests

```bash
# Run all tests
nox -s test

# Run tests with specific Python version
nox -s test-3.11

# Run tests with coverage
nox -s test -- --cov-report=html
```

### Code Quality Checks

```bash
# Run all linting and formatting checks
nox -s lint

# Automatically fix issues
nox -s lint_fix

# Format code only
nox -s format
```

### Type Checking

```bash
# Run mypy type checking
nox -s lint -- mypy -p ai_how
```

### Building Documentation

```bash
# Build documentation
nox -s docs

# Serve documentation locally
nox -s docs_serve
```

## Code Style

### Python Code Style

The project follows these style guidelines:

- **Line Length**: 100 characters maximum
- **Formatting**: Black with double quotes
- **Linting**: Ruff with strict rules
- **Type Hints**: Required for all public functions

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/)
specification:

```text
feat: add new validation feature
fix: resolve schema loading issue
docs: update API documentation
style: format code with black
refactor: simplify validation logic
test: add tests for new feature
```

## Testing

### Writing Tests

- Place tests in the `tests/` directory
- Use descriptive test names
- Test both success and failure cases
- Use fixtures for common test data

Example test:

```python
import pytest
from ai_how.validation import validate_config

def test_validate_config_success():
    """Test successful configuration validation."""
    config = {"cluster": {"name": "test"}}
    result = validate_config(config)
    assert result.is_valid

def test_validate_config_failure():
    """Test configuration validation failure."""
    config = {"invalid": "config"}
    result = validate_config(config)
    assert not result.is_valid
    assert "cluster" in result.errors[0]
```

### Running Specific Tests

```bash
# Run a specific test file
pytest tests/test_validation.py

# Run a specific test function
pytest tests/test_validation.py::test_validate_config_success

# Run tests with verbose output
pytest -v

# Run tests and stop on first failure
pytest -x
```

## Documentation

### Building Documentation

```bash
# Build HTML documentation
nox -s docs

# Serve documentation locally
nox -s docs_serve
```

### Documentation Structure

- **index.md**: Main documentation page
- **api/**: API reference documentation
- **examples.md**: Usage examples
- **development.md**: This development guide

### Adding New Documentation

1. Create new markdown files in the `docs/` directory
2. Update `mkdocs.yml` navigation
3. Use proper markdown formatting
4. Include code examples where appropriate

## Contributing

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and commit them: `git commit -m 'feat: add amazing
   feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Code Review Guidelines

- Ensure all tests pass
- Check that code follows style guidelines
- Verify documentation is updated
- Test the changes locally

### Release Process

1. Update version in `pyproject.toml`
2. Update `CHANGELOG.md` with new features/fixes
3. Create a release tag
4. Build and publish to PyPI

## Troubleshooting

### Common Issues

**Import Errors**: Ensure you're in the correct virtual environment and have
installed the package in development mode.

**Test Failures**: Check that all dependencies are installed and up to date.

**Documentation Build Errors**: Verify that all required documentation
dependencies are installed.

**Pre-commit Hook Failures**: Run `pre-commit install` to set up the hooks
properly.

### Getting Help

- Check the project issues on GitHub
- Review the test files for examples
- Consult the project documentation
- Open a new issue for bugs or feature requests
