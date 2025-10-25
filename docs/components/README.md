# Build System Components Documentation

**Status:** In Progress
**Last Updated:** 2025-10-26

Component-specific implementation documentation for the build system. These documents provide detailed
technical reference for developers working with specific build components.

## Components

### CMake Implementation Reference

**File:** [cmake-implementation.md](cmake-implementation.md)

Comprehensive technical reference for the CMake build system architecture, targets, and
workflows.

- CMake layer architecture (Packer, Containers, 3rd-party dependencies)
- Detailed CMakeLists.txt reference for each layer
- Build target dependencies and graphs
- Adding new components (Packer images, containers)
- Troubleshooting and performance optimization

**Audience:** Developers extending the build system, build system maintainers

### Testing Framework Developer Guide

**File:** [testing-framework-guide.md](testing-framework-guide.md)

Comprehensive guide to the Bash-based testing framework for HPC infrastructure validation.

- Framework architecture and organization (16 test suites, 20 orchestrators)
- Standardized CLI pattern for all test scripts
- Test configurations (17 YAML profiles)
- Utility modules reference (logging, cluster, Ansible, VM management)
- Writing new tests and test suites with examples
- Execution phases and recommended test order
- Makefile targets (22 test targets)
- Logging and output structure
- Development workflow and debugging procedures
- CI/CD integration examples

**Audience:** Test developers, infrastructure engineers, CI/CD maintainers

### BeeGFS (BeeOND) - Berkeley Parallel File System

**Folder:** [beegfs/README.md](beegfs/README.md)

Comprehensive guide to setting up BeeGFS (BeeOND) distributed storage for HPC infrastructure.
Covers complete deployment from management node through client mounting, kernel module compilation,
troubleshooting, and performance optimization.

**Includes:**

- Architecture overview and deployment order
- Complete setup for each component (management, metadata, storage, client)
- Installation flow and component integration patterns
- Critical kernel module build issues and fixes
- Comprehensive troubleshooting guide
- Performance monitoring and tuning
- Integration with Ansible playbooks
- DKMS build failure fixes and diagnostics

**Key Topics:**

- Kernel version mismatch detection and fix
- DKMS module compilation troubleshooting
- Mount failure diagnostics
- Storage performance optimization
- Client caching tuning

**Related Files:**

- [beegfs/README.md](beegfs/README.md) - BeeGFS documentation index
- [beegfs/setup-guide.md](beegfs/setup-guide.md) - Main setup guide
- [beegfs/installation-flow.md](beegfs/installation-flow.md) - Deployment workflow
- [beegfs/fixes-summary.md](beegfs/fixes-summary.md) - Critical fixes summary
- [beegfs/client-role-fixes.md](beegfs/client-role-fixes.md) - DKMS fixes
- [beegfs/kernel-module-fix.txt](beegfs/kernel-module-fix.txt) - Quick reference

**Audience:** Infrastructure engineers, HPC operators, storage administrators

### Documentation Build System

**File:** [documentation-build-system.md](documentation-build-system.md)

Component-level documentation for the documentation build system, including MkDocs configuration,
plugin architecture, build workflow, and maintenance procedures.

- MkDocs configuration architecture and sections
- Plugin architecture (5 plugins including aggregation)
- Markdown extensions and features
- Navigation structure and principles
- Build workflow and commands
- Documentation standards and conventions
- Adding new documentation sections
- Troubleshooting build issues
- Theme customization
- CI/CD integration

**Audience:** Documentation maintainers, content creators, site administrators

## Related Documentation

- **User Guide:** [Build System Architecture](../architecture/build-system.md)
