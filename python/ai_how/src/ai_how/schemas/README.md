# ai_how.schemas Documentation

## Lazy Loading

The schema is now loaded lazily to prevent import failures. This means the
schema file is only loaded when you first call one of the utility functions, not
at module import time.

### Utility Functions

The schema module provides several utility functions for easy access to schema
information:

```python
from ai_how.schemas import (
    get_schema_version,
    get_schema_title,
    get_schema_description,
    get_required_fields,
)

# Get schema metadata
version = get_schema_version()  # Returns "^1\.0$"
title = get_schema_title()      # Returns "Hyperscaler Cluster Configuration"
description = get_schema_description()  # Returns "Schema for the cluster.yaml file"
required_fields = get_required_fields()  # Returns ["version", "metadata", "global", "clusters"]
```

### Schema Structure

The cluster schema defines the structure for cluster configuration files with
the following main sections:

- **version**: Schema version (must match pattern "^1\.0$")
- **metadata**: Cluster name and description
- **global**: Global configuration including GPU allocation strategy
- **clusters**: HPC and cloud cluster definitions

### GPU Allocation Strategies

The schema supports three GPU allocation strategies:

- `mig`: Multi-Instance GPU slices
- `whole`: Whole GPU allocation
- `hybrid`: Combination of both approaches

### Cluster Types

- **HPC Cluster**: SLURM-based high-performance computing cluster
- **Cloud Cluster**: Kubernetes-based cloud-native cluster

## Example

See `examples/schema_usage.py` for a complete demonstration of how to use the
schema.

## Development

When modifying the schema:

1. Update `cluster.schema.json`
2. Test the changes using the example script
3. Update this documentation if needed
4. Ensure the schema validates correctly with your configuration files

## Dependencies

The schema module requires:

- `pathlib.Path` for file path operations
- `json` for JSON parsing
- `typing` for type hints
- `logging` for error logging

## Error Handling

The schema module includes robust error handling:

- If the schema file cannot be loaded, a minimal fallback schema is returned
- Import failures are prevented even if the schema file is missing or corrupted
- Errors are logged for debugging purposes
