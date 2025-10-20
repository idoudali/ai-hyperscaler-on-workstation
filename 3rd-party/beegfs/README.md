# BeeGFS Package Build

**Status:** TODO  
**Created:** 2025-01-20  
**Last Updated:** 2025-01-20

## Overview

This component builds BeeGFS parallel filesystem packages from source for use in HPC infrastructure images.

## TODO: Component Documentation

This README needs to be completed with:

- [ ] Build process documentation
- [ ] Configuration options
- [ ] Dependencies and requirements
- [ ] Usage examples
- [ ] Troubleshooting guide
- [ ] Integration with Packer images

## Build Commands

```bash
# Build BeeGFS packages
cmake --build build --target build-beegfs-packages

# List built packages
cmake --build build --target list-beegfs-packages

# Clean build artifacts
cmake --build build --target clean-beegfs
```

## Related Documentation

- [Build System Architecture](docs/architecture/build-system.md)
- [Packer Images](packer/README.md)
