# SLURM Common Role - DEPRECATED

⚠️ **DEPRECATION NOTICE**: This role was part of an experimental consolidation effort that has been reverted.

This role was created to extract common MUNGE setup and SLURM configuration shared between the `slurm-controller`
and `slurm-compute` roles. Development has been paused and the approach of maintaining these setups within each
role-specific implementation is the recommended approach.

## Historical Purpose

The role was designed to:

- Consolidate MUNGE authentication setup for both controller and compute nodes
- Extract common SLURM directory and permissions configuration
- Unified user and group creation
- Reduce code duplication between slurm-controller and slurm-compute

## Current Status

**Deprecated** - Use `slurm-controller` and `slurm-compute` roles directly.

## Migration Guide

If you're using this role, follow these steps:

1. Review the `slurm-controller/tasks/main.yml` and `slurm-compute/tasks/main.yml` for MUNGE and SLURM setup
2. Ensure both roles have the necessary MUNGE configuration tasks
3. Remove any references to `slurm-common` from playbooks
4. Test thoroughly with controller and compute node deployments

## See Also

- [slurm-controller/README.md](../slurm-controller/README.md) - Controller node role
- [slurm-compute/README.md](../slurm-compute/README.md) - Compute node role
