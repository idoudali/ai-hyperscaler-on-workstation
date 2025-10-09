# HPC SLURM Test Suite Makefile

.PHONY: help test test-all test-base-images test-container-runtime test-slurm-controller test-slurm-compute test-slurm-compute-start test-slurm-compute-deploy test-slurm-compute-tests test-slurm-compute-stop test-slurm-compute-status test-gpu-gres test-gpu-gres-start test-gpu-gres-deploy test-gpu-gres-tests test-gpu-gres-stop test-gpu-gres-status test-cgroup-isolation test-cgroup-isolation-start test-cgroup-isolation-deploy test-cgroup-isolation-tests test-cgroup-isolation-stop test-cgroup-isolation-status test-monitoring-stack test-dcgm-monitoring test-ansible-roles test-integration test-ai-how test-config-validation test-pcie-validation test-test-configs test-container-comprehensive test-quick test-verbose test-fail-fast test-role test-precommit test-ansible-syntax test-infrastructure test-configuration clean

help:
	@echo "HPC SLURM Test Suite"
	@echo "==================="
	@echo ""
	@echo "Available targets:"
	@echo "  test                   - Run core infrastructure tests"
	@echo "  test-all               - Run comprehensive test suite including builds"
	@echo "  test-base-images       - Run base images build tests"
	@echo "  test-container-runtime - Run container runtime tests"
	@echo "  test-slurm-controller  - Run SLURM controller installation tests"
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
	@./test_base_images.sh

# Run container runtime tests
test-container-runtime:
	@echo "Running container runtime tests..."
	@./test-container-runtime-framework.sh

# Run SLURM controller tests
test-slurm-controller:
	@echo "Running SLURM controller tests..."
	@./test-slurm-controller-framework.sh

# Run SLURM compute node tests (full workflow) (Task 022)
test-slurm-compute:
	@echo "Running SLURM compute node tests (full workflow)..."
	@./test-slurm-compute-framework.sh

# Start SLURM compute test cluster
test-slurm-compute-start:
	@echo "Starting SLURM compute test cluster..."
	@./test-slurm-compute-framework.sh start-cluster

# Deploy SLURM compute Ansible configuration
test-slurm-compute-deploy:
	@echo "Deploying SLURM compute Ansible configuration..."
	@./test-slurm-compute-framework.sh deploy-ansible

# Run SLURM compute tests only (assumes cluster deployed)
test-slurm-compute-tests:
	@echo "Running SLURM compute tests..."
	@./test-slurm-compute-framework.sh run-tests

# Stop SLURM compute test cluster
test-slurm-compute-stop:
	@echo "Stopping SLURM compute test cluster..."
	@./test-slurm-compute-framework.sh stop-cluster

# Show SLURM compute test cluster status
test-slurm-compute-status:
	@echo "Checking SLURM compute test cluster status..."
	@./test-slurm-compute-framework.sh status

# Run GPU GRES tests (Task 023) - full workflow
test-gpu-gres:
	@echo "Running GPU GRES tests (full workflow)..."
	@./test-gpu-gres-framework.sh

# Start GPU GRES test cluster
test-gpu-gres-start:
	@echo "Starting GPU GRES test cluster..."
	@./test-gpu-gres-framework.sh start-cluster

# Deploy GPU GRES Ansible configuration
test-gpu-gres-deploy:
	@echo "Deploying GPU GRES Ansible configuration..."
	@./test-gpu-gres-framework.sh deploy-ansible

# Run GPU GRES tests only (assumes cluster deployed)
test-gpu-gres-tests:
	@echo "Running GPU GRES tests..."
	@./test-gpu-gres-framework.sh run-tests

# Stop GPU GRES test cluster
test-gpu-gres-stop:
	@echo "Stopping GPU GRES test cluster..."
	@./test-gpu-gres-framework.sh stop-cluster

# Show GPU GRES test cluster status
test-gpu-gres-status:
	@echo "Checking GPU GRES test cluster status..."
	@./test-gpu-gres-framework.sh status

# Run cgroup isolation tests (Task 024) - full workflow
test-cgroup-isolation:
	@echo "Running cgroup resource isolation tests (full workflow)..."
	@./test-cgroup-isolation-framework.sh

# Start cgroup isolation test cluster
test-cgroup-isolation-start:
	@echo "Starting cgroup isolation test cluster..."
	@./test-cgroup-isolation-framework.sh start-cluster

# Deploy cgroup Ansible configuration
test-cgroup-isolation-deploy:
	@echo "Deploying cgroup Ansible configuration..."
	@./test-cgroup-isolation-framework.sh deploy-ansible

# Run cgroup isolation tests only (assumes cluster deployed)
test-cgroup-isolation-tests:
	@echo "Running cgroup isolation tests..."
	@./test-cgroup-isolation-framework.sh run-tests

# Stop cgroup isolation test cluster
test-cgroup-isolation-stop:
	@echo "Stopping cgroup isolation test cluster..."
	@./test-cgroup-isolation-framework.sh stop-cluster

# Show cgroup isolation test cluster status
test-cgroup-isolation-status:
	@echo "Checking cgroup isolation test cluster status..."
	@./test-cgroup-isolation-framework.sh status

# Run monitoring stack tests (Task 015)
test-monitoring-stack:
	@echo "Running Prometheus monitoring stack tests..."
	@./test-monitoring-stack-framework.sh

# Run DCGM GPU monitoring tests (full workflow)
test-dcgm-monitoring:
	@echo "Running DCGM GPU monitoring tests (full workflow)..."
	@./test-dcgm-monitoring-framework.sh

# Start DCGM test cluster
test-dcgm-start:
	@echo "Starting DCGM test cluster..."
	@./test-dcgm-monitoring-framework.sh start-cluster

# Deploy DCGM Ansible configuration
test-dcgm-deploy:
	@echo "Deploying DCGM Ansible configuration..."
	@./test-dcgm-monitoring-framework.sh deploy-ansible

# Run DCGM tests only (assumes cluster deployed)
test-dcgm-tests:
	@echo "Running DCGM tests..."
	@./test-dcgm-monitoring-framework.sh run-tests

# Stop DCGM test cluster
test-dcgm-stop:
	@echo "Stopping DCGM test cluster..."
	@./test-dcgm-monitoring-framework.sh stop-cluster

# Show DCGM test cluster status
test-dcgm-status:
	@echo "Checking DCGM test cluster status..."
	@./test-dcgm-monitoring-framework.sh status

# Run Grafana dashboard platform tests
test-grafana:
	@echo "Running Grafana dashboard platform tests..."
	@./test-grafana-framework.sh

# Run SLURM job accounting tests
test-job-accounting:
	@echo "Running SLURM job accounting tests..."
	@./test-slurm-accounting-framework.sh

# Run Ansible roles integration tests
test-ansible-roles:
	@echo "Running Ansible roles integration tests..."
	@echo "Note: Basic syntax/linting handled by pre-commit hooks"
	@./test_ansible_roles.sh

# Run integration tests
test-integration:
	@echo "Running infrastructure integration tests..."
	@./test_integration.sh

# Run AI-HOW CLI tests
test-ai-how:
	@echo "Running AI-HOW CLI installation and configuration tests..."
	@./test_ai_how_cli.sh

# Run configuration validation tests
test-config-validation:
	@echo "Running configuration validation tests..."
	@./test_config_validation.sh

# Run PCIe validation tests
test-pcie-validation:
	@echo "Running PCIe validation tests..."
	@./test_pcie_validation.sh

# Run test configuration validation tests
test-test-configs:
	@echo "Running test configuration validation tests..."
	@./test_test_configs.sh

# Quick validation tests (no building)
test-quick:
	@echo "Running quick validation tests..."
	@./test_ansible_roles.sh --integration-only
	@./test-container-runtime-framework.sh --quick
	@./test_integration.sh --quick
	@./suites/monitoring-stack/run-monitoring-stack-tests.sh --quick

# Verbose test execution
test-verbose:
	@echo "Running tests with verbose output..."
	@./test_integration.sh --verbose
	@./test_ansible_roles.sh --verbose
	@./test-container-runtime-framework.sh --verbose

# Fail-fast test execution
test-fail-fast:
	@echo "Running tests with fail-fast mode (stop on first error)..."
	@./test_integration.sh --verbose
	@./test_ansible_roles.sh --fail-fast --verbose
	@./test-container-runtime-framework.sh --verbose

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
	@./test-container-runtime-framework.sh --verbose
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
	@./test_run_basic_infrastructure.sh

# Run configuration validation tests (Task 005 - enhanced validation)
test-configuration:
	@./tests/test_config_validation.sh --all-configs --enhanced

# Run HPC cloud ansible integration tests (new orchestration script)
test-hpc-ansible:
	@echo "Testing HPC cloud Ansible orchestration script..."
	@./test-ansible-hpc-integration.sh full-cycle

# Test HPC ansible deployment only
test-hpc-ansible-deploy:
	@echo "Testing HPC cluster deployment with Ansible..."
	@./test-ansible-hpc-integration.sh deploy

# Test HPC ansible configuration only
test-hpc-ansible-configure:
	@echo "Testing HPC cluster configuration with Ansible..."
	@./test-ansible-hpc-integration.sh configure

# Dry-run test of HPC ansible workflow
test-hpc-ansible-dry:
	@echo "Dry-run testing of HPC cloud Ansible orchestration..."
	@./test-ansible-hpc-integration.sh full-cycle --dry-run

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

# Clean artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f *.log
	@rm -rf logs/
	@echo "Note: Individual test LOG_DIR directories cleaned up automatically by tests"
