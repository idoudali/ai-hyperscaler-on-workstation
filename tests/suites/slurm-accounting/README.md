# SLURM Accounting Test Suite

Tests SLURM accounting database integration and job history tracking.

## Test Scripts

- **run-slurm-accounting-tests.sh** - Main test runner for accounting functionality

## Purpose

Validates that SLURM accounting is properly configured with the database backend
and correctly tracks job information, resource usage, and user activity.

## Prerequisites

- SLURM controller tests passing
- MariaDB/MySQL database configured for SLURM accounting
- slurmdbd daemon running

## Usage

```bash
./run-slurm-accounting-tests.sh
```

## Dependencies

- basic-infrastructure
- slurm-controller
