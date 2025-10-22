# Third-Party Dependencies

**Status:** Production  
**Created:** 2025-01-20  
**Last Updated:** 2025-01-20

## Overview

This directory contains build configurations for external dependencies that are built from
source and integrated into the HPC infrastructure images.

## Components

### [BeeGFS Packages](beegfs/README.md)

Parallel filesystem packages built from source for use in HPC infrastructure.

**Build Commands:**

```bash
# Build BeeGFS packages
cmake --build build --target build-beegfs-packages

# List built packages
cmake --build build --target list-beegfs-packages

# Clean build artifacts
cmake --build build --target clean-beegfs
```

### [SLURM Packages](slurm/README.md)

Workload manager packages (future implementation).

## Build System Integration

All third-party dependencies are integrated into the main build system through CMake targets.
The build process ensures that packages are available for Packer image building.

## Related Documentation

- **Build System Architecture** (docs/architecture/build-system.md)
- **Packer Images** (packer/README.md)
