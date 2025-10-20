# Monitoring Stack Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role deploys a comprehensive monitoring infrastructure for HPC clusters using
Prometheus for metrics collection, Grafana for visualization, and specialized exporters for
system and GPU monitoring.

## Purpose

The monitoring stack role provides:

- **Prometheus**: Time-series database for metrics collection and storage
- **Grafana**: Visualization and dashboard creation platform
- **Node Exporter**: Host system metrics (CPU, memory, disk, network)
- **DCGM**: NVIDIA GPU metrics and health monitoring
- **Alerting**: Alert rules and notification channels
- **Data Persistence**: Persistent storage for metrics

## Monitoring Components

### Prometheus

Central metrics collection and storage system.

- Time-series database for metric storage
- Scrape configuration for target systems
- Alert rule evaluation engine
- Web UI for query and exploration

### Grafana

Visualization and dashboard platform.

- Interactive dashboards for system monitoring
- Pre-built dashboard templates
- Alert management and notification
- User authentication and access control

### Node Exporter

Host-level system metrics.

- CPU utilization and load
- Memory and swap usage
- Disk usage and I/O metrics
- Network interface statistics
- Process-level monitoring

### DCGM (NVIDIA DCGM)

GPU metrics and health monitoring.

- GPU utilization and temperature
- GPU memory usage
- Power consumption
- Health diagnostics and alerts

## Variables

### Prometheus Configuration

- `prometheus_retention_days`: Metrics retention (default: 15)
- `prometheus_retention_size`: Max storage size (default: 50GB)
- `prometheus_port`: Prometheus port (default: 9090)
- `prometheus_scrape_interval`: Scrape interval (default: 15s)
- `prometheus_evaluation_interval`: Evaluation interval (default: 15s)

### Grafana Configuration

- `grafana_port`: Grafana port (default: 3000)
- `grafana_admin_password`: Admin password (default: admin)
- `grafana_users_allow_sign_up`: Allow user registration (default: false)
- `grafana_domain`: Grafana domain/hostname
- `grafana_root_url`: Grafana root URL

### Node Exporter

- `node_exporter_port`: Node exporter port (default: 9100)
- `node_exporter_collectors`: Enabled collectors (default: all)

### DCGM Configuration

- `dcgm_enabled`: Enable DCGM (default: true)
- `dcgm_port`: DCGM port (default: 5555)
- `dcgm_interval`: Metrics interval (default: 30s)

### Storage Configuration

- `monitoring_storage_path`: Data storage directory (default: /var/lib/monitoring)
- `prometheus_data_dir`: Prometheus data (default: /var/lib/prometheus)
- `grafana_data_dir`: Grafana data (default: /var/lib/grafana)

## Usage

### Basic Monitoring Stack

```yaml
- hosts: monitoring_servers
  become: true
  roles:
    - monitoring-stack
```

Deploys Prometheus, Grafana, and Node Exporter on the monitoring server.

### With GPU Monitoring

```yaml
- hosts: monitoring_servers
  become: true
  roles:
    - monitoring-stack
  vars:
    dcgm_enabled: true
```

Includes DCGM for GPU health monitoring.

### Custom Configuration

```yaml
- hosts: monitoring_servers
  become: true
  roles:
    - monitoring-stack
  vars:
    prometheus_retention_days: 30
    prometheus_retention_size: "100GB"
    grafana_port: 3000
    grafana_admin_password: "{{ vault_grafana_password }}"
```

### Distributed Monitoring

For large clusters, deploy monitoring components across multiple nodes:

```yaml
# Node 1: Prometheus and alerting
- hosts: prometheus_server
  become: true
  roles:
    - monitoring-stack

# Node 2: Grafana and visualization
- hosts: grafana_server
  become: true
  roles:
    - monitoring-stack
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- Docker or systemd for service management
- Sufficient disk space (varies by retention policy)
- Network access from all monitored nodes

### Optional Dependencies

- NVIDIA DCGM (for GPU monitoring)
- Alertmanager (for advanced alerting)

## What This Role Does

1. **Installs Prometheus**: Downloads and configures Prometheus
2. **Installs Grafana**: Sets up Grafana with web interface
3. **Installs Node Exporter**: Configures system metrics collection
4. **Installs DCGM**: Sets up GPU monitoring (if enabled)
5. **Configures Scrape Jobs**: Sets up targets for metrics collection
6. **Creates Dashboards**: Deploys pre-configured Grafana dashboards
7. **Configures Alerting**: Sets up alert rules and notification
8. **Enables Services**: Configures systemd for auto-start
9. **Sets Up Storage**: Creates directories for metric persistence

## Services and Ports

| Service | Port | Purpose |
|---------|------|---------|
| Prometheus | 9090 | Metrics API and web UI |
| Grafana | 3000 | Dashboard and visualization |
| Node Exporter | 9100 | Host system metrics |
| DCGM | 5555 | GPU metrics (if enabled) |
| Alertmanager | 9093 | Alert notifications (if enabled) |

## Configuration Files

After deployment, configuration files are typically at:

- `/etc/prometheus/prometheus.yml` - Prometheus configuration
- `/etc/grafana/grafana.ini` - Grafana configuration
- `/etc/default/node-exporter` - Node exporter settings

## Tags

Available Ansible tags:

- `monitoring_stack`: All monitoring components
- `prometheus`: Prometheus installation only
- `grafana`: Grafana installation only
- `node_exporter`: Node exporter only
- `dcgm`: DCGM GPU monitoring
- `monitoring_dashboards`: Dashboard configuration
- `monitoring_alerts`: Alert rule configuration

### Using Tags

```bash
# Deploy only Prometheus
ansible-playbook playbook.yml --tags prometheus

# Skip GPU monitoring
ansible-playbook playbook.yml --skip-tags dcgm
```

## Example Playbook

```yaml
---
- name: Deploy Monitoring Stack
  hosts: monitoring_servers
  become: yes
  roles:
    - monitoring-stack
  vars:
    prometheus_retention_days: 30
    grafana_admin_password: "{{ vault_grafana_admin_password }}"
    dcgm_enabled: true
    grafana_domain: "grafana.hpc.local"
```

## Service Management

```bash
# Check Prometheus status
systemctl status prometheus

# Check Grafana status
systemctl status grafana-server

# Check Node Exporter status
systemctl status node-exporter

# View Prometheus logs
journalctl -u prometheus -f

# View Grafana logs
journalctl -u grafana-server -f
```

## Accessing the Interface

### Prometheus

Access Prometheus web UI at: `http://monitoring-server:9090`

Key pages:

- `/graph` - Query and graph metrics
- `/targets` - Check monitored targets
- `/alerts` - View active alerts
- `/config` - View current configuration

### Grafana

Access Grafana at: `http://monitoring-server:3000`

- Default credentials: admin / admin (or configured password)
- Configure data source to Prometheus
- Create/import dashboards
- Set up alert notifications

## Adding Monitored Targets

### Configure Prometheus to Scrape Node Exporter

Edit `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'hpc_nodes'
    static_configs:
      - targets:
        - '10.0.2.11:9100'  # Compute node 1
        - '10.0.2.12:9100'  # Compute node 2
        - '10.0.2.13:9100'  # Compute node 3
```

Reload Prometheus:

```bash
systemctl reload prometheus
```

### Add GPU Nodes to DCGM Monitoring

Configure DCGM to monitor specific GPU nodes similar to Node Exporter setup.

## Common Monitoring Queries

### Prometheus Queries

```promql
# CPU Usage
100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))

# Memory Usage Percentage
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Disk Usage Percentage
100 * (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes)

# Network Traffic (bytes/sec)
rate(node_network_transmit_bytes_total[5m])

# GPU Utilization (if DCGM enabled)
DCGM_FI_DEV_GPU_UTIL
```

## Troubleshooting

### Prometheus Won't Start

1. Check configuration syntax: `promtool check config /etc/prometheus/prometheus.yml`
2. Verify disk space: `df -h`
3. Check logs: `journalctl -u prometheus -xe`
4. Verify ports not in use: `netstat -tulpn | grep 9090`

### Grafana Connection Issues

1. Verify Grafana service: `systemctl status grafana-server`
2. Check firewall rules for port 3000
3. Review Grafana logs: `journalctl -u grafana-server -xe`
4. Verify data source configuration in Grafana UI

### Missing Metrics

1. Check target status in Prometheus UI (`/targets`)
2. Verify node exporter running on target: `systemctl status node-exporter`
3. Check firewall rules for port 9100
4. Test network connectivity: `telnet target-ip 9100`

### High Disk Usage

1. Check Prometheus data directory: `du -sh /var/lib/prometheus`
2. Reduce retention: Set `prometheus_retention_days` to lower value
3. Increase cleanup frequency
4. Delete old metrics manually if necessary

## Performance Tuning

### For Large Clusters

```yaml
prometheus_scrape_interval: "30s"    # Increase interval for large clusters
prometheus_evaluation_interval: "30s"
prometheus_retention_days: 7          # Reduce retention to save space
```

### For High-Resolution Monitoring

```yaml
prometheus_scrape_interval: "5s"     # More frequent scraping
prometheus_retention_days: 30         # Longer retention
prometheus_retention_size: "200GB"   # Larger storage allocation
```

## Backup and Recovery

### Backup Prometheus Data

```bash
# Stop Prometheus
systemctl stop prometheus

# Backup data directory
tar -czf prometheus-backup.tar.gz /var/lib/prometheus

# Restart Prometheus
systemctl start prometheus
```

### Backup Grafana

```bash
# Export dashboards
# Use Grafana API or web UI export feature

# Backup database
sqlite3 /var/lib/grafana/grafana.db ".dump" > grafana-backup.sql
```

## Integration with Other Roles

This role integrates with:

- **slurm-controller/slurm-compute**: Monitor SLURM metrics
- **nvidia-gpu-drivers**: GPU monitoring via DCGM
- **beegfs-mgmt**: Storage metrics
- **container-registry**: Container infrastructure monitoring

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../../docs/architecture/](../../docs/architecture/)** - HPC architecture
- **[Prometheus Documentation](https://prometheus.io/docs/)** - Prometheus guide
- **[Grafana Documentation](https://grafana.com/docs/)** - Grafana guide
- **[NVIDIA DCGM](https://developer.nvidia.com/dcgm)** - DCGM documentation
