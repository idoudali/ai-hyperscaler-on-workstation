# HPC SLURM Test Suite Makefile

.PHONY: help test test-all test-base-images test-container-runtime test-slurm-controller test-ansible-roles test-integration test-ai-how test-config-validation test-pcie-validation test-test-configs test-container-comprehensive test-quick test-verbose test-fail-fast test-role test-precommit test-ansible-syntax test-infrastructure test-configuration clean

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
test: test-integration test-ansible-roles test-container-runtime test-slurm-controller

# Run comprehensive test suite including builds and CLI validation
test-all: test-base-images test-container-runtime test-slurm-controller test-ansible-roles test-integration test-ai-how test-config-validation test-pcie-validation test-test-configs test-infrastructure test-configuration

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

# Clean artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f *.log
	@rm -rf logs/
	@echo "Note: Individual test LOG_DIR directories cleaned up automatically by tests"
