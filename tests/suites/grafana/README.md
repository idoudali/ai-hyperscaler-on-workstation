# Grafana Test Suite

Tests Grafana-specific functionality including dashboards, datasources, and API access.

## Test Scripts

- **run-grafana-tests.sh** - Main test runner for Grafana functionality tests

## Purpose

Validates Grafana is properly configured with datasources, dashboards are accessible,
and the API is functional for programmatic access.

## Prerequisites

- Monitoring stack tests passing
- Grafana installed and running
- Prometheus datasource configured
- Test dashboards deployed

## Usage

```bash
./run-grafana-tests.sh
```

## Dependencies

- basic-infrastructure
- monitoring-stack
