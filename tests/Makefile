# HPC SLURM Test Suite Makefile

.PHONY: help test test-base-images clean

help:
	@echo "HPC SLURM Test Suite"
	@echo "==================="
	@echo ""
	@echo "Available targets:"
	@echo "  test             - Run base images build tests"
	@echo "  test-base-images - Run base images build tests"
	@echo "  clean           - Clean test artifacts"
	@echo ""

# Run all tests (now just base images test)
test:
	@./run_base_images_test.sh

# Run base images test
test-base-images:
	@./run_base_images_test.sh

# Clean artifacts
clean:
	@rm -f *.log
