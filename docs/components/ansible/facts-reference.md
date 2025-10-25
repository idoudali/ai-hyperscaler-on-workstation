# Ansible Facts Reference

**Last Updated:** 2025-10-26

Complete guide to Ansible facts - where they come from, how to inspect them, and how to use them.

## Quick Answer: Where Does `ansible_kernel` Come From?

```text
ansible_kernel = Output of `uname -r` on the target system

Source: Ansible setup module (runs automatically)
Example: "6.12.38+deb13-cloud-amd64"
Command equivalent: ssh user@host "uname -r"
```

## What Are Ansible Facts?

**Ansible Facts** are system variables automatically gathered from target hosts when a playbook runs. They
provide information about:

- Operating system details
- Hardware configuration
- Network settings
- Disk and filesystem info
- Kernel version
- Python interpreter
- And much more...

## How Facts Are Collected

### 1. Automatic Collection (Default)

```yaml
# When you run a playbook, Ansible automatically runs:
- name: Gathering Facts
  setup:
```

This happens **before** any of your tasks execute (unless disabled).

**In your playbook logs:**

```text
PLAY [Configure HPC Compute Nodes] ***

TASK [Gathering Facts] ***
ok: [hpc-compute01]
ok: [hpc-compute02]
```

### 2. Manual Collection

```bash
# Collect all facts for a host
ansible hostname -i inventory -m setup

# Filter for specific facts
ansible hostname -i inventory -m setup -a "filter=ansible_kernel"

# Get multiple related facts
ansible hostname -i inventory -m setup -a "filter=ansible_os_*"
```

### 3. Disabling Fact Gathering

```yaml
# In your playbook
- name: My Play
  hosts: all
  gather_facts: false  # ← Skip automatic fact gathering
  tasks:
    # Your tasks here
```

## Common Ansible Facts

### System Information

| Fact Variable | Description | Example Value | Shell Equivalent |
|--------------|-------------|---------------|------------------|
| `ansible_kernel` | Kernel version | `6.12.38+deb13-cloud-amd64` | `uname -r` |
| `ansible_os_family` | OS family | `Debian`, `RedHat`, `Windows` | `lsb_release -is` |
| `ansible_distribution` | OS distribution | `Ubuntu`, `Debian`, `CentOS` | `lsb_release -is` |
| `ansible_distribution_version` | OS version | `24.04`, `12`, `8` | `lsb_release -rs` |
| `ansible_distribution_release` | Release codename | `noble`, `bookworm` | `lsb_release -cs` |
| `ansible_hostname` | Short hostname | `hpc-compute01` | `hostname -s` |
| `ansible_fqdn` | Full hostname | `hpc-compute01.local` | `hostname -f` |
| `ansible_machine` | Machine architecture | `x86_64`, `aarch64` | `uname -m` |
| `ansible_python_version` | Python version | `3.11.2` | `python3 --version` |

### Hardware Information

| Fact Variable | Description | Example Value |
|--------------|-------------|---------------|
| `ansible_processor_cores` | CPU cores | `8` |
| `ansible_processor_vcpus` | Virtual CPUs | `16` |
| `ansible_memtotal_mb` | Total RAM in MB | `16384` |
| `ansible_memfree_mb` | Free RAM in MB | `8192` |
| `ansible_swaptotal_mb` | Total swap in MB | `2048` |
| `ansible_devices` | Disk devices | `{ "sda": {...}, "nvme0n1": {...} }` |

### Network Information

| Fact Variable | Description | Example Value |
|--------------|-------------|---------------|
| `ansible_default_ipv4.address` | Primary IPv4 | `192.168.100.11` |
| `ansible_default_ipv4.interface` | Primary interface | `enp1s0` |
| `ansible_all_ipv4_addresses` | All IPv4 addresses | `["192.168.100.11", "10.0.0.5"]` |
| `ansible_interfaces` | Network interfaces | `["lo", "enp1s0", "docker0"]` |
| `ansible_dns.nameservers` | DNS servers | `["8.8.8.8", "8.8.4.4"]` |

## How to Inspect Facts

### Method 1: View All Facts for a Host

```bash
# Get ALL facts (very long output!)
ansible hpc-compute01 -i ansible/inventories/test/hosts -m setup

# Save to file for inspection
ansible hpc-compute01 -i ansible/inventories/test/hosts -m setup > host_facts.json
```

### Method 2: Filter Specific Facts

```bash
# Kernel information
ansible all -i ansible/inventories/test/hosts -m setup -a "filter=ansible_kernel"

# OS information
ansible all -i ansible/inventories/test/hosts -m setup -a "filter=ansible_os*"

# Network information
ansible all -i ansible/inventories/test/hosts -m setup -a "filter=ansible_default_ipv4"

# Memory information
ansible all -i ansible/inventories/test/hosts -m setup -a "filter=ansible_mem*"

# All system facts (kernel, OS, machine)
ansible all -i ansible/inventories/test/hosts -m setup -a "filter=ansible_system"
```

### Method 3: Debug in Playbook

```yaml
- name: Show kernel version
  debug:
    msg: "Running kernel: {{ ansible_kernel }}"

- name: Show multiple facts
  debug:
    msg:
      - "Kernel: {{ ansible_kernel }}"
      - "OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
      - "Arch: {{ ansible_machine }}"
      - "Memory: {{ ansible_memtotal_mb }} MB"
```

### Method 4: View Cached Facts

Ansible caches facts in your configured cache location:

```bash
# From ansible.cfg
# fact_caching = jsonfile
# fact_caching_connection = /tmp/ansible_facts

# View cached facts
ls -la /tmp/ansible_facts/
cat /tmp/ansible_facts/hpc-compute01
```

## Using Facts in Playbooks

### Basic Usage

```yaml
- name: Install kernel headers matching running kernel
  apt:
    name: "linux-headers-{{ ansible_kernel }}"
    state: present

- name: Configure based on OS family
  package:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

- name: Set variable based on memory
  set_fact:
    worker_processes: "{{ (ansible_memtotal_mb / 1024) | int }}"
```

### Conditional Tasks Based on Facts

```yaml
- name: Install package on Debian-based systems
  apt:
    name: package
  when: ansible_os_family == "Debian"

- name: Install package on RedHat-based systems
  yum:
    name: package
  when: ansible_os_family == "RedHat"

- name: Only run on specific kernel version
  command: /usr/local/bin/special-command
  when: ansible_kernel is version('6.12', '>=')

- name: Configure based on available memory
  template:
    src: config.j2
    dest: /etc/myapp/config
  when: ansible_memtotal_mb >= 8192
```

### Using Facts in Templates

```jinja2
# templates/config.j2

# Auto-generated configuration
# Kernel: {{ ansible_kernel }}
# OS: {{ ansible_distribution }} {{ ansible_distribution_version }}

[server]
hostname = {{ ansible_hostname }}
listen_address = {{ ansible_default_ipv4.address }}
worker_processes = {{ ansible_processor_vcpus }}
max_memory = {{ ansible_memtotal_mb }}M

[network]
{% for interface in ansible_interfaces %}
interface_{{ loop.index }} = {{ interface }}
{% endfor %}
```

## Custom Facts

### Creating Custom Facts

You can define your own facts on target systems:

**1. Create fact file on target:**

```bash
# On target system: /etc/ansible/facts.d/custom.fact
#!/bin/bash
echo '{
  "app_version": "1.2.3",
  "deployment_env": "production",
  "region": "us-west-2"
}'
```

**2. Make it executable:**

```bash
chmod +x /etc/ansible/facts.d/custom.fact
```

**3. Access in playbook:**

```yaml
- name: Show custom facts
  debug:
    msg: "App version: {{ ansible_local.custom.app_version }}"
```

### Setting Facts During Playbook Execution

```yaml
- name: Set custom fact
  set_fact:
    my_custom_var: "value"
    calculated_value: "{{ ansible_memtotal_mb / 1024 }}"

- name: Use custom fact
  debug:
    msg: "Custom value: {{ my_custom_var }}"

- name: Set fact based on command output
  shell: cat /etc/custom-version
  register: version_output

- set_fact:
    app_version: "{{ version_output.stdout }}"
```

## Fact Caching

### Why Cache Facts?

- Speeds up subsequent playbook runs
- Reduces load on target systems
- Useful for large inventories

### Configuration

```ini
# ansible.cfg
[defaults]
gathering = smart              # Only gather if not cached or expired
fact_caching = jsonfile       # or 'redis', 'memcached'
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 7200   # 2 hours in seconds
```

### Cache Types

```ini
# JSON file cache (simple, local)
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts

# Redis cache (shared, fast)
fact_caching = redis
fact_caching_connection = localhost:6379:0

# Memcached cache (shared, fast)
fact_caching = memcached
fact_caching_connection = localhost:11211
```

### Clearing Cache

```bash
# Remove JSON cache
rm -rf /tmp/ansible_facts/*

# Or clear cache for specific host
rm /tmp/ansible_facts/hostname
```

## Real-World Examples

### Example 1: Kernel Headers Installation (Our Use Case)

```yaml
# ansible/roles/beegfs-client/tasks/install.yml

- name: Update apt cache and kernel headers to match running kernel
  ansible.builtin.apt:
    name: "linux-headers-{{ ansible_kernel }}"  # ← Uses ansible_kernel fact
    state: present
    update_cache: true
```

**What happens:**

1. Ansible connects to target host
2. Runs `setup` module (automatically)
3. Collects `ansible_kernel` by running `uname -r`
4. Substitutes value: `linux-headers-6.12.38+deb13-cloud-amd64`
5. Installs the exact kernel headers matching the running kernel

### Example 2: Cross-Platform Package Installation

```yaml
- name: Install package manager specific to OS
  package:
    name: "{{ package_name }}"
    state: present
  vars:
    package_name: >-
      {% if ansible_os_family == "Debian" %}
      nginx
      {% elif ansible_os_family == "RedHat" %}
      nginx
      {% elif ansible_os_family == "Archlinux" %}
      nginx
      {% endif %}
```

### Example 3: Memory-Based Configuration

```yaml
- name: Configure application based on available memory
  template:
    src: app-config.j2
    dest: /etc/app/config.yml
  vars:
    # Allocate 70% of available memory
    max_heap_mb: "{{ (ansible_memtotal_mb * 0.7) | int }}"
    worker_count: "{{ ansible_processor_vcpus }}"
```

### Example 4: Network Configuration

```yaml
- name: Configure firewall for primary interface
  ufw:
    rule: allow
    interface: "{{ ansible_default_ipv4.interface }}"
    direction: in
    proto: tcp
    port: 22

- name: Display network info
  debug:
    msg:
      - "Primary IP: {{ ansible_default_ipv4.address }}"
      - "Gateway: {{ ansible_default_ipv4.gateway }}"
      - "Interface: {{ ansible_default_ipv4.interface }}"
```

## Troubleshooting Facts

### Problem: Fact Not Available

```yaml
# Bad: Assumes fact exists
- name: This might fail
  debug:
    msg: "{{ ansible_some_fact }}"

# Good: Check if defined
- name: This is safe
  debug:
    msg: "{{ ansible_some_fact | default('NOT DEFINED') }}"

# Better: Assert fact exists
- name: Validate fact exists
  assert:
    that:
      - ansible_kernel is defined
      - ansible_kernel != ""
    fail_msg: "ansible_kernel fact not available!"
```

### Problem: Stale Facts

```bash
# Clear cache and regather
rm -rf /tmp/ansible_facts/*
ansible-playbook playbook.yml
```

### Problem: Slow Fact Gathering

```yaml
# Gather only subset of facts
- name: My Play
  hosts: all
  gather_facts: true
  gather_subset:
    - '!all'           # Exclude all
    - '!any'           # Exclude any
    - network          # Include only network facts
    - virtual          # Include only virtual facts
```

### Problem: Need Custom Fact

```yaml
# Gather custom information
- name: Get custom kernel info
  shell: uname -a
  register: kernel_info
  changed_when: false

- set_fact:
    full_kernel_info: "{{ kernel_info.stdout }}"
```

## Complete Fact List Command

```bash
# Get ALL available facts for your system
ansible localhost -m setup | less

# Or for remote host
ansible hpc-compute01 -i inventory -m setup | less

# Save to file
ansible all -i inventory -m setup --tree /tmp/facts/
# Creates: /tmp/facts/hostname with all facts
```

## Reference Links

- [Ansible Facts Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_vars_facts.html)
- [Setup Module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/setup_module.html)
- [Fact Caching](https://docs.ansible.com/ansible/latest/plugins/cache.html)
- [Custom Facts](https://docs.ansible.com/ansible/latest/user_guide/playbooks_vars_facts.html#facts-d-or-local-facts)

---

## Summary: ansible_kernel

```text
Variable:     ansible_kernel
Source:       Ansible setup module (automatic)
Command:      uname -r
Example:      6.12.38+deb13-cloud-amd64
When Set:     During fact gathering (start of play)
Where Used:   Anywhere in playbook after gathering
Cache:        Yes (if enabled in ansible.cfg)
Inspect:      ansible hostname -m setup -a "filter=ansible_kernel"
```

**Related:** ansible.cfg, beegfs-client role, kernel header installation
