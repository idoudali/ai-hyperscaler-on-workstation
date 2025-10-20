# Quick Reference (Shared)

## Essential Commands

| Task | Command |
|------|---------|
| Build container | `make build-docker` |
| Configure CMake | `make config` |
| Run in container | `make run-docker COMMAND="..."` |
| Interactive shell | `make shell-docker` |
| Test Python CLI | `make test-ai-how` |
| Run full tests | `cd tests && make test` |
| Quick tests | `cd tests && make test-quick` |
| Interactive commit | `cz commit` |
| Show all targets | `make help` |

## File Locations

| Component | Location |
|-----------|----------|
| Python CLI | `python/ai_how/` |
| Ansible playbooks | `ansible/playbooks/` |
| Test framework | `tests/` |
| Packer templates | `packer/*/` |
| Shared AI rules | `.ai/rules/` |
| Cursor config | `.cursor/` |
| Claude config | `.claude/` |
| Docker container | `docker/Dockerfile` |

## Configuration Files

| File | Purpose |
|------|---------|
| `Makefile` | Primary workflow interface |
| `CMakeLists.txt` | Build system configuration |
| `pyproject.toml` | Python package configuration |
| `.ai/rules/` | Shared agent rules |
| `.claude/settings.json` | Claude configuration |
| `.cursor/rules/` | Cursor rules (symlinks to .ai/) |
| `.env.ai` | Shared environment variables |

## Python CLI Usage

```bash
# Activate virtual environment
source .venv/bin/activate

# Show help
ai-how --help

# Provision cluster
ai-how provision --cluster-file config/cluster.yaml

# Destroy cluster
ai-how destroy --cluster-file config/cluster.yaml
```

## Test Commands

```bash
# Run all tests
cd tests/
make test

# Quick validation tests
make test-quick

# Test specific component
make test-libvirt
make test-ansible
make test-slurm
```

## Container Workflow

```bash
# Build development container
make build-docker

# Enter interactive shell
make shell-docker

# Run single command
make run-docker COMMAND="cmake --build build"

# Clean container
make clean-docker
```

## Git Workflow

```bash
# Stage changes
git add <files>

# Interactive commit (recommended)
cz commit

# Push changes
git push origin <branch>

# NEVER run these without approval:
# - git push --force
# - git reset --hard
# - git rebase --continue (after conflicts)
```

## Safety Checklist

Before any operation, verify:

- [ ] Using container for builds
- [ ] Presented modified files with staging commands
- [ ] Not auto-staging files (present commands, let user stage)
- [ ] Presented change summary before commit
- [ ] Awaited user approval for git operations
- [ ] Not running force operations
- [ ] Not auto-continuing after merge conflicts
- [ ] Running pre-commit on staged files only (not --all-files)
- [ ] Not auto-staging pre-commit fixes (delegate to user)
