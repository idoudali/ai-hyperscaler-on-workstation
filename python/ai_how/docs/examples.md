# Usage Examples

This page provides practical examples of how to use AI-HOW for common tasks.

## Basic Configuration Validation

### Validate a YAML Configuration File

```bash
# Basic validation
ai-how validate config.yaml

# Verbose output
ai-how validate --verbose config.yaml

# Output validation results to a file
ai-how validate --output results.json config.yaml
```

### Example Configuration File

Here's an example of a valid configuration file:

```yaml
# config.yaml
cluster:
  name: "my-hyperscaler-cluster"
  version: "1.0.0"
  nodes:
    - name: "node-1"
      type: "compute"
      resources:
        cpu: 8
        memory: "32Gi"
        gpu: 1
    - name: "node-2"
      type: "storage"
      resources:
        cpu: 4
        memory: "16Gi"
        storage: "1Ti"

settings:
  logging:
    level: "INFO"
    format: "json"
  monitoring:
    enabled: true
    interval: 30
```

## Advanced Usage

### Custom Schema Validation

You can use custom JSON schemas for validation:

```bash
# Validate against a custom schema
ai-how validate --schema custom-schema.json config.yaml
```

### Batch Validation

Validate multiple configuration files at once:

```bash
# Validate all YAML files in a directory
for file in configs/*.yaml; do
  echo "Validating $file..."
  ai-how validate "$file"
done
```

## Error Handling

### Common Validation Errors

When validation fails, AI-HOW provides detailed error messages:

```bash
$ ai-how validate invalid-config.yaml
❌ Validation failed for invalid-config.yaml

Error: 'cluster' is a required property
  File: invalid-config.yaml
  Line: 1

Error: 'nodes' is a required property
  File: invalid-config.yaml
  Line: 1
```

### Debugging Configuration Issues

Use the `--verbose` flag for more detailed error information:

```bash
ai-how validate --verbose config.yaml
```

## Integration Examples

### CI/CD Pipeline Integration

```yaml
# .github/workflows/validate.yml
name: Validate Configuration
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install AI-HOW
        run: |
          pip install -e ".[dev]"
      - name: Validate Configuration
        run: |
          ai-how validate config.yaml
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-config
        name: Validate Configuration
        entry: ai-how validate
        language: system
        files: \.(yaml|yml)$
        pass_filenames: true
```

## Troubleshooting

### Common Issues

1. **Schema Not Found**: Ensure the schema file exists and is accessible
2. **Invalid YAML**: Check for syntax errors in your YAML files
3. **Permission Denied**: Ensure you have read access to configuration files

### Getting Help

```bash
# Show help for the validate command
ai-how validate --help

# Show general help
ai-how --help
```
