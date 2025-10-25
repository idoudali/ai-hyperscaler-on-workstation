# Ansible - Automation and Configuration Management

**Status:** Production  
**Last Updated:** 2025-10-26  
**Scope:** Ansible playbooks, roles, facts, and debugging guides

## Overview

This folder contains comprehensive documentation for Ansible automation within the AI-HOW project. It covers
best practices for writing playbooks, understanding system facts, debugging execution issues, and managing
configuration across HPC infrastructure.

**Audience:** DevOps engineers, infrastructure teams, automation specialists, and developers working with Ansible playbooks.

## Documentation Index

### Core Guides

#### **Ansible Facts Reference**

**File:** [facts-reference.md](facts-reference.md)

Complete guide to Ansible facts - where they come from, how to inspect them, and how to use them in playbooks.

**Includes:**

- What are Ansible facts and how they're collected
- Common system, hardware, and network facts
- Methods to inspect facts (setup module, filtering, caching)
- Using facts in playbooks, templates, and conditionals
- Custom facts creation
- Fact caching configuration
- Real-world examples (kernel headers, cross-platform configs, memory-based settings)
- Troubleshooting fact gathering issues

**Key Sections:**

- `ansible_kernel` - Critical for kernel module compilation
- `ansible_os_family` - Used for platform-specific tasks
- Fact caching for performance optimization

**Use Case:** When you need to understand how to use system variables in Ansible playbooks, especially for
dynamic configurations based on host properties.

#### **Ansible Debugging Guide**

**File:** [debugging-guide.md](debugging-guide.md)

Comprehensive guide to debugging Ansible playbooks, understanding task skipping, and troubleshooting execution issues.

**Includes:**

- Configuration settings in ansible.cfg
- Verbosity levels (-v, -vv, -vvv, -vvvv)
- Common skip reasons and how to debug them
- Advanced debugging techniques (interactive debugger, assert module)
- Tag filtering issues and resolution
- Variable inspection and registration tracking
- Real example: BeeGFS kernel module tag filtering bug
- Best practices and checklist for debugging

**Key Debugging Techniques:**

- Using `-vvv` to see skip reasons
- Adding debug tasks with `tags: [debug, always]`
- Understanding tag filtering with `--list-tasks`
- Variable state inspection
- Conditional evaluation testing

**Use Case:** When tasks are mysteriously skipping, variables are undefined, or playbook execution behaves
unexpectedly. Essential for troubleshooting complex deployments.

## Related Resources

### Ansible Directories (Living Code)

The following directories contain the actual Ansible implementation:

- **`ansible/roles/`** - Reusable Ansible roles for infrastructure components
- **`ansible/playbooks/`** - Playbook definitions for various deployment scenarios
- **`ansible/inventories/`** - Inventory files and host configurations

Reference `ansible/README.md` for role and playbook documentation.

### Component Documentation Using Ansible

These components integrate Ansible for deployment and configuration:

- **BeeGFS:** [docs/components/beegfs/README.md](../beegfs/README.md) - File system setup using Ansible roles
- **SLURM:** `ansible/roles/slurm-*` - Job scheduler configuration
- **GPU Support:** `ansible/roles/nvidia-*` - GPU driver and GRES setup
- **Monitoring:** `ansible/roles/monitoring-*` - Prometheus and Grafana setup

## Quick Reference

### Inspecting Facts

```bash
# Get all facts for a host
ansible hostname -i inventory -m setup

# Filter specific facts
ansible all -i inventory -m setup -a "filter=ansible_kernel"

# View cached facts
ls -la /tmp/ansible_facts/
```

### Debugging Playbooks

```bash
# Run with verbose output to see skip reasons
ansible-playbook playbook.yml -vvv

# List which tasks would run with specific tags
ansible-playbook playbook.yml --tags install --list-tasks

# Add to ansible.cfg for development
display_skipped_hosts = True
display_ok_hosts = True
```

## Best Practices

### DO:

- ✅ Use `ansible_kernel` for kernel-dependent operations
- ✅ Enable `display_skipped_hosts` during development
- ✅ Use `-vvv` when debugging unexpected behavior
- ✅ Add debug tasks with `tags: [debug, always]`
- ✅ Use `assert` module to validate prerequisites
- ✅ Give check tasks the same tags as dependent tasks

### DON'T:

- ❌ Assume undefined variables will fail loudly
- ❌ Use `failed_when: false` to hide problems
- ❌ Mix tasks with incompatible tags when they depend on each other
- ❌ Run with `display_skipped_hosts = False` when debugging

## Common Issues and Solutions

### Issue: Tasks Skip Unexpectedly

**Solution:** Use `-vvv` to see skip reasons, check tag filtering with `--list-tasks`, verify variables with debug tasks.

See [Ansible Debugging Guide](debugging-guide.md#3-understanding-why-tasks-are-skipped) for detailed troubleshooting.

### Issue: Kernel Module Build Fails

**Solution:** Verify kernel version matches installed headers using `ansible_kernel` fact.

```bash
ansible all -m debug -a "var=ansible_kernel"
dpkg -s linux-headers-$(uname -r)
```

See [Ansible Facts Reference](facts-reference.md#example-1-kernel-headers-installation-our-use-case) for details.

## Integration Points

### With BeeGFS

The Ansible facts guide includes a real-world example of using `ansible_kernel` for BeeGFS client kernel module
installation, which requires matching kernel headers to the running kernel version.

### With HPC Deployment

Ansible facts are essential for:

- Dynamic kernel header selection
- Cross-platform package installation
- Memory-based worker process configuration
- Network interface configuration

## Related Documentation

### Infrastructure Guides

- [BeeGFS Setup Guide](../beegfs/setup-guide.md) - Uses `ansible_kernel` fact
- [Testing Framework](../testing-framework-guide.md) - Ansible integration in tests
- [Architecture - Build System](../../architecture/build-system.md) - How Ansible fits in build process

### Ansible Official Resources

- [Ansible Facts Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_vars_facts.html)
- [Ansible Debugging Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html)
- [Ansible Tags](https://docs.ansible.com/ansible/latest/user_guide/playbooks_tags.html)

## Next Steps

1. **For Learning:** Start with [Ansible Facts Reference](facts-reference.md) to understand how to use system variables
2. **For Debugging:** Refer to [Ansible Debugging Guide](debugging-guide.md) when playbooks don't behave as expected
3. **For Real-World Usage:** Check BeeGFS documentation for a practical example of facts usage

---

**Last Updated:** 2025-10-26  
**Audience:** Infrastructure engineers, automation specialists, HPC operators  
**Status:** Production
