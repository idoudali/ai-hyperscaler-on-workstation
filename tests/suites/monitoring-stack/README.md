# Monitoring Stack Test Suite

Tests Prometheus, Grafana, and exporter deployment and integration.

## Test Scripts

- **check-components-installation.sh** - Validates monitoring component installation
- **check-grafana-installation.sh** - Tests Grafana deployment and configuration
- **check-grafana-functionality.sh** - Validates Grafana dashboard and datasource functionality
- **check-monitoring-integration.sh** - Tests integration between Prometheus and exporters
- **run-monitoring-stack-tests.sh** - Main test runner for monitoring stack tests

## Purpose

Ensures the monitoring infrastructure is properly deployed with Prometheus collecting
metrics from node exporters and Grafana providing visualization.

## Prerequisites

- Basic infrastructure tests passing
- Prometheus server deployed
- Node exporters installed on all nodes
- Grafana installed and accessible

## Usage

```bash
./run-monitoring-stack-tests.sh
```

## Dependencies

- basic-infrastructure
