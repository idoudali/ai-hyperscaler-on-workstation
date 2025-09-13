# Network Configuration for HPC Clusters

This document explains how to properly configure network settings for HPC clusters using the ai-how library.

## Overview

The ai-how library provides comprehensive network management for HPC clusters, including:

- Virtual network creation with proper DHCP and DNS configuration
- Default gateway setup for internet connectivity
- Static IP allocation for VMs
- Network validation and troubleshooting

## Network Configuration

### Basic Configuration

```python
network_config = {
    "subnet": "192.168.100.0/24",
    "bridge": "br-hpc-cluster"
}
```

### Advanced Configuration

```python
network_config = {
    "subnet": "192.168.100.0/24",
    "bridge": "br-hpc-cluster",
    "gateway_ip": "192.168.100.1",
    "dhcp_start": "192.168.100.10",
    "dhcp_end": "192.168.100.254",
    "dns_servers": ["192.168.100.1", "8.8.8.8", "1.1.1.1"],
    "dns_mode": "isolated"
}
```

### Static IP Configuration

```python
network_config = {
    "subnet": "192.168.100.0/24",
    "bridge": "br-hpc-cluster",
    "gateway_ip": "192.168.100.1",
    "dhcp_start": "192.168.100.10",
    "dhcp_end": "192.168.100.254",
    "dns_servers": ["192.168.100.1", "8.8.8.8", "1.1.1.1"],
    "dns_mode": "isolated",
    "static_leases": {
        "hpc-cluster-controller": "192.168.100.2",
        "hpc-cluster-compute-01": "192.168.100.10",
        "hpc-cluster-compute-02": "192.168.100.11"
    },
    "vm_macs": {
        "hpc-cluster-controller": "52:54:00:12:34:01",
        "hpc-cluster-compute-01": "52:54:00:12:34:02",
        "hpc-cluster-compute-02": "52:54:00:12:34:03"
    }
}
```

## Configuration Fields

### Required Fields

- **`subnet`**: Network subnet in CIDR notation (e.g., '192.168.100.0/24')
- **`bridge`**: Bridge name for the virtual network (e.g., 'br-hpc-cluster')

### Optional Fields

- **`gateway_ip`**: Gateway IP address (defaults to first IP in subnet)
- **`dhcp_start`**: DHCP range start IP (defaults to subnet + 10)
- **`dhcp_end`**: DHCP range end IP (defaults to subnet + 254)
- **`dns_servers`**: List of DNS servers (defaults to gateway + public DNS)
- **`dns_mode`**: DNS mode: 'isolated', 'shared_dns', 'routed', 'service_discovery'

## DNS Modes

### Isolated Mode (Default)

- Uses gateway IP and public DNS servers
- Provides internet access through NAT
- Isolated from other clusters

### Shared DNS Mode

- Uses host system DNS for cross-cluster resolution
- Requires root privileges for configuration
- Enables communication between clusters

### Routed Mode

- Enables routing between cluster networks
- Requires IP forwarding configuration
- Advanced networking setup

### Service Discovery Mode

- Integrates with external service discovery (e.g., Consul)
- Requires service discovery configuration
- Enterprise-level networking

## Troubleshooting

### Common Issues

#### VMs Cannot Access Internet

**Problem**: VMs get IP addresses but cannot reach the internet.

**Solutions**:

1. Ensure `dns_mode` is set to 'isolated' or 'shared_dns'
2. Check that `dns_servers` includes the gateway IP and public DNS
3. Verify that the network template includes NAT forwarding
4. Check firewall rules on the host system

#### VMs Do Not Get IP Addresses

**Problem**: VMs start but do not receive IP addresses from DHCP.

**Solutions**:

1. Check that `dhcp_start` and `dhcp_end` are within the subnet range
2. Verify that the network is active and running
3. Check dnsmasq service status
4. Verify VM network interface configuration

#### DNS Resolution Issues

**Problem**: VMs can reach IP addresses but cannot resolve domain names.

**Solutions**:

1. Verify `dns_servers` configuration includes working DNS servers
2. Check that the gateway IP is included in DNS servers
3. Test DNS resolution manually: `nslookup google.com`
4. Check dnsmasq configuration and logs

### Diagnostic Commands

```bash
# Check libvirt networks
virsh net-list --all

# Check network status
virsh net-info <network-name>

# Check DHCP leases
virsh net-dhcp-leases <network-name>

# Check dnsmasq status
systemctl status dnsmasq

# Check network connectivity from VM
ping 8.8.8.8
nslookup google.com
```

### Using the Troubleshooting Script

```bash
# Run full diagnostics
python python/ai_how/examples/network_troubleshooting.py

# Check specific components
python python/ai_how/examples/network_troubleshooting.py networks
python python/ai_how/examples/network_troubleshooting.py dnsmasq
python python/ai_how/examples/network_troubleshooting.py network <network-name>
python python/ai_how/examples/network_troubleshooting.py vm <vm-name>
```

## Examples

### Basic Cluster Setup

```python
from ai_how.vm_management.hpc_manager import HPCClusterManager

# Basic cluster configuration
config = {
    "clusters": {
        "hpc": {
            "name": "hpc-cluster",
            "base_image_path": "/path/to/base-image.qcow2",
            "network": {
                "subnet": "192.168.100.0/24",
                "bridge": "br-hpc-cluster"
            },
            "controller": {
                "cpu_cores": 4,
                "memory_gb": 8,
                "disk_gb": 50
            },
            "compute_nodes": [
                {
                    "cpu_cores": 8,
                    "memory_gb": 16,
                    "disk_gb": 100
                }
            ]
        }
    }
}

# Create and start cluster
manager = HPCClusterManager(config, Path("cluster_state.json"))
manager.start_cluster()
```

### Advanced Cluster with Static IPs

```python
# Advanced cluster configuration with static IPs
config = {
    "clusters": {
        "hpc": {
            "name": "hpc-cluster",
            "base_image_path": "/path/to/base-image.qcow2",
            "network": {
                "subnet": "192.168.100.0/24",
                "bridge": "br-hpc-cluster",
                "gateway_ip": "192.168.100.1",
                "dhcp_start": "192.168.100.10",
                "dhcp_end": "192.168.100.254",
                "dns_servers": ["192.168.100.1", "8.8.8.8", "1.1.1.1"],
                "dns_mode": "isolated"
            },
            "controller": {
                "cpu_cores": 4,
                "memory_gb": 8,
                "disk_gb": 50,
                "ip_address": "192.168.100.2"
            },
            "compute_nodes": [
                {
                    "cpu_cores": 8,
                    "memory_gb": 16,
                    "disk_gb": 100,
                    "ip": "192.168.100.10"
                }
            ]
        }
    }
}
```

## Best Practices

1. **Always specify a gateway IP** to ensure proper internet connectivity
2. **Use static IPs for critical VMs** like controllers and compute nodes
3. **Include multiple DNS servers** for redundancy
4. **Test network connectivity** after cluster creation
5. **Monitor network performance** and adjust configuration as needed
6. **Use descriptive bridge names** to avoid conflicts
7. **Document your network configuration** for future reference

## Security Considerations

1. **Isolate cluster networks** from production networks
2. **Use strong passwords** for VM access
3. **Configure firewall rules** appropriately
4. **Monitor network traffic** for anomalies
5. **Keep network software updated** regularly

## Performance Optimization

1. **Use virtio network interfaces** for better performance
2. **Configure CPU pinning** for network-intensive workloads
3. **Use SR-IOV** for high-performance networking
4. **Monitor network utilization** and adjust accordingly
5. **Consider network bonding** for redundancy and performance
