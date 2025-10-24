# Build System Components Documentation

**Status:** In Progress
**Last Updated:** 2025-10-24

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

**Related Documentation:**

- User guide: [Build System Architecture](../architecture/build-system.md)
