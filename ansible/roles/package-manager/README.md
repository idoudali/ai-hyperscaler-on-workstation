# Package Manager Common Role - DEPRECATED

⚠️ **DEPRECATION NOTICE**: This role was part of an experimental consolidation effort that has been reverted.

This role was created as part of the `base-packages` consolidation initiative. Development has been paused and
component-specific package installation in individual roles is the recommended approach.

## Purpose

Eliminate duplicate package installation logic by providing a unified, parameterized approach to:

- Checking if packages are already installed
- Locating packages on remote host (Packer builds) or controller (runtime)
- Copying packages from controller to remote when needed
- Installing packages with proper dependency handling
- Providing consistent error messages

## Usage

### Basic Usage

```yaml
- name: Install BeeGFS management packages
  ansible.builtin.import_role:
    name: package-manager
  vars:
    package_name: "BeeGFS Management"
    package_binary_path: "/usr/bin/beegfs-mgmtd"
    package_files:
      - "beegfs-mgmtd_{{ beegfs_version }}_*.deb"
      - "beegfs-utils_{{ beegfs_version }}_*.deb"
    package_remote_path: "/tmp/beegfs-packages"
    package_source_dir: "{{ playbook_dir }}/../../build/packages/beegfs"
    package_dependencies:
      - libssl3
      - libattr1
    component_tag: "beegfs-mgmt"
```

### Advanced Usage with DPKG

For packages that need better dependency resolution:

```yaml
- name: Install SLURM controller packages
  ansible.builtin.import_role:
    name: package-manager
  vars:
    package_name: "SLURM Controller"
    package_binary_path: "/usr/sbin/slurmctld"
    package_files:
      - "slurm-smd_{{ slurm_version }}-1_*.deb"
    package_remote_path: "/tmp/slurm-packages"
    package_source_dir: "{{ playbook_dir }}/../../build/packages/slurm"
    use_dpkg_install: true  # Use dpkg + apt install -f for complex dependencies
    component_tag: "slurm-controller"
```

## Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `package_name` | Human-readable name for logs and errors | `"BeeGFS Management"` |
| `package_binary_path` | Path to check if installed | `"/usr/bin/beegfs-mgmtd"` |
| `package_files` | List of package filename patterns | `["beegfs-mgmtd_*.deb"]` |
| `package_remote_path` | Where packages are on remote host | `"/tmp/beegfs-packages"` |
| `package_source_dir` | Where packages are on controller | `"build/packages/beegfs"` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `package_dependencies` | `[]` | List of APT packages to install first |
| `component_tag` | `"package-install"` | Tag for Ansible organization |
| `verify_command` | `""` | Command to verify installation |
| `install_dependencies` | `true` | Whether to install dependencies |
| `update_cache` | `false` | Whether to update apt cache |
| `use_dpkg_install` | `false` | Use dpkg+apt-fix for complex dependencies |

## Installation Flow

1. **Check Installation**: Verify if component is already installed by checking binary path
2. **Locate Packages**: Search for packages on remote host (Packer builds)
3. **Copy Packages**: If not found on remote, search controller and copy (runtime)
4. **Install**: Install packages with proper dependency handling
5. **Verify**: Run optional verification command

## Benefits

- ✅ DRY package management - single source of truth
- ✅ Consistent error messages across all components
- ✅ Proper handling of Packer vs runtime modes
- ✅ Flexible dependency management (apt or dpkg)
- ✅ Reduced code duplication (hundreds of lines saved)

## Examples

See usage in:

- `ansible/roles/beegfs-mgmt/tasks/install.yml`
- `ansible/roles/beegfs-meta/tasks/install.yml`
- `ansible/roles/slurm-controller/tasks/install.yml`
- `ansible/roles/slurm-compute/tasks/install.yml`

## Task Organization

```text
tasks/
├── main.yml              # Entry point and orchestration
├── check-installation.yml # Check if already installed
├── copy-packages.yml      # Copy from controller to remote
└── install-packages.yml   # Install packages with dependencies
```
