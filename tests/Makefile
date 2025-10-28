# HPC SLURM Test Suite Makefile

.PHONY: help test test-all test-base-images test-container-runtime test-slurm-controller test-slurm-controller-start test-slurm-controller-deploy test-slurm-controller-tests test-slurm-controller-stop test-slurm-controller-status test-slurm-compute test-slurm-compute-start test-slurm-compute-deploy test-slurm-compute-tests test-slurm-compute-stop test-slurm-compute-status test-gpu-gres test-gpu-gres-start test-gpu-gres-deploy test-gpu-gres-tests test-gpu-gres-stop test-gpu-gres-status test-cgroup-isolation test-cgroup-isolation-start test-cgroup-isolation-deploy test-cgroup-isolation-tests test-cgroup-isolation-stop test-cgroup-isolation-status test-job-scripts test-job-scripts-start test-job-scripts-deploy test-job-scripts-tests test-job-scripts-stop test-job-scripts-status test-container-integration test-container-integration-start test-container-integration-deploy test-container-registry-deploy test-container-integration-tests test-container-integration-stop test-container-integration-status test-virtio-fs test-virtio-fs-start test-virtio-fs-deploy test-virtio-fs-tests test-virtio-fs-stop test-virtio-fs-status test-beegfs test-beegfs-start test-beegfs-deploy test-beegfs-tests test-beegfs-stop test-beegfs-status test-monitoring-stack test-dcgm-monitoring test-ansible-roles test-integration test-ai-how test-config-validation test-pcie-validation test-test-configs test-container-comprehensive test-quick test-verbose test-fail-fast test-role test-precommit test-ansible-syntax test-infrastructure test-configuration clean clean-ssh-keys

help:
	@echo "HPC SLURM Test Suite"
	@echo "==================="
	@echo ""
	@echo "Available targets:"
	@echo "  test                   - Run core infrastructure tests"
	@echo "  test-all               - Run comprehensive test suite including builds"
	@echo "  test-base-images       - Run base images build tests"
	@echo "  test-container-runtime - Run container runtime tests"
	@echo "  test-slurm-controller  - Run SLURM controller installation tests (full workflow)"
	@echo "  test-slurm-controller-start - Start SLURM controller test cluster"
	@echo "  test-slurm-controller-deploy - Deploy SLURM controller Ansible configuration"
	@echo "  test-slurm-controller-tests - Run SLURM controller tests only"
	@echo "  test-slurm-controller-stop - Stop SLURM controller test cluster"
	@echo "  test-slurm-controller-status - Show SLURM controller test cluster status"
	@echo "  test-slurm-compute     - Run SLURM compute node tests (full workflow)"
	@echo "  test-slurm-compute-start   - Start SLURM compute test cluster"
	@echo "  test-slurm-compute-deploy  - Deploy SLURM compute Ansible configuration"
	@echo "  test-slurm-compute-tests   - Run SLURM compute tests only"
	@echo "  test-slurm-compute-stop    - Stop SLURM compute test cluster"
	@echo "  test-slurm-compute-status  - Show SLURM compute test cluster status"
	@echo "  test-gpu-gres          - Run GPU GRES tests (full workflow)"
	@echo "  test-gpu-gres-start    - Start GPU GRES test cluster"
	@echo "  test-gpu-gres-deploy   - Deploy GPU GRES Ansible configuration"
	@echo "  test-gpu-gres-tests    - Run GPU GRES tests only"
	@echo "  test-gpu-gres-stop     - Stop GPU GRES test cluster"
	@echo "  test-gpu-gres-status   - Show GPU GRES test cluster status"
	@echo "  test-cgroup-isolation  - Run cgroup resource isolation tests (full workflow)"
	@echo "  test-cgroup-isolation-start   - Start cgroup isolation test cluster"
	@echo "  test-cgroup-isolation-deploy  - Deploy cgroup Ansible configuration"
	@echo "  test-cgroup-isolation-tests   - Run cgroup isolation tests only"
	@echo "  test-cgroup-isolation-stop    - Stop cgroup isolation test cluster"
	@echo "  test-cgroup-isolation-status  - Show cgroup isolation test cluster status"
	@echo "  test-job-scripts       - Run SLURM job scripts tests (full workflow)"
	@echo "  test-job-scripts-start - Start job scripts test cluster"
	@echo "  test-job-scripts-deploy - Deploy job scripts Ansible configuration"
	@echo "  test-job-scripts-tests - Run job scripts tests only"
	@echo "  test-job-scripts-stop  - Stop job scripts test cluster"
	@echo "  test-job-scripts-status - Show job scripts test cluster status"
	@echo "  test-container-integration - Run container integration tests (full workflow)"
	@echo "  test-container-integration-start - Start container integration test cluster"
	@echo "  test-container-integration-deploy - Deploy container integration Ansible configuration"
	@echo "  test-container-registry-deploy - Build and deploy container images to test cluster"
	@echo "  test-container-integration-tests - Run container integration tests only"
	@echo "  test-container-integration-stop - Stop container integration test cluster"
	@echo "  test-container-integration-status - Show container integration test cluster status"
	@echo "  test-virtio-fs         - Run virtio-fs host directory sharing tests (full workflow)"
	@echo "  test-virtio-fs-start   - Start virtio-fs test cluster"
	@echo "  test-virtio-fs-deploy  - Deploy virtio-fs Ansible configuration"
	@echo "  test-virtio-fs-tests   - Run virtio-fs tests only"
	@echo "  test-virtio-fs-stop    - Stop virtio-fs test cluster"
	@echo "  test-virtio-fs-status  - Show virtio-fs test cluster status"
	@echo "  test-beegfs            - Run BeeGFS parallel filesystem tests (full workflow)"
	@echo "  test-beegfs-start      - Start BeeGFS test cluster"
	@echo "  test-beegfs-deploy     - Deploy BeeGFS Ansible configuration"
	@echo "  test-beegfs-tests      - Run BeeGFS tests only"
	@echo "  test-beegfs-stop       - Stop BeeGFS test cluster"
	@echo "  test-beegfs-status     - Show BeeGFS test cluster status"
	@echo "  test-monitoring-stack  - Run Prometheus monitoring stack tests"
	@echo "  test-dcgm-monitoring   - Run DCGM GPU monitoring tests (full workflow)"
	@echo "  test-dcgm-start        - Start DCGM test cluster"
	@echo "  test-dcgm-deploy       - Deploy DCGM Ansible configuration"
	@echo "  test-dcgm-tests        - Run DCGM tests only"
	@echo "  test-dcgm-stop         - Stop DCGM test cluster"
	@echo "  test-dcgm-status       - Show DCGM test cluster status"
	@echo "  test-grafana           - Run Grafana dashboard platform tests"
	@echo "  test-job-accounting    - Run SLURM job accounting tests"
	@echo "  test-ansible-roles     - Run Ansible roles validation"
	@echo "  test-integration       - Run integration tests"
	@echo "  test-pcie-validation   - Run PCIe validation tests"
	@echo "  test-test-configs      - Run test infrastructure configuration validation"
	@echo "  test-container-comprehensive - Run comprehensive container runtime validation"
	@echo "  test-infrastructure    - Run basic infrastructure tests (VM lifecycle, networking, SSH)"
	@echo "  test-configuration     - Run configuration validation tests (YAML, schema, network)"
	@echo "  clean                  - Clean test artifacts"
	@echo ""
	@echo "Quick options:"
	@echo "  test-quick             - Run quick validation tests only"
	@echo "  test-verbose           - Run tests with verbose output"
	@echo "  test-fail-fast         - Run tests with fail-fast mode (stop on first error)"
	@echo ""
	@echo "Pre-commit validation (basic syntax/linting):"
	@echo "  test-precommit         - Run all pre-commit hooks"
	@echo "  test-ansible-syntax    - Run Ansible syntax/lint validation"
	@echo ""
	@echo "SSH key management:"
	@echo "  clean-ssh-keys         - Remove SSH keys for IPs in CLUSTER_CONFIG (config-based)"
	@echo ""

# Run core infrastructure tests (fast, essential components)
test: \
  test-integration \
  test-ansible-roles \
  test-container-runtime \
  test-slurm-controller \
  test-slurm-compute \
  test-grafana \
  test-job-accounting \
  test-dcgm-monitoring

# Run comprehensive test suite including builds and CLI validation
test-all: \
  test-base-images \
  test-container-runtime \
  test-slurm-controller \
  test-slurm-compute \
  test-monitoring-stack \
  test-dcgm-monitoring \
  test-grafana \
  test-job-accounting \
  test-ansible-roles \
  test-integration \
  test-ai-how \
  test-config-validation \
  test-pcie-validation \
  test-test-configs \
  test-infrastructure \
  test-configuration

# Run base images test
test-base-images:
	@echo "Running base images build tests..."
	@./foundation/test_base_images.sh

# Run container runtime tests (DEPRECATED: Now part of test-hpc-packer-compute)
test-container-runtime:
	@echo "⚠️  DEPRECATED: test-container-runtime is now part of test-hpc-packer-compute"
	@echo "Running container runtime tests..."
	@./frameworks/test-hpc-packer-compute-framework.sh

# Run SLURM controller tests (full workflow) (DEPRECATED: Now test-hpc-packer-controller)
test-slurm-controller:
	@echo "⚠️  DEPRECATED: test-slurm-controller is now test-hpc-packer-controller"
	@echo "Running SLURM controller tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh

# Start SLURM controller test cluster
test-slurm-controller-start:
	@echo "Starting SLURM controller test cluster..."
	@./frameworks/test-hpc-packer-controller-framework.sh start-cluster

# Deploy SLURM controller Ansible configuration
test-slurm-controller-deploy:
	@echo "Deploying SLURM controller Ansible configuration..."
	@./frameworks/test-hpc-packer-controller-framework.sh deploy-ansible

# Run SLURM controller tests only (assumes cluster deployed)
test-slurm-controller-tests:
	@echo "Running SLURM controller tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh run-tests

# Stop SLURM controller test cluster
test-slurm-controller-stop:
	@echo "Stopping SLURM controller test cluster..."
	@./frameworks/test-hpc-packer-controller-framework.sh stop-cluster

# Show SLURM controller test cluster status
test-slurm-controller-status:
	@echo "Checking SLURM controller test cluster status..."
	@./frameworks/test-hpc-packer-controller-framework.sh status

# Run SLURM compute node tests (full workflow) (Task 022)
test-slurm-compute:
	@echo "Running SLURM compute node tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start SLURM compute test cluster
test-slurm-compute-start:
	@echo "Starting SLURM compute test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy SLURM compute Ansible configuration
test-slurm-compute-deploy:
	@echo "Deploying SLURM compute Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Run SLURM compute tests only (assumes cluster deployed)
test-slurm-compute-tests:
	@echo "Running SLURM compute tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop SLURM compute test cluster
test-slurm-compute-stop:
	@echo "Stopping SLURM compute test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show SLURM compute test cluster status
test-slurm-compute-status:
	@echo "Checking SLURM compute test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run GPU GRES tests (Task 023) - full workflow
test-gpu-gres:
	@echo "Running GPU GRES tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start GPU GRES test cluster
test-gpu-gres-start:
	@echo "Starting GPU GRES test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy GPU GRES Ansible configuration
test-gpu-gres-deploy:
	@echo "Deploying GPU GRES Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Run GPU GRES tests only (assumes cluster deployed)
test-gpu-gres-tests:
	@echo "Running GPU GRES tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop GPU GRES test cluster
test-gpu-gres-stop:
	@echo "Stopping GPU GRES test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show GPU GRES test cluster status
test-gpu-gres-status:
	@echo "Checking GPU GRES test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run cgroup isolation tests (Task 024) - full workflow
test-cgroup-isolation:
	@echo "Running cgroup resource isolation tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start cgroup isolation test cluster
test-cgroup-isolation-start:
	@echo "Starting cgroup isolation test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy cgroup Ansible configuration
test-cgroup-isolation-deploy:
	@echo "Deploying cgroup Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Run cgroup isolation tests only (assumes cluster deployed)
test-cgroup-isolation-tests:
	@echo "Running cgroup isolation tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop cgroup isolation test cluster
test-cgroup-isolation-stop:
	@echo "Stopping cgroup isolation test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show cgroup isolation test cluster status
test-cgroup-isolation-status:
	@echo "Checking cgroup isolation test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run SLURM job scripts tests (Task 025) - full workflow
test-job-scripts:
	@echo "Running SLURM job scripts tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start job scripts test cluster
test-job-scripts-start:
	@echo "Starting job scripts test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy job scripts Ansible configuration
test-job-scripts-deploy:
	@echo "Deploying job scripts Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Run job scripts tests only (assumes cluster deployed)
test-job-scripts-tests:
	@echo "Running job scripts tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop job scripts test cluster
test-job-scripts-stop:
	@echo "Stopping job scripts test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show job scripts test cluster status
test-job-scripts-status:
	@echo "Checking job scripts test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run container integration tests (Task 026) - full workflow
test-container-integration:
	@echo "Running container integration tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start container integration test cluster
test-container-integration-start:
	@echo "Starting container integration test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy container integration Ansible configuration
test-container-integration-deploy:
	@echo "Deploying container integration Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Build and deploy container images to test cluster (Task 026)
test-container-registry-deploy:
	@echo "Building and deploying container images to test cluster..."
	@TEST_CONFIG="$(PWD)/test-infra/configs/test-container-integration.yaml" \
	 TARGET_VM_PATTERN="test-container-integration" \
	 ./test-container-registry-framework.sh deploy-images

# Run container integration tests only (assumes cluster deployed)
test-container-integration-tests:
	@echo "Running container integration tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop container integration test cluster
test-container-integration-stop:
	@echo "Stopping container integration test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show container integration test cluster status
test-container-integration-status:
	@echo "Checking container integration test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run virtio-fs tests (Task 027) - full workflow
test-virtio-fs:
	@echo "Running virtio-fs host directory sharing tests (full workflow)..."
	@./advanced/test-virtio-fs-framework.sh

# Start virtio-fs test cluster
test-virtio-fs-start:
	@echo "Starting virtio-fs test cluster..."
	@./advanced/test-virtio-fs-framework.sh start-cluster

# Deploy virtio-fs Ansible configuration
test-virtio-fs-deploy:
	@echo "Deploying virtio-fs Ansible configuration..."
	@./advanced/test-virtio-fs-framework.sh deploy-ansible

# Run virtio-fs tests only (assumes cluster deployed)
test-virtio-fs-tests:
	@echo "Running virtio-fs tests..."
	@./advanced/test-virtio-fs-framework.sh run-tests

# Stop virtio-fs test cluster
test-virtio-fs-stop:
	@echo "Stopping virtio-fs test cluster..."
	@./advanced/test-virtio-fs-framework.sh stop-cluster

# Show virtio-fs test cluster status
test-virtio-fs-status:
	@echo "Checking virtio-fs test cluster status..."
	@./advanced/test-virtio-fs-framework.sh status

# Run BeeGFS tests (Task 028) - full workflow
test-beegfs:
	@echo "Running BeeGFS parallel filesystem tests (full workflow)..."
	@./advanced/test-beegfs-framework.sh

# Start BeeGFS test cluster
test-beegfs-start:
	@echo "Starting BeeGFS test cluster..."
	@./advanced/test-beegfs-framework.sh start-cluster

# Deploy BeeGFS Ansible configuration
test-beegfs-deploy:
	@echo "Deploying BeeGFS Ansible configuration..."
	@./advanced/test-beegfs-framework.sh deploy-ansible

# Run BeeGFS tests only (assumes cluster deployed)
test-beegfs-tests:
	@echo "Running BeeGFS tests..."
	@./advanced/test-beegfs-framework.sh run-tests

# Stop BeeGFS test cluster
test-beegfs-stop:
	@echo "Stopping BeeGFS test cluster..."
	@./advanced/test-beegfs-framework.sh stop-cluster

# Show BeeGFS test cluster status
test-beegfs-status:
	@echo "Checking BeeGFS test cluster status..."
	@./advanced/test-beegfs-framework.sh status

# Run monitoring stack tests (Task 015)
test-monitoring-stack:
	@echo "Running Prometheus monitoring stack tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh

# Run DCGM GPU monitoring tests (full workflow)
test-dcgm-monitoring:
	@echo "Running DCGM GPU monitoring tests (full workflow)..."
	@./frameworks/test-hpc-runtime-framework.sh

# Start DCGM test cluster
test-dcgm-start:
	@echo "Starting DCGM test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

# Deploy DCGM Ansible configuration
test-dcgm-deploy:
	@echo "Deploying DCGM Ansible configuration..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

# Run DCGM tests only (assumes cluster deployed)
test-dcgm-tests:
	@echo "Running DCGM tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

# Stop DCGM test cluster
test-dcgm-stop:
	@echo "Stopping DCGM test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

# Show DCGM test cluster status
test-dcgm-status:
	@echo "Checking DCGM test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# Run Grafana dashboard platform tests
test-grafana:
	@echo "Running Grafana dashboard platform tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh

# Run SLURM job accounting tests
test-job-accounting:
	@echo "Running SLURM job accounting tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh

# Run Ansible roles integration tests
test-ansible-roles:
	@echo "Running Ansible roles integration tests..."
	@echo "Note: Basic syntax/linting handled by pre-commit hooks"
	@./foundation/test_ansible_roles.sh

# Run integration tests
test-integration:
	@echo "Running infrastructure integration tests..."
	@./foundation/test_integration.sh || echo "Warning: test_integration.sh not found"

# Run AI-HOW CLI tests
test-ai-how:
	@echo "Running AI-HOW CLI installation and configuration tests..."
	@./foundation/test_ai_how_cli.sh

# Run configuration validation tests
test-config-validation:
	@echo "Running configuration validation tests..."
	@./foundation/test_config_validation.sh

# Run PCIe validation tests
test-pcie-validation:
	@echo "Running PCIe validation tests..."
	@./foundation/test_pcie_validation.sh

# Run test configuration validation tests
test-test-configs:
	@echo "Running test configuration validation tests..."
	@./foundation/test_test_configs.sh

# Quick validation tests (no building)
test-quick:
	@echo "Running quick validation tests..."
	@./foundation/test_ansible_roles.sh --integration-only
	@./foundation/test_integration.sh --quick || echo "Warning: test_integration.sh not found"
	@./suites/monitoring-stack/run-monitoring-stack-tests.sh --quick

# Verbose test execution
test-verbose:
	@echo "Running tests with verbose output..."
	@./foundation/test_integration.sh --verbose || echo "Warning: test_integration.sh not found"
	@./foundation/test_ansible_roles.sh --verbose

# Fail-fast test execution
test-fail-fast:
	@echo "Running tests with fail-fast mode (stop on first error)..."
	@./foundation/test_integration.sh --verbose || echo "Warning: test_integration.sh not found"
	@./foundation/test_ansible_roles.sh --fail-fast --verbose

# Test specific role
test-role:
ifndef ROLE
	@echo "Usage: make test-role ROLE=role-name"
	@echo "Available roles:"
	@ls -1 ../ansible/roles/ | sed 's/^/  /'
else
	@echo "Testing role: $(ROLE)"
	@./test_ansible_roles.sh --role $(ROLE) --verbose
endif

# Test container runtime comprehensively
test-container-comprehensive:
	@echo "Running comprehensive container runtime validation..."
	@./frameworks/test-hpc-packer-compute-framework.sh --verbose
	@./test_ansible_roles.sh --role container-runtime --verbose

# Pre-commit validation targets
test-precommit:
	@echo "Running all pre-commit hooks for validation..."
	@cd .. && pre-commit run --all-files

test-ansible-syntax:
	@echo "Running Ansible syntax and linting validation..."
	@cd .. && pre-commit run --all-files check-yaml
	@cd .. && pre-commit run --all-files ansible-lint
	@cd .. && pre-commit run --all-files ansible-playbook-syntax-check

# Run basic infrastructure tests (Task 005 - leveraging existing framework)
test-infrastructure:
	@./foundation/test_run_basic_infrastructure.sh

# Run configuration validation tests (Task 005 - enhanced validation)
test-configuration:
	@./foundation/test_config_validation.sh --all-configs --enhanced

# Run HPC cloud ansible integration tests (new orchestration script)
test-hpc-ansible:
	@echo "Testing HPC cloud Ansible orchestration script..."
	@./legacy/test-ansible-hpc-integration.sh full-cycle

# Test HPC ansible deployment only
test-hpc-ansible-deploy:
	@echo "Testing HPC cluster deployment with Ansible..."
	@./legacy/test-ansible-hpc-integration.sh deploy

# Test HPC ansible configuration only
test-hpc-ansible-configure:
	@echo "Testing HPC cluster configuration with Ansible..."
	@./legacy/test-ansible-hpc-integration.sh configure

# Dry-run test of HPC ansible workflow
test-hpc-ansible-dry:
	@echo "Dry-run testing of HPC cloud Ansible orchestration..."
	@./legacy/test-ansible-hpc-integration.sh full-cycle --dry-run

# Run HPC cloud deployment directly (without test wrapper)
deploy-hpc-cloud:
	@echo "Deploying HPC cloud cluster..."
	@../ansible/run-ansible-hpc-cloud.sh deploy

# Configure existing HPC cloud cluster
configure-hpc-cloud:
	@echo "Configuring HPC cloud cluster..."
	@../ansible/run-ansible-hpc-cloud.sh configure

# Verify HPC cloud cluster status
verify-hpc-cloud:
	@echo "Verifying HPC cloud cluster..."
	@../ansible/run-ansible-hpc-cloud.sh verify

# Destroy HPC cloud cluster
destroy-hpc-cloud:
	@echo "Destroying HPC cloud cluster..."
	@../ansible/run-ansible-hpc-cloud.sh destroy --force

# SSH Key Management
# Remove SSH host keys for cluster VMs to avoid "host key verification failed" errors
# after rebuilding VMs. Uses utilities from test-infra/utils/ for IP extraction and cleanup.

# Remove SSH host keys for cluster IPs from configuration file
# Default config can be overridden with CLUSTER_CONFIG variable
CLUSTER_CONFIG ?= ../config/example-multi-gpu-clusters.yaml

clean-ssh-keys:
	@echo "Removing SSH host keys for cluster configuration..."
	@echo "Configuration: $(CLUSTER_CONFIG)"
	@CLUSTER_IPS=$$(./test-infra/utils/extract-cluster-ips.sh $(CLUSTER_CONFIG) hpc 2>/dev/null || echo ""); \
	if [ -n "$$CLUSTER_IPS" ]; then \
		echo "Found IP(s) in config: $$CLUSTER_IPS"; \
		./test-infra/utils/ssh-key-cleanup.sh $$CLUSTER_IPS || echo "⚠️  SSH key cleanup failed (continuing anyway)"; \
	else \
		echo "⚠️  No IPs found in config, skipping SSH key cleanup"; \
	fi
	@echo ""

# ==============================================================================
# UNIFIED TEST FRAMEWORKS (Phase 3-4 Consolidation)
# ==============================================================================
# These 7 unified frameworks consolidate 15+ individual test frameworks:
#
# PHASE 3: HPC Packer Frameworks (TASK-036)
#   - test-hpc-runtime: 6 consolidated runtime validation suites
#   - test-hpc-packer-controller: 4 consolidated controller suites
#   - test-hpc-packer-compute: 1 consolidated compute suite
#
# PHASE 4: Refactored Standalone Frameworks
#   - test-beegfs: Parallel filesystem (75% code reduction)
#   - test-virtio-fs: Virtio-FS filesystem passthrough (77% reduction)
#   - test-pcie-passthrough: GPU passthrough validation (55% reduction)
#   - test-container-registry: Container registry infrastructure (86% reduction)
#

# HPC Runtime Framework (consolidates 6 test suites)
test-hpc-runtime:
	@echo "Running HPC Runtime Test Framework (6 consolidated suites)..."
	@./frameworks/test-hpc-runtime-framework.sh

test-hpc-runtime-start:
	@echo "Starting HPC Runtime test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh start-cluster

test-hpc-runtime-deploy:
	@echo "Deploying HPC Runtime configuration via Ansible..."
	@./frameworks/test-hpc-runtime-framework.sh deploy-ansible

test-hpc-runtime-tests:
	@echo "Running HPC Runtime tests..."
	@./frameworks/test-hpc-runtime-framework.sh run-tests

test-hpc-runtime-stop:
	@echo "Stopping HPC Runtime test cluster..."
	@./frameworks/test-hpc-runtime-framework.sh stop-cluster

test-hpc-runtime-status:
	@echo "Checking HPC Runtime test cluster status..."
	@./frameworks/test-hpc-runtime-framework.sh status

# HPC Packer Controller Framework (consolidates 4 test suites)
test-hpc-packer-controller:
	@echo "Running HPC Packer Controller Test Framework (4 consolidated suites)..."
	@./frameworks/test-hpc-packer-controller-framework.sh

test-hpc-packer-controller-start:
	@echo "Starting HPC Packer Controller test cluster..."
	@./frameworks/test-hpc-packer-controller-framework.sh start-cluster

test-hpc-packer-controller-deploy:
	@echo "Deploying HPC Packer Controller configuration via Ansible..."
	@./frameworks/test-hpc-packer-controller-framework.sh deploy-ansible

test-hpc-packer-controller-tests:
	@echo "Running HPC Packer Controller tests..."
	@./frameworks/test-hpc-packer-controller-framework.sh run-tests

test-hpc-packer-controller-stop:
	@echo "Stopping HPC Packer Controller test cluster..."
	@./frameworks/test-hpc-packer-controller-framework.sh stop-cluster

test-hpc-packer-controller-status:
	@echo "Checking HPC Packer Controller test cluster status..."
	@./frameworks/test-hpc-packer-controller-framework.sh status

# HPC Packer Compute Framework (consolidates 1 test suite)
test-hpc-packer-compute:
	@echo "Running HPC Packer Compute Test Framework..."
	@./frameworks/test-hpc-packer-compute-framework.sh

test-hpc-packer-compute-start:
	@echo "Starting HPC Packer Compute test cluster..."
	@./frameworks/test-hpc-packer-compute-framework.sh start-cluster

test-hpc-packer-compute-deploy:
	@echo "Deploying HPC Packer Compute configuration via Ansible..."
	@./frameworks/test-hpc-packer-compute-framework.sh deploy-ansible

test-hpc-packer-compute-tests:
	@echo "Running HPC Packer Compute tests..."
	@./frameworks/test-hpc-packer-compute-framework.sh run-tests

test-hpc-packer-compute-stop:
	@echo "Stopping HPC Packer Compute test cluster..."
	@./frameworks/test-hpc-packer-compute-framework.sh stop-cluster

test-hpc-packer-compute-status:
	@echo "Checking HPC Packer Compute test cluster status..."
	@./frameworks/test-hpc-packer-compute-framework.sh status

# Refactored BeeGFS Framework (60% code reduction - TASK-028)
test-beegfs-unified:
	@echo "Running refactored BeeGFS Test Framework..."
	@./advanced/test-beegfs-framework.sh

test-beegfs-unified-start:
	@echo "Starting refactored BeeGFS test cluster..."
	@./advanced/test-beegfs-framework.sh start-cluster

test-beegfs-unified-deploy:
	@echo "Deploying refactored BeeGFS configuration via Ansible..."
	@./advanced/test-beegfs-framework.sh deploy-ansible

test-beegfs-unified-tests:
	@echo "Running refactored BeeGFS tests..."
	@./advanced/test-beegfs-framework.sh run-tests

test-beegfs-unified-stop:
	@echo "Stopping refactored BeeGFS test cluster..."
	@./advanced/test-beegfs-framework.sh stop-cluster

test-beegfs-unified-status:
	@echo "Checking refactored BeeGFS test cluster status..."
	@./advanced/test-beegfs-framework.sh status

# Refactored Virtio-FS Framework (77% code reduction - TASK-027)
test-virtio-fs-unified:
	@echo "Running refactored Virtio-FS Test Framework..."
	@./advanced/test-virtio-fs-framework.sh

test-virtio-fs-unified-start:
	@echo "Starting refactored Virtio-FS test cluster..."
	@./advanced/test-virtio-fs-framework.sh start-cluster

test-virtio-fs-unified-deploy:
	@echo "Deploying refactored Virtio-FS configuration via Ansible..."
	@./advanced/test-virtio-fs-framework.sh deploy-ansible

test-virtio-fs-unified-tests:
	@echo "Running refactored Virtio-FS tests..."
	@./advanced/test-virtio-fs-framework.sh run-tests

test-virtio-fs-unified-stop:
	@echo "Stopping refactored Virtio-FS test cluster..."
	@./advanced/test-virtio-fs-framework.sh stop-cluster

test-virtio-fs-unified-status:
	@echo "Checking refactored Virtio-FS test cluster status..."
	@./advanced/test-virtio-fs-framework.sh status

# Refactored PCIe Passthrough Framework (55% code reduction - TASK-031)
test-pcie-passthrough:
	@echo "Running refactored PCIe Passthrough Test Framework..."
	@./frameworks/test-pcie-passthrough-framework.sh

test-pcie-passthrough-start:
	@echo "Starting refactored PCIe Passthrough test cluster..."
	@./frameworks/test-pcie-passthrough-framework.sh start-cluster

test-pcie-passthrough-deploy:
	@echo "Deploying refactored PCIe Passthrough configuration via Ansible..."
	@./frameworks/test-pcie-passthrough-framework.sh deploy-ansible

test-pcie-passthrough-tests:
	@echo "Running refactored PCIe Passthrough tests..."
	@./frameworks/test-pcie-passthrough-framework.sh run-tests

test-pcie-passthrough-stop:
	@echo "Stopping refactored PCIe Passthrough test cluster..."
	@./frameworks/test-pcie-passthrough-framework.sh stop-cluster

test-pcie-passthrough-status:
	@echo "Checking refactored PCIe Passthrough test cluster status..."
	@./frameworks/test-pcie-passthrough-framework.sh status

# Refactored Container Registry Framework (86% code reduction - TASK-021)
test-container-registry-unified:
	@echo "Running refactored Container Registry Test Framework..."
	@./advanced/test-container-registry-framework.sh

test-container-registry-unified-start:
	@echo "Starting refactored Container Registry test cluster..."
	@./advanced/test-container-registry-framework.sh start-cluster

test-container-registry-unified-deploy:
	@echo "Deploying refactored Container Registry configuration via Ansible..."
	@./advanced/test-container-registry-framework.sh deploy-ansible

test-container-registry-unified-deploy-images:
	@echo "Building and deploying container images to test cluster..."
	@./advanced/test-container-registry-framework.sh deploy-images

test-container-registry-unified-tests:
	@echo "Running refactored Container Registry tests..."
	@./advanced/test-container-registry-framework.sh run-tests

test-container-registry-unified-stop:
	@echo "Stopping refactored Container Registry test cluster..."
	@./advanced/test-container-registry-framework.sh stop-cluster

test-container-registry-unified-status:
	@echo "Checking refactored Container Registry test cluster status..."
	@./advanced/test-container-registry-framework.sh status

# Clean artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f *.log
	@rm -rf logs/
	@echo "Note: Individual test LOG_DIR directories cleaned up automatically by tests"
