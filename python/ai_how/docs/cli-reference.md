# AI-HOW CLI Reference

**Status:** Production  
**Version:** 0.1.0  
**Last Updated:** 2025-10-21

Complete reference for all AI-HOW CLI commands, options, and subcommands.

> **Note**: For core concepts and terminology, see [Common Concepts](common-concepts.md).

## Table of Contents

1. [Global Options](#global-options)
2. [Commands Overview](#commands-overview)
3. [Validate Command](#validate-command)
4. [HPC Command](#hpc-command)
5. [Cloud Command](#cloud-command)
6. [Plan Command](#plan-command)
7. [Inventory Command](#inventory-command)
8. [Environment Variables](#environment-variables)
9. [Exit Codes](#exit-codes)
10. [Examples](#examples)

## Global Options

These options are available for all commands and must be placed before the subcommand.

### `--state PATH`

State file location for cluster tracking. See [Common Concepts - State
Management](common-concepts.md#state-management) for detailed information.

**Default:** `output/state.json`  
**Type:** Path string  
**Required:** No

**Usage:**

```bash
ai-how --state /var/lib/ai-how/state.json validate config.yaml
ai-how --state ./custom-state.json hpc start config.yaml
```text

**Notes:**

- Parent directory will be created if it doesn't exist
- State file persists cluster metadata between CLI invocations
- Stores cluster configuration, VM information, and resource mappings

### `--log-level LEVEL`

Set logging verbosity level.

**Default:** `INFO`
**Accepted Values:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
**Type:** String
**Required:** No

**Usage:**

```bash
ai-how --log-level DEBUG validate config.yaml
ai-how --log-level ERROR hpc status
```text

**Level Descriptions:**

- `DEBUG`: Detailed diagnostic information, including subprocess calls and internal state changes
- `INFO`: General informational messages about major operations
- `WARNING`: Warning messages about potential issues or deprecated features
- `ERROR`: Error messages for failed operations
- `CRITICAL`: Critical failures that may prevent execution

### `--log-file PATH`

Write logs to a file in addition to console output.

**Default:** None (console only)
**Type:** Path string
**Required:** No

**Usage:**

```bash
ai-how --log-file /var/log/ai-how/operations.log hpc start config.yaml
ai-how --log-level DEBUG --log-file debug.log validate config.yaml
```text

**Notes:**

- Log file location will be created if directory doesn't exist
- Logs are appended to existing files
- Console output continues even with `--log-file` specified
- Use with `--log-level DEBUG` for comprehensive debugging

### `--verbose, -v`

Enable debug output and detailed error information.

**Type:** Flag (boolean)
**Default:** False
**Required:** No

**Usage:**

```bash
ai-how --verbose validate config.yaml
ai-how -v hpc status
ai-how --verbose --log-level DEBUG hpc start config.yaml
```text

**Notes:**

- Shorter alternative: `-v`
- Activates maximum debug output
- Useful for troubleshooting failures
- Can be combined with `--log-level DEBUG` for maximum detail

## Commands Overview

AI-HOW provides several main command groups:

| Command | Purpose | Status |
|---------|---------|--------|
| `validate` | Validate cluster configuration | ✅ Implemented |
| `hpc` | HPC cluster lifecycle management | ✅ Implemented |
| `cloud` | Cloud cluster lifecycle management | ⏳ Not implemented |
| `plan` | Planning and visualization utilities | ✅ Partial |
| `inventory` | Host device inventory and status | ✅ Partial |

## Validate Command

Validates cluster configuration against the JSON Schema and performs system readiness checks.

### Syntax

```bash
ai-how validate <config_file> [OPTIONS]
```text

### Arguments

#### `config_file` (Required)

Path to cluster configuration YAML file.

**Type:** Path (must exist)
**Format:** YAML
**Extension:** `.yaml` or `.yml`

**Usage:**

```bash
ai-how validate config/cluster.yaml
ai-how validate ./my-cluster-config.yaml
ai-how validate /etc/ai-how/production.yaml
```text

### Options

#### `--skip-pcie-validation`

Skip PCIe passthrough device validation.

**Type:** Flag (boolean)
**Default:** False (validation enabled)

**Usage:**

```bash
ai-how validate config.yaml --skip-pcie-validation
ai-how --log-level INFO validate config.yaml --skip-pcie-validation
```text

**Use Cases:**

- Validate configuration structure without checking device availability
- Speed up validation when PCIe devices not yet configured
- Separate configuration validation from system readiness checks

### Validation Steps

The `validate` command performs the following checks:

1. **YAML Parsing**
   - Parses YAML syntax
   - Checks for malformed configuration

2. **JSON Schema Validation**
   - Validates against cluster.schema.json (Draft-7)
   - Checks required fields
   - Validates field types and formats
   - Verifies enum values

3. **PCIe Passthrough Validation** (unless `--skip-pcie-validation`)
   - Configuration validation: PCI address formats, device types
   - System validation: VFIO modules, IOMMU, KVM support
   - Device validation: Device existence, driver binding, IOMMU groups

For detailed PCIe passthrough information, see [Common Concepts - PCIe Passthrough](common-concepts.md#pcie-passthrough).

### Output

**Success:**

```text
✅ Schema validation passed
✅ PCIe passthrough configuration valid
✅ System supports PCIe passthrough
```text

**Failure (Schema):**

```text
❌ Validation failed
Error: Additional properties are not allowed ('invalid_field' was unexpected)
  in config.yaml at path clusters.hpc[0].network.invalid_field

Remediation: Check cluster.schema.json for allowed fields
```text

**Failure (PCIe):**

```text
❌ PCIe validation failed
Error: VFIO module not loaded: vfio_iommu_type1

Remediation: Load VFIO module with: sudo modprobe vfio_iommu_type1
```text

### Exit Codes

- `0`: Validation successful
- `1`: Validation failed (schema or system checks)
- `2`: File not found or permission denied

### Examples

**Basic validation:**

```bash
ai-how validate config/cluster.yaml
```text

**Validation with detailed logging:**

```bash
ai-how --log-level DEBUG validate config/cluster.yaml
```text

**Validate without PCIe checks:**

```bash
ai-how validate config/cluster.yaml --skip-pcie-validation
```text

**Validate and save logs:**

```bash
ai-how --log-file validation.log validate config/cluster.yaml
```text

---

## HPC Command

Manage HPC cluster lifecycle (start, stop, status, destroy).

### Syntax

```bash
ai-how hpc <subcommand> <config_file> [OPTIONS]
```text

### Subcommands

### `hpc start`

Start an HPC cluster from configuration.

**Syntax:**

```bash
ai-how hpc start <config_file> [OPTIONS]
```text

**Arguments:**

- `config_file` (Required): Cluster configuration YAML file

**Options:**

- None (uses global options)

**Workflow:**

1. Validates configuration (runs `validate` command)
2. Creates storage pools
3. Creates cluster network
4. Creates VM volumes from base images
5. Generates libvirt domain XML
6. Defines and starts controller VM
7. Defines and starts compute node VMs
8. Tracks all resources in state file

**Output:**

```text
Starting HPC cluster 'my-cluster'...
  ✓ Validating configuration
  ✓ Creating storage pool
  ✓ Creating cluster network (192.168.100.0/24)
  ✓ Creating volumes for controller
  ✓ Creating volumes for compute-01
  ✓ Defining controller VM
  ✓ Starting controller VM
  ✓ Defining compute-01 VM
  ✓ Starting compute-01 VM
  ✓ Cluster started successfully

State saved to: output/state.json
```text

**Example:**

```bash
ai-how hpc start config/my-cluster.yaml
ai-how --verbose hpc start config/my-cluster.yaml
ai-how --log-level DEBUG hpc start config/my-cluster.yaml
```text

**Rollback on Failure:**

- If startup fails, HPC manager attempts rollback
- Resources are cleaned up in reverse order
- State file may contain partial cluster info for recovery

### `hpc stop`

Stop an HPC cluster gracefully.

**Syntax:**

```bash
ai-how hpc stop <config_file> [OPTIONS]
```text

**Arguments:**

- `config_file` (Required): Cluster configuration YAML file

**Options:**

- None (uses global options)

**Workflow:**

1. Loads cluster state from state file
2. Gracefully shuts down each VM
3. Waits for VMs to stop (timeout: 60s)
4. Force-stops any VMs that don't respond
5. Keeps volumes and pools intact
6. Updates state file

**Output:**

```text
Stopping HPC cluster 'my-cluster'...
  ✓ Stopping compute-01 VM
  ✓ Stopping controller VM
  ✓ All VMs stopped

State saved to: output/state.json
```text

**Example:**

```bash
ai-how hpc stop config/my-cluster.yaml
ai-how --log-level INFO hpc stop config/my-cluster.yaml
```text

**Notes:**

- Graceful shutdown waits for VM shutdown completion
- VMs are not destroyed, volumes are preserved
- Use `hpc destroy` to clean up all resources

### `hpc status`

Display HPC cluster status and information.

**Syntax:**

```bash
ai-how hpc status [OPTIONS]
```text

**Arguments:**

- None

**Options:**

- None (uses global options)

**Output (Table Format):**

```text
┌─ HPC Cluster Status ────────────────────────────────────────┐
│ Cluster: my-cluster (HPC)                                   │
│ Status: RUNNING                                             │
│ Created: 2025-10-21 14:32:15                               │
│ Modified: 2025-10-21 14:35:42                              │
└─────────────────────────────────────────────────────────────┘

┌─ VMs ──────────────────────────────────────────────────────┐
│ Name          │ State    │ CPU │ Memory │ IP Address       │
├───────────────┼──────────┼─────┼────────┼──────────────────┤
│ my-controller │ RUNNING  │ 8   │ 32 GB  │ 192.168.100.10   │
│ compute-01    │ RUNNING  │ 16  │ 64 GB  │ 192.168.100.20   │
│ compute-02    │ RUNNING  │ 16  │ 64 GB  │ 192.168.100.21   │
└─────────────────────────────────────────────────────────────┘

┌─ Volumes ──────────────────────────────────────────────────┐
│ VM            │ Volume Path                                 │
├───────────────┼──────────────────────────────────────────────┤
│ my-controller │ /var/lib/libvirt/images/.../controller.img │
│ compute-01    │ /var/lib/libvirt/images/.../compute-01.img │
│ compute-02    │ /var/lib/libvirt/images/.../compute-02.img │
└─────────────────────────────────────────────────────────────┘

┌─ Networks ─────────────────────────────────────────────────┐
│ Name                    │ Subnet         │ Active IPs      │
├─────────────────────────┼────────────────┼─────────────────┤
│ my-cluster-network      │ 192.168.100/24 │ 3               │
└─────────────────────────────────────────────────────────────┘
```text

**Example:**

```bash
ai-how hpc status
ai-how --verbose hpc status
```text

**Exit Codes:**

- `0`: Status retrieved successfully
- `1`: State file not found or cluster not running

### `hpc destroy`

Destroy HPC cluster and clean up all resources.

**Syntax:**

```bash
ai-how hpc destroy <config_file> [OPTIONS]
```text

**Arguments:**

- `config_file` (Required): Cluster configuration YAML file

**Options:**

#### `--force, -f`

Skip confirmation prompt and destroy immediately.

**Type:** Flag (boolean)
**Default:** False (confirmation required)

**Usage:**

```bash
ai-how hpc destroy config/my-cluster.yaml --force
ai-how hpc destroy config/my-cluster.yaml -f
```text

**Workflow:**

1. Prompts for confirmation (unless `--force` specified)
2. Stops all VMs
3. Destroys all VM definitions
4. Removes all volumes
5. Destroys network
6. Destroys storage pool
7. Clears state file

**Output (with confirmation):**

```text
Preparing to destroy HPC cluster 'my-cluster'
This will remove:
  - 3 VMs (controller, compute-01, compute-02)
  - 3 volumes (~1.5 TB)
  - 1 network
  - 1 storage pool

Are you sure? (y/N): y

Destroying cluster...
  ✓ Stopped all VMs
  ✓ Destroyed VM definitions
  ✓ Removed volumes
  ✓ Removed network
  ✓ Removed storage pool
  ✓ Cluster destroyed

State cleared.
```text

**Example:**

```bash
ai-how hpc destroy config/my-cluster.yaml
ai-how hpc destroy config/my-cluster.yaml --force
ai-how --verbose hpc destroy config/my-cluster.yaml -f
```text

**Safety:**

- Confirmation required by default
- `--force` flag bypasses confirmation
- All resources are removed, action is not reversible
- State file is cleared after successful destruction

---

## Cloud Command

Cloud cluster lifecycle management (Kubernetes/cloud infrastructure).

### Status: Not Implemented

Cloud cluster commands are placeholders for future implementation.

### Available Subcommands

- `cloud start` - Not implemented
- `cloud stop` - Not implemented
- `cloud status` - Not implemented
- `cloud destroy` - Not implemented

### Future Implementation

When implemented, cloud commands will provide similar lifecycle management as HPC commands but for Kubernetes clusters.

---

## Plan Command

Planning and visualization utilities for cluster configuration.

### Syntax

```bash
ai-how plan <subcommand> [OPTIONS]
```text

### Subcommands

### `plan show`

Show cluster planning information.

**Status:** Not implemented

### `plan clusters`

Display planned clusters from configuration file.

**Syntax:**

```bash
ai-how plan clusters <config_file> [OPTIONS]
```text

**Arguments:**

- `config_file` (Required): Cluster configuration YAML file

**Options:**

#### `--format FORMAT`

Output format for cluster information.

**Accepted Values:** `text`, `json`, `markdown`
**Default:** `text`
**Type:** String

**Usage:**

```bash
ai-how plan clusters config.yaml --format text
ai-how plan clusters config.yaml --format json
ai-how plan clusters config.yaml --format markdown
```text

#### `--output FILE`

Write output to file instead of stdout.

**Type:** Path string
**Default:** None (output to stdout)

**Usage:**

```bash
ai-how plan clusters config.yaml --output plan.txt
ai-how plan clusters config.yaml --format json --output plan.json
```text

**Output (text format):**

```text
Planned Clusters from: config/my-cluster.yaml

HPC Clusters:
  - my-cluster
    Location: HPC Cluster Configuration

    VMs:
      - my-controller (Controller)
        CPUs: 8
        Memory: 32 GB
        Networking: 192.168.100.10

      - compute-01 (Compute)
        CPUs: 16
        Memory: 64 GB
        Networking: 192.168.100.20
        GPUs: 2x NVIDIA A100

      - compute-02 (Compute)
        CPUs: 16
        Memory: 64 GB
        Networking: 192.168.100.21
        GPUs: 2x NVIDIA A100

    Network Configuration:
      Subnet: 192.168.100.0/24
      Bridge: virbr100
      DHCP: Enabled (192.168.100.100-192.168.100.254)

    Storage:
      Pool Location: /var/lib/libvirt/images/my-cluster
      Total Size: 1500 GB

Cloud Clusters:
  (None configured)
```text

**Output (JSON format):**

```json
{
  "hpc_clusters": [
    {
      "name": "my-cluster",
      "vms": [
        {
          "name": "my-controller",
          "cpu_cores": 8,
          "memory_gb": 32,
          "ip_address": "192.168.100.10",
          "gpu_count": 0
        },
        {
          "name": "compute-01",
          "cpu_cores": 16,
          "memory_gb": 64,
          "ip_address": "192.168.100.20",
          "gpu_count": 2
        }
      ],
      "network": {
        "subnet": "192.168.100.0/24",
        "bridge": "virbr100"
      },
      "storage": {
        "pool_path": "/var/lib/libvirt/images/my-cluster",
        "total_gb": 1500
      }
    }
  ],
  "cloud_clusters": []
}
```text

**Output (markdown format):**

```markdown
# Planned Clusters

## HPC Clusters

### my-cluster

| VM | CPUs | Memory | Network | GPUs |
|----|------|--------|---------|------|
| my-controller | 8 | 32 GB | 192.168.100.10 | 0 |
| compute-01 | 16 | 64 GB | 192.168.100.20 | 2 |
| compute-02 | 16 | 64 GB | 192.168.100.21 | 2 |

**Network:** 192.168.100.0/24 (bridge: virbr100)

**Storage:** /var/lib/libvirt/images/my-cluster (1500 GB)

## Cloud Clusters

(None configured)
```text

**Example:**

```bash
ai-how plan clusters config/my-cluster.yaml
ai-how plan clusters config/my-cluster.yaml --format json
ai-how plan clusters config/my-cluster.yaml --format markdown --output plan.md
```text

---

## Inventory Command

Host device inventory and status reporting.

### Syntax

```bash
ai-how inventory <subcommand> [OPTIONS]
```text

### Subcommands

### `inventory gpu`

GPU device inventory and status.

**Status:** Not implemented

### `inventory pcie`

PCIe device inventory with driver and VFIO status.

**Syntax:**

```bash
ai-how inventory pcie [OPTIONS]
```text

**Arguments:**

- None

**Options:**

- None (uses global options)

**Output:**

```text
PCIe Device Inventory
==================================================

┌─ Graphics ─────────────────────────────────────────────┐
│ PCI Address  │ Name           │ Driver    │ VFIO │ Grp │
├──────────────┼────────────────┼───────────┼──────┼─────┤
│ 0000:01:00.0 │ NVIDIA A100    │ vfio-pci  │ Yes  │ 12  │
│ 0000:02:00.0 │ NVIDIA A100    │ vfio-pci  │ Yes  │ 13  │
│ 0000:0e:00.0 │ NVIDIA RTX6000 │ nvidia    │ No   │ 31  │
└────────────────────────────────────────────────────────┘

Possible conflicts:
  - 0000:0e:00.0: nvidia driver (use for visualization, not passthrough)

┌─ Audio ────────────────────────────────────────────────┐
│ PCI Address  │ Name           │ Driver    │ VFIO │ Grp │
├──────────────┼────────────────┼───────────┼──────┼─────┤
│ 0000:0d:00.0 │ Intel Audio    │ snd_hda   │ No   │ 30  │
└────────────────────────────────────────────────────────┘

Recommendations:
  - To use 0000:01:00.0 for passthrough: already bound to vfio-pci ✓
  - To use 0000:02:00.0 for passthrough: already bound to vfio-pci ✓
  - To use 0000:0e:00.0 for passthrough: rebind with: sudo vfio-bind 0000:0e:00.0

┌─ Network ──────────────────────────────────────────────┐
│ PCI Address  │ Name           │ Driver    │ VFIO │ Grp │
├──────────────┼────────────────┼───────────┼──────┼─────┤
│ 0000:05:00.0 │ Mellanox ConnX │ mlx5_core │ No   │ 9   │
│ 0000:06:00.0 │ Broadcom Nic   │ bnx2x     │ No   │ 10  │
└────────────────────────────────────────────────────────┘

System Summary:
  Total PCIe Devices: 15
  VFIO-capable Devices: 2
  Ready for Passthrough: 2
  Potentially Conflicting: 1
```text

**Color Legend:**

- 🟢 Green: VFIO bound (ready for passthrough)
- 🟡 Yellow: Bound to native driver (manual rebinding needed)
- 🔴 Red: Potential conflicts detected

**Example:**

```bash
ai-how inventory pcie
ai-how --verbose inventory pcie
ai-how --log-level DEBUG inventory pcie
```text

---

## Environment Variables

### `AI_HOW_STATE_FILE`

Override default state file location.

**Type:** Path string
**Default:** `output/state.json`

**Usage:**

```bash
export AI_HOW_STATE_FILE=/var/lib/ai-how/state.json
ai-how hpc start config.yaml
```text

**Notes:**

- Command-line `--state` option takes precedence over environment variable
- Useful for scripting and automation

### `AI_HOW_LOG_LEVEL`

Override default logging level.

**Type:** String (DEBUG|INFO|WARNING|ERROR|CRITICAL)
**Default:** `INFO`

**Usage:**

```bash
export AI_HOW_LOG_LEVEL=DEBUG
ai-how validate config.yaml
```text

**Notes:**

- Command-line `--log-level` option takes precedence
- Useful for development and debugging workflows

### `LIBVIRT_URI`

libvirt connection URI for custom daemon socket.

**Type:** String (URI format)
**Default:** `qemu:///system`

**Usage:**

```bash
export LIBVIRT_URI=qemu+ssh://remote-host/system
ai-how hpc start config.yaml
```text

**Common Values:**

- `qemu:///system` - Local system daemon (default)
- `qemu:///session` - Local user session
- `qemu+ssh://host/system` - Remote SSH connection
- `qemu+tcp://host:16509/system` - Remote TCP connection

### `KVM_QEMU_BINARY`

Override QEMU binary path.

**Type:** Path string
**Default:** Auto-detected (`/usr/bin/qemu-system-x86_64`)

**Usage:**

```bash
export KVM_QEMU_BINARY=/opt/qemu/bin/qemu-system-x86_64
ai-how hpc start config.yaml
```text

---

## Exit Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 0 | Success | Command completed successfully |
| 1 | General failure | Configuration error, validation failure, operation failed |
| 2 | File not found | Config file doesn't exist, state file missing |
| 3 | Permission denied | Insufficient privileges, can't write state file |
| 4 | Invalid argument | Bad command-line argument, invalid format |
| 5 | System error | libvirt error, filesystem error, VFIO error |

### Interpreting Exit Codes in Scripts

```bash
#!/bin/bash

ai-how validate config.yaml
case $? in
    0)
        echo "Validation successful"
        ;;
    1)
        echo "Validation failed - check configuration"
        exit 1
        ;;
    2)
        echo "Configuration file not found"
        exit 1
        ;;
    *)
        echo "Unexpected error"
        exit 1
        ;;
esac
```text

---

## Examples

### Complete Workflow: Start, Check, Stop Cluster

```bash
# Validate configuration
ai-how validate config/my-cluster.yaml

# Start HPC cluster
ai-how hpc start config/my-cluster.yaml

# Check cluster status
ai-how hpc status

# Stop cluster when done
ai-how hpc stop config/my-cluster.yaml
```text

### Planning Before Deployment

```bash
# View planned clusters in text format
ai-how plan clusters config/my-cluster.yaml

# Export plan to JSON for automation
ai-how plan clusters config/my-cluster.yaml --format json --output plan.json

# Generate markdown documentation
ai-how plan clusters config/my-cluster.yaml --format markdown --output DEPLOYMENT_PLAN.md
```text

### Inventory and Device Management

```bash
# Check available PCIe devices
ai-how inventory pcie

# Validate configuration includes available GPUs
ai-how validate config/my-cluster.yaml

# Check PCIe with verbose output
ai-how --verbose inventory pcie
```text

### Debugging and Troubleshooting

```bash
# Run with maximum debug output
ai-how --log-level DEBUG --verbose hpc start config/my-cluster.yaml

# Save debug logs to file
ai-how --log-level DEBUG --log-file debug.log hpc start config/my-cluster.yaml

# Use custom state file for testing
ai-how --state ./test-state.json hpc start config/test-cluster.yaml
```text

### Production Scripting

```bash
#!/bin/bash
set -e

# Configuration
CONFIG_FILE="config/production-cluster.yaml"
STATE_FILE="/var/lib/ai-how/production-state.json"

# Validate
ai-how --state "$STATE_FILE" validate "$CONFIG_FILE"

# Start cluster
ai-how --state "$STATE_FILE" hpc start "$CONFIG_FILE"

# Wait for cluster ready
sleep 30

# Check status
ai-how --state "$STATE_FILE" hpc status

echo "Production cluster ready"
```text

### Automation with Remote State

```bash
#!/bin/bash

# Store state on network filesystem
export AI_HOW_STATE_FILE=/mnt/shared/ai-how/state.json
export LIBVIRT_URI=qemu:///system

# Start cluster with network state tracking
ai-how hpc start config/shared-cluster.yaml

# Later, from different session:
ai-how hpc status  # Shows state from network location
```text

---

## See Also

- [Schema Guide](schema-guide.md) - Configuration schema reference
- [State Management](state-management.md) - Cluster state internals
- [API Documentation](api/ai_how.md) - Internal API reference
