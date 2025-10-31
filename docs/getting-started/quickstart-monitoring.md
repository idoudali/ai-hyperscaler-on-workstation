# Monitoring Quickstart

**Status:** Production  
**Last Updated:** 2025-10-31  
**Target Time:** 10 minutes  
**Prerequisites:** [Cluster Deployment Quickstart](quickstart-cluster.md) completed

## Overview

Set up monitoring and visualization for your HPC cluster in 10 minutes. This quickstart covers deploying Prometheus
for metrics collection, Grafana for visualization, and viewing real-time cluster metrics.

**What You'll Deploy:**

- Prometheus for time-series metrics collection
- Grafana dashboards for visualization
- Node Exporter for system metrics
- SLURM metrics collection
- GPU monitoring (if GPUs available)

**What You'll Monitor:**

- System resources (CPU, memory, disk, network)
- SLURM job metrics and queue status
- Node health and availability
- GPU utilization and temperature (if GPUs configured)

## Prerequisites Check

Before starting, ensure you have:

```bash
# Verify cluster is running
virsh list | grep running

# Check SLURM cluster operational
ssh admin@192.168.190.10 sinfo

# Verify controller is accessible
ping -c 2 192.168.190.10
```

## Step 1: Deploy Monitoring Stack (3-4 minutes)

Deploy monitoring using Ansible:

```bash
# Navigate to Ansible directory
cd ansible

# Deploy monitoring stack to controller
ansible-playbook -i inventories/hpc/hosts.yml playbooks/monitoring-stack.yml \
    --limit hpc-controller

# Or deploy to all nodes for comprehensive monitoring
ansible-playbook -i inventories/hpc/hosts.yml playbooks/monitoring-stack.yml
```

**Expected Output:**

```text
PLAY [Install monitoring stack] ************************************************

TASK [monitoring-stack : Install Prometheus packages] **************************
changed: [hpc-controller]

TASK [monitoring-stack : Install Grafana] **************************************
changed: [hpc-controller]

TASK [monitoring-stack : Configure Prometheus] *********************************
changed: [hpc-controller]

TASK [monitoring-stack : Start Prometheus] *************************************
ok: [hpc-controller]

TASK [monitoring-stack : Start Grafana] ****************************************
ok: [hpc-controller]

PLAY RECAP *********************************************************************
hpc-controller      : ok=12  changed=8  unreachable=0  failed=0  skipped=0
```

**Note:** Deployment includes:

- Prometheus server on controller (port 9090)
- Grafana on controller (port 3000)
- Node exporters on all nodes (port 9100)

## Step 2: Verify Services (30 seconds)

Check that monitoring services are running:

```bash
# SSH to controller
ssh admin@192.168.190.10

# Check Prometheus
systemctl status prometheus
curl -s http://localhost:9090/-/healthy

# Check Grafana
systemctl status grafana-server
curl -s http://localhost:3000/api/health

# Check Node Exporter
systemctl status prometheus-node-exporter
curl -s http://localhost:9100/metrics | head -20
```

**Expected Output:**

```text
● prometheus.service - Prometheus
     Active: active (running)

Prometheus is Healthy.

● grafana-server.service - Grafana
     Active: active (running)

{"commit":"abc123","database":"ok","version":"10.2.2"}

● prometheus-node-exporter.service - Prometheus Node Exporter
     Active: active (running)

# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
...
```

## Step 3: Access Prometheus UI (30 seconds)

Access Prometheus from your host machine:

```bash
# From your workstation, forward Prometheus port
ssh -L 9090:localhost:9090 admin@192.168.190.10 -N -f

# Or configure direct access if your network allows
# Open browser to: http://192.168.190.10:9090
```

**In your browser:**

1. Navigate to `http://localhost:9090`
2. Go to Status → Targets to see scrape targets
3. Try a query: `up` (shows which services are up)
4. Try another: `node_load1` (shows system load)

**Expected View:**

- All targets should show as "UP"
- Prometheus, node-exporter targets visible
- Graphs display when running queries

## Step 4: Access Grafana UI (1 minute)

Access Grafana and log in:

```bash
# Forward Grafana port
ssh -L 3000:localhost:3000 admin@192.168.190.10 -N -f

# Or direct access: http://192.168.190.10:3000
```

**In your browser:**

1. Navigate to `http://localhost:3000`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. Change password when prompted (recommended)

## Step 5: Configure Data Source (1 minute)

Connect Grafana to Prometheus:

**Via UI:**

1. Click **Configuration** (gear icon) → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure:
   - Name: `Prometheus`
   - URL: `http://localhost:9090`
5. Click **Save & Test**

**Expected:** "Data source is working" message

**Via API (alternative):**

```bash
# SSH to controller
ssh admin@192.168.190.10

# Add Prometheus data source
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'
```

## Step 6: Import System Dashboard (2 minutes)

Import a pre-built dashboard for system monitoring:

**Method 1: Import from Grafana.com**

1. Click **Dashboards** (four squares icon) → **Import**
2. Enter dashboard ID: `1860` (Node Exporter Full)
3. Click **Load**
4. Select **Prometheus** as data source
5. Click **Import**

**Method 2: Using API**

```bash
# Download dashboard JSON
curl -o node-exporter-dashboard.json \
  https://grafana.com/api/dashboards/1860/revisions/27/download

# Import via API
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @node-exporter-dashboard.json
```

**Expected:** Dashboard appears with system metrics, CPU, memory, disk, network graphs

## Step 7: View Cluster Metrics (1 minute)

Explore the dashboard to see your cluster metrics:

**Key Metrics to Check:**

1. **System Overview**
   - CPU usage (should be low at idle)
   - Memory utilization
   - Disk I/O
   - Network traffic

2. **Node Status**
   - Uptime
   - Load average
   - Process count

3. **Resource Trends**
   - Historical CPU usage
   - Memory patterns
   - Disk space changes

**Try Interactive Queries:**

In Prometheus UI (http://localhost:9090):

```promql
# CPU usage percentage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage percentage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Network traffic (bytes per second)
rate(node_network_receive_bytes_total[5m])
```

## Step 8: Monitor SLURM Jobs (Optional, 1 minute)

If SLURM exporter is configured, view job metrics:

```bash
# SSH to controller
ssh admin@192.168.190.10

# Check SLURM metrics endpoint (if exporter installed)
curl -s http://localhost:9341/metrics | grep slurm

# Example metrics:
# slurm_job_count{state="running"} 2
# slurm_job_count{state="pending"} 5
# slurm_node_count{state="idle"} 1
```

**In Grafana:** Create a simple SLURM panel

1. Create New Dashboard
2. Add Panel
3. Query: `slurm_job_count`
4. Visualization: Stat or Time series
5. Save dashboard

## ✅ Success!

You now have comprehensive monitoring with:

- ✅ Prometheus collecting metrics from all nodes
- ✅ Grafana visualizing system performance
- ✅ Real-time cluster resource monitoring
- ✅ Historical metric trends
- ✅ Custom dashboards for your workloads

## Next Steps

### Create Custom Dashboards

Build dashboards for your specific workflows:

```bash
# Example: GPU monitoring dashboard (if GPUs configured)
# 1. Install DCGM exporter
ssh admin@192.168.190.131
sudo apt install datacenter-gpu-manager dcgm-exporter

# 2. Start DCGM exporter
sudo systemctl start dcgm-exporter

# 3. Add to Prometheus scrape config
# Edit /etc/prometheus/prometheus.yml:
#   - job_name: 'dcgm'
#     static_configs:
#       - targets: ['compute-node:9400']

# 4. Import GPU dashboard (ID: 12239)
```

### Set Up Alerting

Configure alerts for critical conditions:

```bash
# SSH to controller
ssh admin@192.168.190.10

# Create alert rules
sudo vi /etc/prometheus/rules/alerts.yml
```

Add alert rules:

```yaml
groups:
  - name: node_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
```

Reload Prometheus:

```bash
sudo systemctl reload prometheus
```

### Configure Alert Notifications

Set up AlertManager for notifications:

```bash
# Edit AlertManager config
sudo vi /etc/prometheus/alertmanager.yml
```

Example Slack integration:

```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  receiver: 'slack-notifications'
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#monitoring-alerts'
        title: 'HPC Cluster Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

### Monitor Job Performance

Track specific job metrics:

```bash
# Create job monitoring script
cat > /usr/local/bin/job-metrics.sh << 'EOF'
#!/bin/bash
# Collect metrics for SLURM job
JOB_ID=$1
sstat -j $JOB_ID --format=JobID,AveCPU,AveRSS,MaxRSS,AveVMSize
EOF

chmod +x /usr/local/bin/job-metrics.sh

# Run for specific job
job-metrics.sh 123
```

### Advanced Monitoring

Explore additional exporters:

- **SLURM Exporter**: Job queue and node metrics
- **DCGM Exporter**: NVIDIA GPU detailed metrics
- **cAdvisor**: Container metrics
- **Blackbox Exporter**: Endpoint availability monitoring

## Monitoring Management

### Check Service Status

```bash
# All monitoring services
sudo systemctl status prometheus grafana-server prometheus-node-exporter

# View logs
sudo journalctl -u prometheus -n 50
sudo journalctl -u grafana-server -n 50
```

### Restart Services

```bash
# Restart Prometheus
sudo systemctl restart prometheus

# Restart Grafana
sudo systemctl restart grafana-server

# Reload configuration (no restart)
sudo systemctl reload prometheus
```

### Update Scrape Targets

```bash
# Edit Prometheus config
sudo vi /etc/prometheus/prometheus.yml

# Add new target
#  - job_name: 'new-service'
#    static_configs:
#      - targets: ['hostname:port']

# Reload config
sudo systemctl reload prometheus

# Verify targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].labels'
```

## Troubleshooting

### Prometheus Not Collecting Metrics

**Issue:** Targets showing as "DOWN" in Prometheus

**Solution:**

```bash
# Check if node exporter is running
systemctl status prometheus-node-exporter

# Verify port is listening
netstat -tulpn | grep 9100

# Check firewall (if enabled)
sudo ufw status
sudo ufw allow 9100/tcp

# Test endpoint manually
curl http://localhost:9100/metrics
```

### Grafana Login Issues

**Issue:** Cannot log in to Grafana

**Solution:**

```bash
# Reset admin password
sudo grafana-cli admin reset-admin-password newpassword

# Check Grafana is running
systemctl status grafana-server

# View Grafana logs
sudo journalctl -u grafana-server -n 100
```

### Dashboard Not Showing Data

**Issue:** Dashboard panels empty or showing "No data"

**Solution:**

```bash
# Verify Prometheus data source configured
curl -s http://admin:admin@localhost:3000/api/datasources | jq

# Test Prometheus query
curl -s http://localhost:9090/api/v1/query?query=up

# Check time range in dashboard (top-right)
# Try "Last 5 minutes" instead of "Last 24 hours"
```

### High Prometheus Disk Usage

**Issue:** Prometheus data directory filling up

**Solution:**

```bash
# Check current size
du -sh /var/lib/prometheus/

# Adjust retention period
sudo vi /etc/default/prometheus
# Add: ARGS="--storage.tsdb.retention.time=7d"

# Restart Prometheus
sudo systemctl restart prometheus
```

For more troubleshooting:

- [Monitoring Architecture](../architecture/monitoring.md)
- [Common Issues Guide](../troubleshooting/common-issues.md)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## What's Next?

**Continue learning:**

- **[Monitoring Setup Tutorial](../tutorials/06-monitoring-setup.md)** - Advanced monitoring configuration
- **[Performance Tuning Guide](../operations/performance-tuning.md)** - Optimize based on metrics
- **[Job Debugging Tutorial](../tutorials/07-job-debugging.md)** - Use metrics for debugging

**Understand the architecture:**

- **[Monitoring Architecture](../architecture/monitoring.md)** - Monitoring system design
- **[Operations Guide](../operations/maintenance.md)** - Production monitoring best practices

## Summary

In 10 minutes, you've:

1. ✅ Deployed Prometheus monitoring stack
2. ✅ Set up Grafana visualization platform
3. ✅ Configured data collection from all nodes
4. ✅ Imported pre-built system dashboards
5. ✅ Viewed real-time cluster metrics
6. ✅ Learned to create custom queries and dashboards

**Congratulations!** You now have comprehensive monitoring and observability for your HPC cluster, enabling you to
track performance, debug issues, and optimize resource utilization.

## Quick Reference

### Access URLs

```text
Prometheus: http://192.168.190.10:9090
Grafana:    http://192.168.190.10:3000
  Username: admin
  Password: admin (change on first login)
```

### Useful Commands

```bash
# Prometheus status
systemctl status prometheus
curl http://localhost:9090/-/healthy

# Grafana status
systemctl status grafana-server
curl http://localhost:3000/api/health

# View metrics
curl http://localhost:9100/metrics

# Reload Prometheus config
sudo systemctl reload prometheus
```

### Key Metrics

```promql
# System
up                                          # Service availability
node_load1                                  # System load (1 min)
rate(node_cpu_seconds_total[5m])            # CPU usage
node_memory_MemAvailable_bytes              # Available memory
node_filesystem_avail_bytes                 # Disk space

# Network
rate(node_network_receive_bytes_total[5m])  # Inbound traffic
rate(node_network_transmit_bytes_total[5m]) # Outbound traffic
```
