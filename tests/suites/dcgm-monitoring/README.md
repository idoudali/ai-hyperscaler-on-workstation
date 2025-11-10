# DCGM Monitoring Test Suite

Tests NVIDIA DCGM (Data Center GPU Manager) exporter deployment and GPU metrics collection.

## Test Scripts

- **check-dcgm-installation.sh** - Validates DCGM installation on GPU nodes
- **check-dcgm-exporter.sh** - Tests DCGM exporter deployment and metrics exposure
- **check-prometheus-integration.sh** - Validates Prometheus scraping of DCGM metrics
- **run-dcgm-monitoring-tests.sh** - Main test runner for DCGM monitoring tests

## Purpose

Ensures DCGM is properly installed on GPU nodes and exporting metrics to Prometheus
for GPU monitoring and alerting.

## Prerequisites

- GPU validation tests passing
- Monitoring stack tests passing
- DCGM installed on GPU nodes
- DCGM exporter configured
- Prometheus configured to scrape DCGM endpoints

## Usage

```bash
./run-dcgm-monitoring-tests.sh
```

## Dependencies

- basic-infrastructure
- gpu-validation
- monitoring-stack

## Additional Documentation

See [NVIDIA DCGM documentation](https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-user-guide/index.html)
for configuration details and troubleshooting.
