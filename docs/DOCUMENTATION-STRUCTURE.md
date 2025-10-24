# Documentation Structure

**Status:** Complete  
**Last Updated:** 2025-10-16

## Overview

This document provides a complete overview of the Hyperscaler on Workstation project documentation structure.
The documentation is organized following the principle that component-specific documentation lives next to the
code implementing that component, while high-level documentation lives in `docs/` for cross-component guides,
tutorials, and architecture.

## High-Level Documentation (docs/)

```text
docs/
├── README.md                          # Main documentation index
├── getting-started/                   # User onboarding
│   ├── prerequisites.md
│   ├── installation.md
│   ├── quickstart-5min.md
│   ├── quickstart-cluster.md
│   ├── quickstart-gpu.md
│   ├── quickstart-containers.md
│   └── quickstart-monitoring.md
├── tutorials/                         # Learning paths (end-to-end workflows)
│   ├── 01-first-cluster.md
│   ├── 02-distributed-training.md
│   ├── 03-gpu-partitioning.md
│   ├── 04-container-management.md
│   ├── 05-custom-images.md
│   ├── 06-monitoring-setup.md
│   └── 07-job-debugging.md
├── architecture/                      # High-level architecture (system-wide)
│   ├── overview.md                    # Overall system architecture
│   ├── network.md                     # Network topology and design
│   ├── storage.md                     # Storage architecture
│   ├── gpu.md                         # GPU virtualization strategy
│   ├── containers.md                  # Container architecture overview
│   ├── slurm.md                       # SLURM cluster architecture
│   └── monitoring.md                  # Monitoring architecture
├── storage-configuration.md           # Storage backend configuration guide
├── operations/                        # Operational procedures (cross-component)
│   ├── deployment.md
│   ├── maintenance.md
│   ├── backup-recovery.md
│   ├── scaling.md
│   ├── security.md
│   └── performance-tuning.md
├── workflows/                         # High-level workflows
│   ├── CLUSTER-DEPLOYMENT-WORKFLOW.md
│   ├── GPU-GRES-WORKFLOW.md
│   ├── SLURM-COMPUTE-WORKFLOW.md
│   ├── APPTAINER-CONVERSION-WORKFLOW.md
│   └── VIRTIO-FS-INTEGRATION.md
├── troubleshooting/                   # Cross-component troubleshooting
│   ├── common-issues.md
│   ├── debugging-guide.md
│   ├── faq.md
│   └── error-codes.md
├── testing/                           # Link to tests/README.md
│   └── README.md -> ../../tests/README.md
├── design-docs/                       # Design decisions
└── implementation-plans/              # Implementation task lists
```

## Component-Specific Documentation (next to code)

```text
ansible/
├── README.md                          # Ansible overview and usage
├── README-packer-ansible.md           # Packer integration
├── roles/
│   ├── README.md                      # Roles index and guide
│   ├── <role-name>/
│   │   ├── README.md                  # Role-specific documentation
│   │   └── ...
│   └── nvidia-gpu-drivers/
│       └── README.md                  # GPU driver role docs
└── playbooks/
    └── README.md                      # Playbooks index and usage

config/
└── README.md                          # Configuration reference

containers/
├── README.md                          # Container definitions guide
├── images/
│   └── <container-name>/
│       └── README.md                  # Container-specific docs

docker/
└── README.md                          # Dev environment setup

packer/
├── README.md                          # Packer templates guide
├── hpc-base/
│   └── README.md                      # Base image documentation
├── hpc-controller/
│   └── README.md                      # Controller image documentation
└── hpc-compute/
    └── README.md                      # Compute image documentation

python/ai_how/
├── README.md                          # CLI overview
└── docs/                              # Comprehensive CLI docs
    ├── api/
    ├── development.md
    ├── examples.md
    ├── index.md
    ├── network_configuration.md
    └── pcie-passthrough-validation.md

scripts/
├── README.md                          # Scripts index and usage
├── system-checks/
│   └── README.md                      # System check scripts docs
└── experiments/
    └── README.md                      # Experimental scripts

tests/
├── README.md                          # Testing framework
├── test-infra/
│   └── README.md                      # Test infrastructure
└── suites/
    └── <suite-name>/
        └── README.md                  # Test suite documentation
```

## Documentation Philosophy

### Component-Specific Documentation

- Lives next to the code implementing that component
- Maintains close coupling between code and documentation
- Easier to keep documentation in sync with code changes
- Examples: Ansible roles, Packer templates, CLI commands

### High-Level Documentation

- Lives in `docs/` for cross-component guides, tutorials, and architecture
- Provides user-facing documentation that spans multiple components
- Examples: Getting started guides, architecture overviews, troubleshooting

## File Status

All placeholder files are currently marked with `**Status:** TODO` and contain a brief overview section. As content is
added to each file, the status should be updated to reflect the completion level.

## Navigation

The documentation structure is designed to work with MkDocs, which will provide:

- Automatic navigation based on directory structure
- Search functionality across all documentation
- Cross-references between documents
- Mobile-friendly responsive design

## Maintenance

- Update documentation when code changes
- Quarterly documentation review
- Link to source code files where appropriate
- Track documentation debt and user feedback
