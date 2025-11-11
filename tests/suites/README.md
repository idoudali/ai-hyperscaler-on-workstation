# Test Suites

This directory contains comprehensive test suites for validating the AI-HPC-on-Workstation infrastructure.

## Test Suite Categories

### Infrastructure Layer

- **[basic-infrastructure/](./basic-infrastructure/)** - VM lifecycle, networking, SSH connectivity tests
- **[beegfs/](./beegfs/)** - BeeGFS distributed filesystem services and performance tests
- **[virtio-fs/](./virtio-fs/)** - VirtioFS mount functionality and performance validation

### SLURM Cluster

- **[slurm-controller/](./slurm-controller/)** - SLURM controller installation, configuration, and functionality
- **[slurm-compute/](./slurm-compute/)** - Compute node registration and distributed job execution
- **[slurm-accounting/](./slurm-accounting/)** - Job accounting and database integration tests
- **[slurm-job-examples/](./slurm-job-examples/)** - Example job submissions and cluster health validation

### GPU Resources

- **[gpu-validation/](./gpu-validation/)** - GPU driver installation and PCIe device detection
- **[gpu-gres/](./gpu-gres/)** - GPU GRES configuration and scheduling in SLURM
- **[cgroup-isolation/](./cgroup-isolation/)** - Cgroup-based GPU resource isolation tests

### Container Platform

#### Runtime Framework Suites

- **[container-runtime/](./container-runtime/)** - Singularity/Apptainer installation and execution (on compute nodes)
- **[container-integration/](./container-integration/)** - SLURM + container + GPU + MPI (via SLURM from controller)
- **[container-e2e/](./container-e2e/)** - End-to-end ML framework deployments via SLURM (PyTorch, TensorFlow)

#### Registry Framework Suites

- **[container-registry/](./container-registry/)** - Container registry infrastructure and synchronization (via controller)
- **[container-deployment/](./container-deployment/)** - Image deployment and multi-node sync (via controller)

### Monitoring Stack

- **[monitoring-stack/](./monitoring-stack/)** - Prometheus, Grafana, and exporters deployment
- **[grafana/](./grafana/)** - Grafana functionality and dashboard tests
- **[dcgm-monitoring/](./dcgm-monitoring/)** - DCGM exporter and GPU metrics collection

### Utilities

- **[common/](./common/)** - Shared test utilities, helpers, and logging functions
- **[job-scripts/](./job-scripts/)** - SLURM prolog/epilog scripts and failure detection

## Running Tests

Each test suite contains a main runner script (e.g., `run-*-tests.sh`) that executes all tests in that category.

```bash
# Run a specific test suite
cd <suite-name>
./run-<suite-name>-tests.sh

# Run all infrastructure tests
cd basic-infrastructure
./run-basic-infrastructure-tests.sh
```

## Test Dependencies

Test suites have dependencies on each other. Refer to the test execution order:

1. Basic Infrastructure → BeeGFS/VirtioFS
2. GPU Validation → GPU GRES → Cgroup Isolation
3. SLURM Controller → SLURM Compute
4. Container Runtime → Container Registry → Container Deployment
5. Monitoring Stack → DCGM Monitoring → Grafana

## Logs

Test execution logs are stored in `logs/` subdirectories within each suite.
