# Cloud Cluster Testing Implementation Tasks

**Status**: Planning  
**Created**: 2025-10-28  
**Reference**: [08-cloud-cluster-testing.md](08-cloud-cluster-testing.md)

---

## Executive Summary

This document provides a task breakdown for implementing comprehensive testing of the new cloud cluster infrastructure.
These tasks add **4 new test frameworks** to validate Kubernetes deployment, MLOps stack, and model inference workflows.

**New Frameworks**: 11 total (7 HPC + 4 Cloud)  
**Timeline**: 5 weeks  
**Prerequisites**: Cloud cluster implementation (CLOUD-0.1 through CLOUD-6.3)

---

## Task List

### CLOUD-TEST-1: Create Cloud VM Test Framework ⭐ CRITICAL

**Priority**: CRITICAL  
**Duration**: 2-3 days  
**Dependencies**: CLOUD-0.2 (CLI implementation)

**Deliverables**:

- [ ] Create `tests/frameworks/test-cloud-vm-framework.sh`
- [ ] Create `tests/test-infra/configs/test-cloud-vm.yaml`
- [ ] Create test suite: `tests/suites/cloud-vm-lifecycle/`
  - [ ] **Cluster-level tests**:
    - [ ] `check-vm-provisioning.sh`
    - [ ] `check-vm-network.sh`
    - [ ] `check-vm-storage.sh`
    - [ ] `check-vm-gpu-passthrough.sh`
    - [ ] `check-vm-lifecycle.sh`
    - [ ] `check-state-tracking.sh`
  - [ ] **Individual VM tests** (NEW - CLOUD-0.4):
    - [ ] `check-individual-vm-stop.sh`
    - [ ] `check-individual-vm-start.sh`
    - [ ] `check-individual-vm-restart.sh`
    - [ ] `check-vm-status-command.sh`
    - [ ] `check-vm-gpu-release.sh`
  - [ ] **Shared GPU tests** (NEW - CLOUD-0.3):
    - [ ] `check-shared-gpu-detection.sh`
    - [ ] `check-gpu-conflict-detection.sh`
    - [ ] `check-gpu-ownership-tracking.sh`
    - [ ] `check-gpu-switch-between-vms.sh`
    - [ ] `check-gpu-error-messages.sh`
- [ ] Implement cluster CLI tests (`ai-how cloud start|stop|status|destroy`)
- [ ] Implement individual VM CLI tests (`ai-how vm stop|start|restart|status`) (NEW)
- [ ] Add Makefile targets: `test-cloud-vm`, `test-individual-vm-lifecycle`, `test-shared-gpu-management`

**Test Coverage**:

- Cloud VM provisioning with correct resources
- Network connectivity between VMs
- GPU passthrough for GPU workers
- State management in `state.json`
- Cluster lifecycle operations (start/stop/restart)
- CLI error handling and validation
- Individual VM lifecycle management (NEW - CLOUD-0.4)
- GPU resource release on VM stop (NEW - CLOUD-0.4)
- Shared GPU conflict detection (NEW - CLOUD-0.3)
- Global state GPU tracking (NEW - CLOUD-0.3)

---

### CLOUD-TEST-2: Create Kubernetes Test Framework ⭐ CRITICAL

**Priority**: CRITICAL  
**Duration**: 3-4 days  
**Dependencies**: CLOUD-2.1 (Kubespray integration)

**Deliverables**:

- [ ] Create `tests/frameworks/test-kubernetes-framework.sh`
- [ ] Create `tests/test-infra/configs/test-kubernetes.yaml`
- [ ] Create test suite: `tests/suites/kubernetes-cluster/`
  - [ ] `check-kubespray-installation.sh`
  - [ ] `check-cluster-health.sh`
  - [ ] `check-networking.sh`
  - [ ] `check-dns-resolution.sh`
  - [ ] `check-calico-cni.sh`
  - [ ] `check-ingress-controller.sh`
  - [ ] `check-metrics-server.sh`
  - [ ] `check-gpu-device-plugin.sh`
  - [ ] `check-gpu-scheduling.sh`
- [ ] Add Makefile targets: `test-kubernetes`, `test-kubernetes-deployment`, `test-kubernetes-networking`

**Test Coverage**:

- Kubernetes API server accessibility
- All nodes report Ready status
- System pods running in kube-system namespace
- Pod-to-pod networking (Calico CNI)
- CoreDNS resolution for cluster services
- NGINX ingress controller operational
- Metrics Server collecting metrics
- GPU resources exposed via NVIDIA Device Plugin

---

### CLOUD-TEST-3: Create MLOps Stack Test Framework

**Priority**: HIGH  
**Duration**: 4-5 days  
**Dependencies**: CLOUD-3.1-3.4 (MLOps stack deployment)

**Deliverables**:

- [ ] Create `tests/frameworks/test-mlops-stack-framework.sh`
- [ ] Create `tests/test-infra/configs/test-mlops-stack.yaml`
- [ ] Create test suite: `tests/suites/mlops-stack/`
  - [ ] MinIO tests (`minio/`):
    - [ ] `check-minio-deployment.sh`
    - [ ] `check-minio-storage.sh`
    - [ ] `check-minio-buckets.sh`
    - [ ] `check-minio-api.sh`
    - [ ] `check-minio-upload-download.sh`
  - [ ] PostgreSQL tests (`postgresql/`):
    - [ ] `check-postgresql-deployment.sh`
    - [ ] `check-postgresql-connection.sh`
    - [ ] `check-mlflow-schema.sh`
    - [ ] `check-postgresql-persistence.sh`
  - [ ] MLflow tests (`mlflow/`):
    - [ ] `check-mlflow-deployment.sh`
    - [ ] `check-mlflow-api.sh`
    - [ ] `check-mlflow-backend-store.sh`
    - [ ] `check-mlflow-artifact-store.sh`
    - [ ] `check-mlflow-experiment.sh`
    - [ ] `check-mlflow-model-registry.sh`
  - [ ] KServe tests (`kserve/`):
    - [ ] `check-kserve-installation.sh`
    - [ ] `check-knative-serving.sh`
    - [ ] `check-cert-manager.sh`
    - [ ] `check-inference-service-crd.sh`
    - [ ] `check-mlflow-serving-runtime.sh`
- [ ] Add Makefile targets: `test-mlops-stack`, `test-mlops-minio`, `test-mlops-mlflow`, `test-mlops-kserve`

**Test Coverage**:

- MinIO deployment and S3 API functionality
- PostgreSQL database connectivity and persistence
- MLflow tracking server API and model registry
- KServe installation with Knative Serving
- End-to-end: Register model in MLflow → Deploy via KServe

---

### CLOUD-TEST-4: Create Inference Test Framework

**Priority**: HIGH  
**Duration**: 4-5 days  
**Dependencies**: CLOUD-3.4 (KServe), CLOUD-5.1 (Oumi integration)

**Deliverables**:

- [ ] Create `tests/frameworks/test-inference-framework.sh`
- [ ] Create `tests/test-infra/configs/test-inference.yaml`
- [ ] Create test suite: `tests/suites/inference-validation/`
  - [ ] `check-inference-service-deployment.sh`
  - [ ] `check-model-loading.sh`
  - [ ] `check-inference-endpoint.sh`
  - [ ] `check-inference-request-response.sh`
  - [ ] `check-gpu-utilization.sh`
  - [ ] `check-autoscaling-scale-up.sh`
  - [ ] `check-autoscaling-scale-down.sh`
  - [ ] `check-multi-replica-load-balancing.sh`
  - [ ] `check-inference-latency.sh`
  - [ ] `check-inference-throughput.sh`
- [ ] Add Makefile targets: `test-inference`, `test-inference-deployment`, `test-inference-performance`

**Test Coverage**:

- InferenceService deployment and readiness
- Model loading from MLflow artifact store
- Inference API endpoint accessibility
- Request/response validation
- GPU utilization during inference (>70%)
- Autoscaling behavior under load
- Multi-replica load balancing
- Performance targets:
  - Cold start < 10s
  - Inference latency P95 < 500ms
  - Throughput > 50 req/s per GPU

---

### CLOUD-TEST-5: Create Multi-Cluster Test Utilities

**Priority**: MEDIUM  
**Duration**: 2-3 days  
**Dependencies**: CLOUD-TEST-1 through CLOUD-TEST-4

**Deliverables**:

- [ ] Create `tests/test-infra/utils/multi-cluster-utils.sh`
  - [ ] `is_hpc_cluster_running()`
  - [ ] `is_cloud_cluster_running()`
  - [ ] `get_multi_cluster_status()`
  - [ ] `validate_multi_cluster_resources()`
- [ ] Create `tests/test-infra/utils/cloud-cli-utils.sh`
  - [ ] `test_cloud_cli_command()`
  - [ ] `test_vm_cli_command()` (NEW - CLOUD-0.4)
  - [ ] `wait_for_cloud_cluster_ready()`
  - [ ] `wait_for_vm_ready()` (NEW - CLOUD-0.4)
  - [ ] `validate_kubernetes_cluster()`
- [ ] Create `tests/test-infra/utils/gpu-test-utils.sh` (NEW - CLOUD-0.3, CLOUD-0.4)
  - [ ] `check_gpu_allocation()`
  - [ ] `check_gpu_released()`
  - [ ] `test_gpu_conflict()`
  - [ ] `get_gpu_owner()`
  - [ ] `verify_vm_gpu()`
  - [ ] `test_gpu_transfer()`
- [ ] Create `tests/test-infra/utils/mlops-test-utils.sh`
  - [ ] `test_minio_bucket()`
  - [ ] `test_mlflow_api()`
  - [ ] `deploy_test_inference_service()`
- [ ] Create test suite: `tests/suites/multi-cluster/`
  - [ ] `test-both-clusters-running.sh` (Scenario 1)
  - [ ] `test-hpc-only.sh` (Scenario 2)
  - [ ] `test-cloud-only.sh` (Scenario 3)
  - [ ] `test-cold-start.sh` (Scenario 4)
  - [ ] `test-workflow-transition.sh` (Scenario 5)
  - [ ] `test-shared-gpu-conflict.sh` (Scenario 6 - NEW - CLOUD-0.3)
  - [ ] `test-vm-gpu-transfer.sh` (Scenario 7 - NEW - CLOUD-0.4)
- [ ] Add Makefile targets: `test-multi-cluster-scenarios`, `test-workflow-transition`, `test-shared-gpu`

**Test Coverage**:

- Multi-cluster state management
- Resource contention validation
- HPC-to-Cloud workflow transitions
- Different cluster start/stop scenarios
- Shared GPU conflict detection (NEW - CLOUD-0.3)
- Individual VM GPU transfer (NEW - CLOUD-0.4)
- Global state GPU tracking (NEW - CLOUD-0.3, CLOUD-0.4)

---

### CLOUD-TEST-6: Update Test Plan Documentation

**Priority**: MEDIUM  
**Duration**: 1-2 days  
**Dependencies**: CLOUD-TEST-1 through CLOUD-TEST-5

**Deliverables**:

- [ ] Update `00-test-inventory.md`
  - [ ] Add 4 cloud test frameworks to inventory
  - [ ] Update test suite count (16 → 20+ suites)
  - [ ] Add cloud CLI utilities to shared utilities section
- [ ] Update `02-component-matrix.md`
  - [ ] Add Cloud Cluster Components section
  - [ ] Map cloud components to test frameworks
- [ ] Update `03-framework-specifications.md`
  - [ ] Add specifications for 4 cloud test frameworks
  - [ ] Document CLI patterns for cloud frameworks
- [ ] Update `06-test-dependencies-matrix.md`
  - [ ] Add cloud framework dependency matrix
  - [ ] Document Kubernetes cluster requirements
  - [ ] Add MLOps stack requirements
- [ ] Update `tests/README.md`
  - [ ] Add cloud testing guide section
  - [ ] Document multi-cluster testing workflow

---

### CLOUD-TEST-7: Add Makefile Targets

**Priority**: MEDIUM  
**Duration**: 1 day  
**Dependencies**: CLOUD-TEST-1 through CLOUD-TEST-5

**Deliverables**:

- [ ] Update `tests/Makefile` with cloud test targets:

```makefile
# Cloud Cluster Tests
test-cloud-vm:
 ./frameworks/test-cloud-vm-framework.sh e2e

test-kubernetes:
 ./frameworks/test-kubernetes-framework.sh e2e

test-mlops-stack:
 ./frameworks/test-mlops-stack-framework.sh e2e

test-inference:
 ./frameworks/test-inference-framework.sh e2e

test-cloud-all: test-cloud-vm test-kubernetes test-mlops-stack test-inference
 @echo "✓ All cloud cluster tests passed"

# Multi-Cluster Tests
test-multi-cluster-scenarios:
 ./frameworks/test-multi-cluster-framework.sh all-scenarios

test-workflow-transition:
 ./frameworks/test-multi-cluster-framework.sh workflow-transition

# Complete Test Suite (HPC + Cloud)
test-all-clusters: test-all test-cloud-all test-multi-cluster-scenarios
 @echo "✓ All HPC and Cloud tests passed"
```

---

## Quick Reference

### New Test Frameworks

| Framework | Test Suites | Priority | Tests |
|-----------|-------------|----------|-------|
| test-cloud-vm-framework.sh | cloud-vm-lifecycle/ | CRITICAL | 6 tests |
| test-kubernetes-framework.sh | kubernetes-cluster/ | CRITICAL | 9 tests |
| test-mlops-stack-framework.sh | mlops-stack/ | HIGH | 15 tests |
| test-inference-framework.sh | inference-validation/ | HIGH | 10 tests |

**Total**: 4 frameworks, 4 test suites, 40+ new tests

### New CLI Features to Test

**Cloud Cluster Commands** (from CLOUD-0.2):

```bash
ai-how cloud start <config>      # Start cloud cluster
ai-how cloud stop <config>       # Stop cloud cluster
ai-how cloud status <config>     # Get cluster status
ai-how cloud destroy <config>    # Destroy cluster (with --force)
```

**Individual VM Commands** (NEW from CLOUD-0.4):

```bash
ai-how vm stop <vm-name>         # Stop individual VM with GPU release
ai-how vm start <vm-name>        # Start individual VM with GPU allocation
ai-how vm restart <vm-name>      # Restart VM with GPU rebinding
ai-how vm status <vm-name>       # Display detailed VM status
```

**Cluster Test Scenarios**:

1. Cold start from scratch
2. Warm restart (stop + start)
3. Forced destroy
4. Status during operations
5. Error recovery and rollback

**Individual VM Test Scenarios** (NEW):

1. Stop individual VM in running cluster
2. Start individual stopped VM
3. Restart VM with automatic GPU rebinding
4. Display detailed VM information
5. Detect and prevent GPU conflicts

### Multi-Cluster Scenarios

| Scenario | HPC | Cloud | Use Case | Test |
|----------|-----|-------|----------|------|
| 1 | ✅ Running | ✅ Running | Full stack | test-both-clusters-running.sh |
| 2 | ✅ Running | ❌ Stopped | HPC only | test-hpc-only.sh |
| 3 | ❌ Stopped | ✅ Running | Cloud only | test-cloud-only.sh |
| 4 | ❌ Stopped | ❌ Stopped | Clean | test-cold-start.sh |
| 5 | ✅ Running | 🔄 Starting | Workflow | test-workflow-transition.sh |
| 6 | 🔄 Running→Stopped | 🔄 Stopped→Running | Shared GPU conflict | test-shared-gpu-conflict.sh |
| 7 | 🔄 VM Stop→Start | 🔄 VM Start→Stop | VM GPU transfer | test-vm-gpu-transfer.sh |

---

## Timeline

| Week | Tasks | Deliverables |
|------|-------|--------------|
| **Week 1** | CLOUD-TEST-1, CLOUD-TEST-2 (partial) | Cloud VM framework, K8s framework started |
| **Week 2** | CLOUD-TEST-2 (complete), CLOUD-TEST-3 (partial) | K8s complete, MLOps started |
| **Week 3** | CLOUD-TEST-3 (complete), CLOUD-TEST-4 (partial) | MLOps complete, Inference started |
| **Week 4** | CLOUD-TEST-4 (complete), CLOUD-TEST-5 | Inference complete, Multi-cluster utils |
| **Week 5** | CLOUD-TEST-6, CLOUD-TEST-7 | Documentation and Makefile updates |

**Total Duration**: 5 weeks

---

## Success Criteria

### Functional Criteria

- [ ] All 4 cloud test frameworks created and passing
- [ ] Cloud VM lifecycle validated (provision, start, stop, destroy)
- [ ] Kubernetes cluster deployment validated (via Kubespray)
- [ ] MLOps stack components validated (MinIO, PostgreSQL, MLflow, KServe)
- [ ] Model inference workflows validated
- [ ] Multi-cluster scenarios tested (5 scenarios)
- [ ] CLI commands fully tested (`ai-how cloud`)

### Performance Criteria

- [ ] Inference latency P95 < 500ms
- [ ] GPU utilization > 70% during inference
- [ ] Throughput > 50 req/s per GPU
- [ ] Cold start < 10s
- [ ] Autoscaling responds within 60s

### Quality Criteria

- [ ] Test coverage >80% for cloud components
- [ ] All tests pass consistently (3 consecutive runs)
- [ ] Clear error messages and logging
- [ ] Integration with existing HPC test infrastructure
- [ ] Documentation complete and accurate

---

## Dependencies

### Cloud Cluster Implementation

Tasks depend on cloud cluster features being implemented:

- **CLOUD-0.1**: VM Management extension
- **CLOUD-0.2**: CLI commands (`ai-how cloud`)
- **CLOUD-0.3**: Shared GPU Resource Management (NEW)
- **CLOUD-0.4**: Enhanced VM Lifecycle Management (NEW)
- **CLOUD-1.1**: Cloud Base Packer image
- **CLOUD-1.2**: GPU Worker Cloud image
- **CLOUD-2.1**: Kubespray integration
- **CLOUD-2.2**: NVIDIA GPU Operator
- **CLOUD-3.1-3.4**: MLOps stack (MinIO, PostgreSQL, MLflow, KServe)
- **CLOUD-4.1-4.2**: Monitoring stack (Prometheus, Grafana)
- **CLOUD-5.1**: Oumi integration

### Existing Test Infrastructure

Leverage existing utilities:

- `tests/test-infra/utils/log-utils.sh`
- `tests/test-infra/utils/cluster-utils.sh`
- `tests/test-infra/utils/vm-utils.sh`
- `tests/test-infra/utils/ansible-utils.sh`
- `tests/test-infra/utils/test-framework-utils.sh`
- `tests/test-infra/utils/framework-cli.sh` (created in Phase 2)
- `tests/test-infra/utils/framework-orchestration.sh` (created in Phase 2)

---

## Risk Mitigation

### Risk 1: Resource Contention

**Issue**: Running HPC + Cloud clusters simultaneously may exceed host resources.

**Mitigation**:

- Implement resource validation in `multi-cluster-utils.sh`
- Provide clear error messages when resources insufficient
- Document minimum hardware requirements

### Risk 2: Test Execution Time

**Issue**: Full test suite (HPC + Cloud) may take 4-6 hours.

**Mitigation**:

- Modular test execution (run individual frameworks)
- Parallel test execution where possible
- CI/CD optimization (future)

### Risk 3: External Dependencies

**Issue**: Tests depend on external images and packages.

**Mitigation**:

- Pin specific versions in configurations
- Cache images locally when possible
- Validate availability before test execution

---

## Next Steps

1. **Review and Approve**: Review this task list and `08-cloud-cluster-testing.md`
2. **Create GitHub Issues**: Create issues for CLOUD-TEST-1 through CLOUD-TEST-7
3. **Wait for Dependencies**: Monitor cloud cluster implementation progress
4. **Start Implementation**: Begin CLOUD-TEST-1 once CLOUD-0.2 is complete
5. **Track Progress**: Update this document as tasks are completed

## Related Refactoring Opportunities

### Test Suite Script Refactoring

**Status**: 📝 Planned (See [09-test-suite-refactoring-plan.md](09-test-suite-refactoring-plan.md))

While implementing cloud cluster testing, consider the **test suite refactoring opportunity** to eliminate
code duplication in existing test scripts:

**Scope**: 80+ test scripts across 16 test suite directories
**Duplication**: 2,000-3,000 lines of duplicated logging, color definitions, and test execution patterns
**Impact**: 30-40% code reduction in test suite scripts
**Timeline**: 14 hours estimated effort

**Benefits for Cloud Testing**:

- Standardized logging patterns for new cloud test suites
- Consistent test execution patterns across HPC and Cloud tests
- Reduced maintenance overhead for test infrastructure
- Better developer experience for cloud test development

**Implementation Strategy**:

- Create shared utilities for test suites (`tests/suites/common/`)
- Refactor existing test scripts to use shared utilities
- Apply same patterns to new cloud test suites
- Preserve all test logic and functionality

This refactoring complements cloud cluster testing by providing a clean, maintainable foundation for
both existing HPC tests and new cloud tests.

---

**Document Version**: 1.0  
**Status**: Planning  
**Created**: 2025-10-28  
**For Details**: See [08-cloud-cluster-testing.md](08-cloud-cluster-testing.md)
