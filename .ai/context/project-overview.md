# Project Overview (Shared Context)

**Name**: Pharos.ai Hyperscaler on Workstation
**Purpose**: Emulate AI/HPC infrastructure on single workstation
**Stack**: KVM + SLURM + BeeGFS + Kubernetes-ready + MIG GPU support

## Architecture

```text
Cluster YAML → ai-how CLI → Libvirt VMs → Ansible → HPC Cluster
```

## Components

- **ai-how CLI**: Python CLI tool for cluster provisioning
- **Libvirt/KVM**: VM hypervisor for emulating nodes
- **Ansible**: IaC for deploying SLURM/BeeGFS stack
- **Packer**: VM image building
- **SLURM**: HPC workload scheduler with GPU support
- **BeeGFS**: Parallel filesystem
- **MIG**: Multi-Instance GPU partitioning

## Primary Commands

- Build: `make build-docker`
- Test: `cd tests/ && make test`
- CLI: `source .venv/bin/activate && ai-how`
- Configure: `make config`

## Safety Rules

- Container-only builds (never on host)
- Never auto-stage files (present files with staging commands)
- User approval for commits
- Never force push or hard reset
- Never auto-continue after merge conflicts
- Present summary before any git operations

## Project Structure

```text
ai-hyperscaler-on-workstation-3/
├── ansible/          # IaC deployment playbooks
├── python/ai_how/    # Python CLI package
├── packer/           # VM image templates
├── docker/           # Development environment
├── tests/            # Test framework
├── .ai/              # Shared AI agent config
├── .cursor/          # Cursor-specific config
└── .claude/          # Claude-specific config
```

## Technology Stack

- **Languages**: Python 3.11+, Bash, HCL (Terraform/Packer)
- **IaC**: Ansible, Packer, Terraform (planned)
- **Virtualization**: Libvirt, KVM, QEMU
- **HPC**: SLURM, BeeGFS, MIG GPU
- **Development**: Docker, CMake, Ninja
- **Testing**: Bash test framework, pytest
- **Code Quality**: ruff, mypy, pre-commit

## Development Workflow

1. All operations through Makefile
2. All builds in Docker container
3. Conventional commits (`cz commit`)
4. Pre-commit hooks enforced
5. Test before commit
