# AI-HOW State Management

**Status:** Production  
**Version:** 0.1.0  
**Last Updated:** 2025-10-21

Comprehensive guide to cluster state management, persistence, and recovery.

> **Note**: For core concepts and terminology, see [Common Concepts](common-concepts.md).

## Table of Contents

1. [State Architecture](#state-architecture)
2. [State File Format](#state-file-format)
3. [State Lifecycle](#state-lifecycle)
4. [State Models](#state-models)
5. [VM State Transitions](#vm-state-transitions)
6. [State Persistence](#state-persistence)
7. [State Recovery](#state-recovery)
8. [Troubleshooting](#troubleshooting)

## State Architecture

AI-HOW maintains cluster state to track resources and enable reliable operations across multiple CLI invocations.

### Architecture Overview

```text
┌─────────────────────────────────────────────┐
│         ClusterStateManager                 │
│  (High-level state interface)               │
└──────────────┬──────────────────────────────┘
               │
       ┌───────┴──────────┐
       │                  │
       v                  v
┌─────────────┐    ┌──────────────────┐
│  In-Memory  │    │  StateFileManager│
│   State     │    │  (Persistence)   │
│             │    │                  │
│ ClusterState│    │ JSON File I/O    │
│  - VMs      │    │ Backup/Recovery  │
│  - Networks │    │                  │
│  - Volumes  │    │ state.json       │
└─────────────┘    └──────────────────┘
       ^                  ^
       │                  │
       └──────────────────┘
              JSON
           Serialization
```text

### State Flow During Operations

```text
User Command
    │
    v
Load ClusterStateManager
    │
    v
├─ Read state.json (if exists)
│   └─ Deserialize to ClusterState
│
└─ In-Memory ClusterState
    │
    v
Perform Operation
  (start/stop/destroy)
    │
    v
Update ClusterState
  - Add/remove VMs
  - Update VM states
  - Record timestamps
    │
    v
Save state.json
  - Serialize to JSON
  - Backup previous
  - Write atomically
    │
    v
Operation Complete
```text

---

## State File Format

State is persisted in JSON format for language-neutral compatibility and human readability.

For basic state management information, see [Common Concepts - State Management](common-concepts.md#state-management).

### File Location

**Default:** `output/state.json`  
**Override:** `--state /path/to/state.json`

**Permissions:** User read/write (mode 0600)

### JSON Structure

```json
{
  "cluster_name": "my-cluster",
  "cluster_type": "hpc",
  "status": "running",
  "created_at": "2025-10-21T14:32:15.123456",
  "last_modified": "2025-10-21T14:35:42.654321",
  "vms": [
    {
      "name": "controller",
      "cpu_cores": 8,
      "memory_gb": 32,
      "state": "RUNNING",
      "ip_address": "192.168.100.10",
      "gpu_count": 0,
      "volumes": [
        "/var/lib/libvirt/images/my-cluster/controller.qcow2"
      ],
      "created_at": "2025-10-21T14:32:15.123456",
      "last_seen": "2025-10-21T14:35:40.123456"
    },
    {
      "name": "compute-01",
      "cpu_cores": 16,
      "memory_gb": 64,
      "state": "RUNNING",
      "ip_address": "192.168.100.20",
      "gpu_count": 2,
      "volumes": [
        "/var/lib/libvirt/images/my-cluster/compute-01.qcow2"
      ],
      "created_at": "2025-10-21T14:32:30.123456",
      "last_seen": "2025-10-21T14:35:38.123456"
    }
  ],
  "networks": [
    {
      "name": "my-cluster-network",
      "subnet": "192.168.100.0/24",
      "bridge": "virbr100",
      "active_ips": [
        "192.168.100.10",
        "192.168.100.20",
        "192.168.100.21"
      ]
    }
  ],
  "volumes": [
    {
      "name": "controller-disk",
      "path": "/var/lib/libvirt/images/my-cluster/controller.qcow2",
      "size_gb": 100,
      "format": "qcow2"
    },
    {
      "name": "compute-01-disk",
      "path": "/var/lib/libvirt/images/my-cluster/compute-01.qcow2",
      "size_gb": 500,
      "format": "qcow2"
    }
  ]
}
```text

### Field Descriptions

#### Root Level

| Field | Type | Description |
|-------|------|-------------|
| `cluster_name` | string | Cluster identifier |
| `cluster_type` | string | "hpc" or "cloud" |
| `status` | string | "running", "stopped", "error", "partial" |
| `created_at` | ISO 8601 | Cluster creation time |
| `last_modified` | ISO 8601 | Last state update |

#### VM Objects

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | VM name |
| `cpu_cores` | integer | CPU count |
| `memory_gb` | integer | Memory allocation |
| `state` | string | VM state (RUNNING, PAUSED, SHUTOFF, etc.) |
| `ip_address` | string \| null | Assigned IP address |
| `gpu_count` | integer | GPU devices assigned |
| `volumes` | array[string] | Volume file paths |
| `created_at` | ISO 8601 | VM creation time |
| `last_seen` | ISO 8601 | Last state check time |

#### Network Objects

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Network name |
| `subnet` | string | Network subnet (CIDR) |
| `bridge` | string | Bridge device name |
| `active_ips` | array[string] | Currently allocated IPs |

#### Volume Objects

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Volume identifier |
| `path` | string | Filesystem path |
| `size_gb` | integer | Allocated size |
| `format` | string | Image format (qcow2) |

---

## State Lifecycle

### State Creation

State is created when:

1. **First cluster start:**

   ```bash
   ai-how hpc start config/cluster.yaml
```text

   - Creates new state file
   - Initializes all resources
   - Saves initial state

2. **Programmatic initialization:**

   ```python
   from ai_how.state import ClusterStateManager

   mgr = ClusterStateManager("state.json")
   state = mgr.ensure_state("my-cluster", "hpc")
```text

### State Updates

State is updated during operations:

- **Start:** Add VMs, networks, volumes
- **Stop:** Update VM states (SHUTOFF)
- **Status:** Update last_seen timestamps
- **Destroy:** Remove resources

### State Recovery

State persists across:

- CLI invocations
- System restarts (if libvirt state synced)
- Network disconnections

### State Cleanup

State is cleared when:

- Cluster destroyed with `hpc destroy --force`
- Manual deletion of state file
- State recovery fails

---

## State Models

### VMState Enum

Represents VM execution states from libvirt. See [Common Concepts - VM States](common-concepts.md#vm-states) for state descriptions.

**Values:**

```python
class VMState(Enum):
    RUNNING = 1        # VM is running
    PAUSED = 2         # VM is paused
    SHUTOFF = 3        # VM is shut off
    UNDEFINED = 4      # VM undefined
    CRASHED = 5        # VM has crashed
    DYING = 6          # VM is shutting down
    PMSUSPENDED = 7    # Power-managed suspended
```text

**Mapping from libvirt:**

```text
libvirt VIR_DOMAIN_* constants → VMState
VIR_DOMAIN_RUNNING      → RUNNING
VIR_DOMAIN_BLOCKED      → RUNNING (treated as running)
VIR_DOMAIN_PAUSED       → PAUSED
VIR_DOMAIN_SHUTDOWN     → DYING
VIR_DOMAIN_SHUTOFF      → SHUTOFF
VIR_DOMAIN_CRASHED      → CRASHED
VIR_DOMAIN_PMSUSPENDED  → PMSUSPENDED
VIR_DOMAIN_NOSTATE      → UNDEFINED
```text

**Usage:**

```python
from ai_how.state import VMState

if vm.state == VMState.RUNNING:
    print("VM is running")

# Check multiple states
if vm.state in (VMState.RUNNING, VMState.PAUSED):
    print("VM is active")
```text

### VMInfo Model

Complete VM information snapshot.

**Attributes:**

```python
@dataclass
class VMInfo:
    name: str                        # VM identifier
    cpu_cores: int                   # CPU count
    memory_gb: int                   # Memory allocation
    state: VMState                   # Current state
    ip_address: str | None = None   # Assigned IP
    gpu_count: int = 0              # GPU devices
    volumes: list[str] = field(default_factory=list)  # Volume paths
    created_at: datetime = field(default_factory=datetime.now)
    last_seen: datetime = field(default_factory=datetime.now)
```text

**Serialization:**

- Converts to/from JSON
- ISO 8601 datetime format
- Type-safe validation

**Example:**

```python
from ai_how.state import VMInfo, VMState
from datetime import datetime

vm = VMInfo(
    name="compute-01",
    cpu_cores=16,
    memory_gb=64,
    state=VMState.RUNNING,
    ip_address="192.168.100.20",
    gpu_count=2,
    volumes=["/var/lib/libvirt/images/cluster/compute-01.qcow2"]
)

print(f"{vm.name}: {vm.state} ({vm.ip_address})")
```text

### ClusterState Model

Complete cluster state snapshot.

**Attributes:**

```python
@dataclass
class ClusterState:
    cluster_name: str                 # Cluster ID
    cluster_type: str                 # "hpc" or "cloud"
    status: str                       # "running", "stopped", "error"
    vms: list[VMInfo] = field(default_factory=list)
    networks: list[dict] = field(default_factory=list)
    volumes: list[dict] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
    last_modified: datetime = field(default_factory=datetime.now)
```text

**Methods:**

- JSON serialization
- Validation
- History tracking

---

## VM State Transitions

### Valid State Transitions

```text
UNDEFINED
    │
    ├─(define)─→ RUNNING
    │
    └─(define)─→ PAUSED
                 │
                 ├─(resume)─→ RUNNING
                 │
                 └─(resume)─→ DYING

RUNNING
    ├─(pause)─→ PAUSED
    │
    ├─(shutdown)─→ DYING
    │
    ├─(reboot)─→ RUNNING
    │
    └─(crash)─→ CRASHED

PAUSED
    ├─(resume)─→ RUNNING
    │
    └─(shutdown)─→ DYING

DYING
    ├─(timeout)─→ SHUTOFF
    │
    └─(force stop)─→ SHUTOFF

SHUTOFF
    ├─(start)─→ RUNNING
    │
    └─(destroy)─→ UNDEFINED

CRASHED
    ├─(recovery)─→ RUNNING
    │
    └─(destroy)─→ UNDEFINED

PMSUSPENDED
    └─(resume)─→ RUNNING
```text

### State Transitions in Operations

**Start Operation:**

```text
UNDEFINED → (define) → RUNNING
                        │
                        └─→ Update state
```text

**Stop Operation:**

```text
RUNNING → (shutdown 60s) → SHUTOFF
                            │
                            └─→ Update state
          └→ (force stop) ↓
            SHUTOFF ← RUNNING
```text

**Destroy Operation:**

```text
RUNNING → (stop) → SHUTOFF → (destroy) → UNDEFINED
                              │
                              └─→ Remove from state
```text

---

## State Persistence

### Loading State

**Programmatically:**

```python
from ai_how.state import ClusterStateManager

mgr = ClusterStateManager("state.json")

# Load existing state
state = mgr.get_state()
if state:
    print(f"Cluster: {state.cluster_name}")
else:
    print("No state file")

# Or ensure state exists
state = mgr.ensure_state("my-cluster", "hpc")
```text

**From CLI:**

- State automatically loaded on each command
- Uses default or `--state` specified location
- Creates if doesn't exist

### Saving State

**Programmatically:**

```python
from datetime import datetime

state.last_modified = datetime.now()
mgr.save_state(state)
```text

**From CLI:**

- Automatically saved after operations
- Atomic write (write to temp, then rename)
- Backup of previous state retained

### State Backup

**Automatic Backup:**

- Previous state backed up before write
- Backup location: `state.json.backup`
- Useful for recovery

**Manual Backup:**

```python
mgr.backup("state.json.backup")
```text

### Atomic Operations

State writes are atomic:

```text
1. Write to state.json.tmp
2. Verify write successful
3. Rename state.json.tmp → state.json
4. Backup previous state.json
```text

Ensures consistency even if crash occurs during write.

---

## State Recovery

### Recovery Scenarios

#### Scenario 1: State File Corrupted

**Problem:** `state.json` is invalid JSON

**Recovery:**

```bash
# Restore from backup
cp state.json.backup state.json

# Verify state
ai-how hpc status

# Resync with libvirt
ai-how validate config.yaml
```text

#### Scenario 2: State File Missing

**Problem:** `state.json` deleted or lost

**Recovery:**

```bash
# Create new state from configuration
ai-how hpc status
# Will create minimal state from cluster detection

# Or explicitly recreate
ai-how --state ./state.json hpc start config.yaml
```text

#### Scenario 3: State Out of Sync

**Problem:** libvirt state differs from state.json

**Recovery:**

```bash
# Update state from actual cluster
ai-how hpc status
# Refreshes state from libvirt

# If IPs changed
ai-how hpc stop config.yaml
ai-how hpc start config.yaml
# Rebuilds state completely
```text

### Recovery Procedure

**Step 1: Check Current State**

```bash
ai-how hpc status
```text

**Step 2: Verify Backup**

```bash
ls -la state.json*
# Check modification times
```text

**Step 3: Restore if Needed**

```bash
# From backup
cp state.json.backup state.json

# Verify
ai-how hpc status
```text

**Step 4: Resync with libvirt**

```bash
# If still inconsistent
ai-how validate config.yaml
ai-how hpc stop config.yaml
ai-how hpc destroy config.yaml --force
ai-how hpc start config.yaml
```text

---

## State Management Operations

### Reading State

**Get all VMs:**

```python
vms = mgr.get_all_vms()
for vm in vms:
    print(f"{vm.name}: {vm.state}")
```text

**Get specific VM:**

```python
vm = mgr.get_vm("compute-01")
if vm:
    print(f"IP: {vm.ip_address}")
```text

**Get cluster state:**

```python
state = mgr.get_state()
print(f"Status: {state.status}")
print(f"VMs: {len(state.vms)}")
```text

### Updating State

**Add VM:**

```python
from ai_how.state import VMInfo, VMState

vm = VMInfo(
    name="compute-01",
    cpu_cores=16,
    memory_gb=64,
    state=VMState.RUNNING,
    ip_address="192.168.100.20",
    gpu_count=2
)
mgr.add_vm(vm)
```text

**Update VM State:**

```python
from ai_how.state import VMState

mgr.update_vm_state("compute-01", VMState.PAUSED)
```text

**Remove VM:**

```python
mgr.remove_vm("compute-01")
```text

**Save Changes:**

```python
mgr.save_state(state)
```text

### Querying State

**Check if cluster running:**

```python
state = mgr.get_state()
if state and state.status == "running":
    print("Cluster is running")
```text

**Count VMs:**

```python
running_vms = sum(
    1 for vm in state.vms
    if vm.state == VMState.RUNNING
)
print(f"Running VMs: {running_vms}")
```text

**Find VM by IP:**

```python
target_ip = "192.168.100.20"
vm = next(
    (vm for vm in state.vms if vm.ip_address == target_ip),
    None
)
if vm:
    print(f"Found VM: {vm.name}")
```text

---

## Troubleshooting

### Problem: State File Permission Denied

**Symptoms:**

```text
Error: Permission denied writing to state.json
```text

**Solution:**

```bash
# Check ownership
ls -la state.json

# Fix permissions
chmod 600 state.json

# Or change directory
mkdir -p ~/.ai-how
ai-how --state ~/.ai-how/state.json hpc status
```text

### Problem: State File Grows Large

**Symptoms:**

- state.json becomes very large (>10MB)
- Slow state operations

**Solution:**

```bash
# Check state file size
ls -lh state.json

# Backup current state
cp state.json state.json.archive

# Create new state
ai-how hpc destroy config.yaml --force
ai-how hpc start config.yaml
# New state is fresh and smaller
```text

### Problem: State Out of Sync with libvirt

**Symptoms:**

```bash
ai-how hpc status shows different IPs than actual VMs
VM listed in state but doesn't exist in libvirt
```text

**Solution:**

```bash
# Option 1: Refresh state only
ai-how hpc status  # Reads from libvirt and updates state

# Option 2: Rebuild cluster from scratch
ai-how hpc destroy config.yaml --force
rm state.json
ai-how hpc start config.yaml
```text

### Problem: State File Corrupted

**Symptoms:**

```text
Error: JSON decode error in state.json
Invalid state data structure
```text

**Solution:**

```bash
# Restore from backup
cp state.json.backup state.json

# Verify it works
ai-how hpc status

# If backup also corrupted
rm state.json state.json.backup
ai-how hpc start config.yaml  # Creates fresh state
```text

### Problem: State File Location Hard to Find

**Solution:**

```bash
# Check current state location
env | grep AI_HOW

# Set environment variable
export AI_HOW_STATE_FILE=/var/lib/ai-how/state.json
ai-how hpc status

# Or always specify with --state
alias ai-how='ai-how --state /var/lib/ai-how/state.json'
ai-how hpc status
```text

### Problem: Multiple Clusters Using Same State File

**Symptoms:**

```text
Cluster name mismatch
VMs from different clusters mixed in state
```text

**Solution:**

```bash
# Use separate state files per cluster
ai-how --state cluster1-state.json hpc start config/cluster1.yaml
ai-how --state cluster2-state.json hpc start config/cluster2.yaml

# Check status
ai-how --state cluster1-state.json hpc status
ai-how --state cluster2-state.json hpc status
```text

---

## Best Practices

### State Management Best Practices

1. **Backup State Regularly**

   ```bash
   cp state.json state.json.$(date +%s)
```text

2. **Use Consistent State Location**

   ```bash
   export AI_HOW_STATE_FILE=/var/lib/ai-how/state.json
```text

3. **Monitor State File Size**

   ```bash
   watch -n 60 'ls -lh state.json'
```text

4. **Archive Old States**

   ```bash
   # Keep last 10 states
   ls -t state.json.* | tail -n +11 | xargs rm
```text

5. **Verify State on Recovery**

   ```bash
   ai-how hpc status
   ai-how --verbose hpc status
```text

### Scripting with State

**Robust Cluster Management:**

```bash
#!/bin/bash

STATE_FILE="/var/lib/ai-how/state.json"

# Check if cluster exists
if [ -f "$STATE_FILE" ]; then
    echo "Cluster already exists"
    ai-how --state "$STATE_FILE" hpc status
else
    echo "Creating new cluster"
    ai-how --state "$STATE_FILE" hpc start config.yaml
fi

# Backup state
cp "$STATE_FILE" "$STATE_FILE.backup"

# Do operations
...

# Restore if needed
# cp "$STATE_FILE.backup" "$STATE_FILE"
```text

---

## See Also

- [CLI Reference](cli-reference.md) - Command-line usage
- [Schema Guide](schema-guide.md) - Configuration format
- [API Documentation](api/ai_how.md) - Python API reference
