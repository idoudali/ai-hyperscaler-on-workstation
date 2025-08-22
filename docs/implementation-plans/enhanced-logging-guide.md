# Enhanced Logging Implementation Guide

## Overview

The ai-how CLI now includes comprehensive logging capabilities with configurable
log levels, subprocess debugging, and detailed operation tracking. This enhancement
provides visibility into all cluster management operations for troubleshooting and
monitoring.

## New Logging Features

### 1. **Configurable Log Levels**

The CLI now supports multiple logging levels with command-line options:

```bash
# Basic usage with default INFO logging
ai-how hpc start

# Enable debug logging with verbose flag
ai-how --verbose hpc start
ai-how -v hpc start

# Set specific log level
ai-how --log-level DEBUG hpc start
ai-how --log-level WARNING hpc start

# Save logs to file
ai-how --log-file /var/log/ai-how.log hpc start

# Debug mode with automatic log file
ai-how --verbose hpc start  # Creates output/ai-how.log automatically
```

### 2. **Subprocess Command Logging**

All subprocess calls (qemu-img, libvirt operations) are logged with:

- Full command execution details
- Execution time tracking
- stdout/stderr capture
- Return code monitoring

Example debug output:

```text
2024-01-15 10:30:15 - ai_how.vm_management.disk_manager - DEBUG - 
Executing subprocess command: qemu-img create -f qcow2 -b 
/var/lib/libvirt/images/base.qcow2 -F qcow2 
/var/lib/libvirt/images/hpc-compute-01.qcow2
2024-01-15 10:30:15 - ai_how.vm_management.disk_manager - DEBUG - 
Working directory: None
2024-01-15 10:30:15 - ai_how.vm_management.disk_manager - DEBUG - 
Command completed in 0.23s with exit code 0
```

### 3. **Function Entry/Exit Tracking**

Debug mode tracks function calls with parameters and results:

```text
2024-01-15 10:30:15 - ai_how.vm_management.hpc_manager - DEBUG - 
Entering start_cluster()
2024-01-15 10:30:16 - ai_how.vm_management.hpc_manager - DEBUG - 
Exiting start_cluster with result: True
```

### 4. **Operation Progress Logging**

Major operations include start/success logging:

```text
2024-01-15 10:30:15 - ai_how.vm_management.hpc_manager - INFO - 
Starting HPC cluster startup (cluster_name=hpc-cluster)
2024-01-15 10:30:45 - ai_how.vm_management.hpc_manager - INFO - 
Successfully completed HPC cluster startup (cluster_name=hpc-cluster, total_vms=4)
```

## CLI Logging Options

### Command Line Arguments

| Option | Description | Default |
|--------|-------------|---------|
| `--log-level LEVEL` | Set logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL) | INFO |
| `--log-file PATH` | Write logs to file | None |
| `--verbose, -v` | Enable verbose output (DEBUG level) | False |

### Log Level Behavior

- **DEBUG**: All debug information, function entry/exit, subprocess details
- **INFO**: Normal operation messages, start/completion of major operations
- **WARNING**: Non-fatal issues that should be noted
- **ERROR**: Error conditions that prevent operation completion
- **CRITICAL**: Severe errors that may cause program termination

### Automatic Log File Creation

When `--verbose` is used without `--log-file`, logs are automatically saved to:

```text
output/ai-how.log
```

## Enhanced Components

### 1. **Disk Manager Logging**

- qemu-img command execution details
- Disk creation, resize, and validation operations
- Base image information and validation
- Space availability checking

### 2. **LibVirt Client Logging**

- Connection establishment and management
- Domain listing and state checking
- XML definition processing
- Hypervisor information

### 3. **HPC Manager Logging**

- Cluster lifecycle operations (start/stop/destroy)
- Configuration validation steps
- VM creation and management progress
- State management operations

### 4. **Subprocess Wrapper Utility**

- Command execution with timing
- Output capture and logging
- Error handling and debugging
- Execution context tracking

## Usage Examples

### Basic Debugging Session

```bash
# Enable debug mode for cluster start
ai-how --verbose hpc start

# Check the generated log file
tail -f output/ai-how.log
```

### Production Monitoring

```bash
# Run with INFO level and log to file
ai-how --log-level INFO --log-file /var/log/ai-how.log hpc start
```

### Troubleshooting Failed Operations

```bash
# Enable maximum debugging
ai-how --log-level DEBUG --log-file debug.log hpc start

# If operation fails, check the debug log
grep -A 5 -B 5 "ERROR" debug.log
```

### Performance Analysis

```bash
# Run with debug to see execution times
ai-how --verbose hpc start

# Check subprocess execution times
grep "completed in" output/ai-how.log
```

## Log File Locations

### Default Behavior

- Console output: stderr with colored formatting
- No file logging unless specified

### With --verbose

- Console output: stderr with timestamps
- Automatic file: `output/ai-how.log`

### With --log-file

- Console output: stderr
- File output: specified path

## Colored Console Output

The logging system includes colored output for better readability:

- 🔵 **DEBUG**: Cyan
- 🟢 **INFO**: Green  
- 🟡 **WARNING**: Yellow
- 🔴 **ERROR**: Red
- 🟣 **CRITICAL**: Magenta

## Integration with Existing Tools

### With systemd

```bash
# Create service file with logging
ExecStart=/usr/local/bin/ai-how --log-file /var/log/ai-how.log hpc start
```

### With logrotate

```bash
# Add to /etc/logrotate.d/ai-how
/var/log/ai-how.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

### With monitoring tools

The structured logging output can be parsed by monitoring tools like:

- ELK Stack (Elasticsearch, Logstash, Kibana)
- Prometheus with log exporters
- Grafana Loki
- Standard syslog

## Performance Impact

### Debug Mode

- ~5-10% performance overhead due to detailed logging
- Increased disk I/O for log file writes
- Memory usage for log buffering

### INFO Mode

- Minimal performance impact (<1%)
- Suitable for production use

### Recommendations

- Use INFO level for production deployments
- Use DEBUG level for development and troubleshooting
- Use WARNING level for minimal logging in resource-constrained environments

## Troubleshooting

### Common Issues

1. **Log file permission errors**

   ```bash
   # Ensure directory exists and is writable
   mkdir -p $(dirname /var/log/ai-how.log)
   chmod 755 $(dirname /var/log/ai-how.log)
   ```

2. **Missing subprocess output**
   - Ensure DEBUG level is enabled
   - Check that commands are being executed with the subprocess wrapper

3. **Performance issues with debug logging**
   - Switch to INFO level for better performance
   - Use log file instead of console output

### Debug Information Sources

When troubleshooting, check these log sections:

1. **Configuration validation** - Shows config parsing issues
2. **Prerequisite checks** - Shows system requirement problems  
3. **Subprocess execution** - Shows command failures
4. **State management** - Shows file I/O issues
5. **libvirt operations** - Shows virtualization problems

## Future Enhancements

Planned logging improvements:

1. **Structured JSON logging** for machine parsing
2. **Log aggregation** to central logging systems
3. **Performance metrics** logging
4. **Audit trail** for compliance requirements
5. **Log filtering** by component or operation type
