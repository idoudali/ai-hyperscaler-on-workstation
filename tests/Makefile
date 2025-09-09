# HPC SLURM Test Suite Makefile

.PHONY: help test test-base-images test-ai-how test-config-validation test-pcie-validation test-test-configs clean

help:
	@echo "HPC SLURM Test Suite"
	@echo "==================="
	@echo ""
	@echo "Available targets:"
	@echo "  test                 - Run all tests"
	@echo "  test-base-images     - Run base images build tests"
	@echo "  test-ai-how          - Run AI-HOW CLI installation and configuration tests"
	@echo "  test-config-validation - Run configuration validation tests"
	@echo "  test-pcie-validation - Run PCIe validation tests"
	@echo "  test-test-configs    - Run test configuration validation tests"
	@echo "  clean               - Clean test artifacts"
	@echo ""

# Run all tests
test: test-base-images test-ai-how test-test-configs

# Run base images test
test-base-images:
	@./run_base_images_test.sh

# Run AI-HOW CLI tests
test-ai-how:
	@./test_ai_how_cli.sh

# Run configuration validation tests
test-config-validation:
	@./test_config_validation.sh

# Run PCIe validation tests
test-pcie-validation:
	@./test_pcie_validation.sh

# Run test configuration validation tests
test-test-configs:
	@./test_test_configs.sh

# Clean artifacts
clean:
	@rm -f *.log
