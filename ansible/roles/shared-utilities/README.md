# Shared Utilities Role

**Status:** ✅ Complete (Phase 4.8 Consolidation)
**Last Updated:** 2025-11-18

This role provides reusable validation tasks, health checks, and service management patterns used across
multiple Ansible roles. It eliminates duplicate code for common operations like service validation, port
checking, logging setup, and connectivity testing.

## Purpose

The shared-utilities role consolidates common patterns that are repeated across multiple roles:

- **Service Health Checks**: Validate systemd services are running and healthy
- **Port Availability**: Check if ports are listening and accessible
- **Logging Setup**: Configure log directories and log rotation
- **Connectivity Testing**: Verify network connectivity to hosts and services

## Variables

### Service Validation

| Variable | Default | Description |
|----------|---------|-------------|
| `service_name` | **required** | systemd service name (e.g., "slurmctld") |
| `service_port` | - | TCP/UDP port to check (optional) |
| `service_check_command` | - | Command to run for health check (optional) |
| `service_validation_timeout` | 30 | Timeout in seconds for service checks |

### Port Checking

| Variable | Default | Description |
|----------|---------|-------------|
| `port` or `ports` | **required** | Single port or list of ports to check |
| `port_check_timeout` | 30 | Timeout in seconds |
| `port_check_delay` | 2 | Delay between checks in seconds |
| `port_protocol` | tcp | Protocol to check (tcp or udp) |

### Logging Setup

| Variable | Default | Description |
|----------|---------|-------------|
| `log_directory` | **required** | Path to log directory |
| `log_owner` | root | Log directory owner |
| `log_group` | root | Log directory group |
| `log_mode` | 0755 | Log directory permissions |
| `log_rotation_enabled` | true | Enable log rotation |
| `log_retention_days` | 30 | Days to retain logs |
| `log_max_size` | 100M | Maximum log file size |

### Connectivity Testing

| Variable | Default | Description |
|----------|---------|-------------|
| `connectivity_host` or `connectivity_hosts` | **required** | Single host or list of hosts to test |
| `connectivity_port` | 22 | Port to test (default: SSH) |
| `connectivity_protocol` | tcp | Protocol to use (tcp or udp) |
| `connectivity_test_timeout` | 10 | Timeout in seconds |

## Usage

### Service Health Check

```yaml
- name: Validate SLURM controller service
  import_role:
    name: shared-utilities
    tasks_from: validate-service
  vars:
    service_name: "slurmctld"
    service_port: 6817
    service_check_command: "slurmctld -V"
```

### Port Availability Check

```yaml
- name: Check required ports
  import_role:
    name: shared-utilities
    tasks_from: check-ports
  vars:
    ports:
      - 6817  # SLURM controller
      - 6818  # SLURM database
      - 9090  # Prometheus
```

### Logging Setup

```yaml
- name: Setup logging for service
  import_role:
    name: shared-utilities
    tasks_from: setup-logging
  vars:
    log_directory: "/var/log/my-service"
    log_owner: "myuser"
    log_group: "mygroup"
    log_rotation_enabled: true
    log_retention_days: 30
```

### Connectivity Testing

```yaml
- name: Verify network connectivity
  import_role:
    name: shared-utilities
    tasks_from: verify-connectivity
  vars:
    connectivity_hosts:
      - "controller"
      - "compute01"
      - "compute02"
    connectivity_port: 22
```

## Task Modules

### validate-service

Validates that a systemd service is running and optionally checks port availability and runs health checks.

**Required:**

- `service_name`: Service name to validate

**Optional:**

- `service_port`: Port to check
- `service_check_command`: Health check command
- `service_validation_timeout`: Timeout in seconds

### check-ports

Checks if one or more ports are available and listening.

**Required:**

- `port` or `ports`: Port(s) to check

**Optional:**

- `port_check_timeout`: Timeout in seconds
- `port_check_delay`: Delay between checks
- `port_protocol`: Protocol (tcp or udp)

### setup-logging

Creates log directories and configures log rotation.

**Required:**

- `log_directory`: Path to log directory

**Optional:**

- `log_owner`, `log_group`, `log_mode`: Directory ownership and permissions
- `log_rotation_enabled`: Enable/disable log rotation
- `log_retention_days`, `log_max_size`: Rotation settings

### verify-connectivity

Tests network connectivity to one or more hosts.

**Required:**

- `connectivity_host` or `connectivity_hosts`: Host(s) to test

**Optional:**

- `connectivity_port`: Port to test (default: 22)
- `connectivity_protocol`: Protocol (tcp or udp)
- `connectivity_test_timeout`: Timeout in seconds

## Example: Complete Service Validation

```yaml
- name: Validate BeeGFS management service
  import_role:
    name: shared-utilities
    tasks_from: validate-service
  vars:
    service_name: "beegfs-mgmtd"
    service_port: 8008
    service_check_command: "beegfs-ctl --listnodes --nodetype=all"

- name: Setup BeeGFS logging
  import_role:
    name: shared-utilities
    tasks_from: setup-logging
  vars:
    log_directory: "/var/log/beegfs"
    log_owner: "beegfs"
    log_group: "beegfs"
```

## Benefits

- ✅ **Eliminates Duplication**: Common validation patterns in one place
- ✅ **Consistent Behavior**: Same validation logic across all roles
- ✅ **Easier Maintenance**: Fix bugs and add features in one location
- ✅ **Standardized Output**: Consistent debug messages and error handling
- ✅ **Reusable**: Import only the tasks you need

## Integration with Other Roles

This role is designed to be imported by other roles:

- **slurm-controller**: Service validation, port checking
- **slurm-compute**: Service validation, connectivity testing
- **beegfs-mgmt**: Service validation, logging setup
- **monitoring-stack**: Port checking, service validation
- **container-registry**: Port checking, connectivity testing

## Related Roles

- `package-manager` - Pre-built package installation logic
- `slurm-common` - SLURM common functionality
- `beegfs-common` - BeeGFS common functionality
- `base-packages` - Base package installation
