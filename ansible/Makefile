# Ansible Makefile - Validation and Testing Targets
# This Makefile provides standardized commands for validating, linting, and testing Ansible code

# Default values
ROLE ?=
PLAYBOOK ?=
INVENTORY ?= inventories/
TAGS ?=
SKIP_TAGS ?=
LIMIT ?=

# Directories
PLAYBOOKS_DIR := playbooks
ROLES_DIR := roles
COLLECTIONS_DIR := collections

# Virtual Environment (managed by uv)
VENV_DIR := .venv
UV_CMD := uv
UV_RUN := $(UV_CMD) run

# Use uv run for all commands (uv automatically uses .venv if it exists)
ANSIBLE_PLAYBOOK := $(UV_RUN) ansible-playbook
ANSIBLE_LINT := $(UV_RUN) ansible-lint
ANSIBLE_GALAXY := $(UV_RUN) ansible-galaxy
ANSIBLE_INVENTORY := $(UV_RUN) ansible-inventory
ANSIBLE_CONFIG := $(UV_RUN) ansible-config
UV_PIP := $(UV_CMD) pip
VENV_PYTHON := $(UV_RUN) python3

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE := \033[34m

# Helper function to print colored output
define print_header
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)===================================================$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)  $(1)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)===================================================$(COLOR_RESET)"
endef

.PHONY: help
help: ## Show this help message
	@echo "$(COLOR_BOLD)Ansible Makefile - Available Targets$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-30s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_BOLD)Examples:$(COLOR_RESET)"
	@echo "  make venv-create                            # Create venv and install requirements"
	@echo "  make validate-all                           # Run all validation checks"
	@echo "  make lint-role ROLE=slurm-controller       # Lint specific role"
	@echo "  make test-playbook-check PLAYBOOK=playbook-hpc-runtime.yml"
	@echo "  make syntax-check-all                       # Check syntax of all playbooks"
	@echo ""

#####################################################
# Virtual Environment Targets
#####################################################

$(VENV_DIR): requirements.txt
	$(call print_header,Creating Virtual Environment)
	@if ! command -v $(UV_CMD) >/dev/null 2>&1; then \
		echo "$(COLOR_YELLOW)Error: uv not found. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh$(COLOR_RESET)"; \
		exit 1; \
	fi
	$(UV_CMD) venv $(VENV_DIR)
	$(UV_PIP) install -r requirements.txt
	@echo "$(COLOR_GREEN)✓ Virtual environment ready!$(COLOR_RESET)"

.PHONY: venv-create
venv-create: $(VENV_DIR) ## Create Python virtual environment and install requirements.txt


#####################################################
# Validation Targets
#####################################################

.PHONY: validate-all
validate-all: venv-create ## Run all validation checks (syntax + lint + requirements)
	$(call print_header,Running All Validation Checks)
	@$(MAKE) check-requirements
	@$(MAKE) syntax-check-all
	@$(MAKE) lint-all
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ All validation checks passed!$(COLOR_RESET)"

.PHONY: check-requirements
check-requirements: venv-create ## Verify ansible-lint is installed
	$(call print_header,Checking Requirements)
	@$(ANSIBLE_PLAYBOOK) --version > /dev/null
	@$(ANSIBLE_LINT) --version > /dev/null
	@echo "$(COLOR_GREEN)✓ All required tools are installed$(COLOR_RESET)"

#####################################################
# Syntax Check Targets
#####################################################

.PHONY: syntax-check-all
syntax-check-all: venv-create ## Syntax check all playbooks
	$(call print_header,Syntax Check - All Playbooks)
	@for playbook in $(PLAYBOOKS_DIR)/*.yml; do \
		echo "$(COLOR_YELLOW)Checking: $$playbook$(COLOR_RESET)"; \
		$(ANSIBLE_PLAYBOOK) --syntax-check $$playbook || exit 1; \
	done
	@echo "$(COLOR_GREEN)✓ All playbooks passed syntax check$(COLOR_RESET)"

.PHONY: syntax-check-playbook
syntax-check-playbook: venv-create ## Syntax check specific playbook (use PLAYBOOK=name.yml)
	@if [ -z "$(PLAYBOOK)" ]; then \
		echo "$(COLOR_YELLOW)Error: PLAYBOOK variable not set$(COLOR_RESET)"; \
		echo "Usage: make syntax-check-playbook PLAYBOOK=playbook-name.yml"; \
		exit 1; \
	fi
	$(call print_header,Syntax Check - $(PLAYBOOK))
	@$(ANSIBLE_PLAYBOOK) --syntax-check $(PLAYBOOKS_DIR)/$(PLAYBOOK)
	@echo "$(COLOR_GREEN)✓ Syntax check passed$(COLOR_RESET)"

#####################################################
# Lint Targets
#####################################################

.PHONY: lint-all
lint-all: venv-create ## Lint all playbooks and roles
	$(call print_header,Linting - All Files)
	@$(ANSIBLE_LINT) $(PLAYBOOKS_DIR)/ $(ROLES_DIR)/
	@echo "$(COLOR_GREEN)✓ Linting completed$(COLOR_RESET)"

.PHONY: lint-playbooks
lint-playbooks: venv-create ## Lint all playbooks
	$(call print_header,Linting - Playbooks)
	@$(ANSIBLE_LINT) $(PLAYBOOKS_DIR)/
	@echo "$(COLOR_GREEN)✓ Playbook linting completed$(COLOR_RESET)"

.PHONY: lint-roles
lint-roles: venv-create ## Lint all roles
	$(call print_header,Linting - All Roles)
	@$(ANSIBLE_LINT) $(ROLES_DIR)/
	@echo "$(COLOR_GREEN)✓ Role linting completed$(COLOR_RESET)"

.PHONY: lint-role
lint-role: venv-create ## Lint specific role (use ROLE=role-name)
	@if [ -z "$(ROLE)" ]; then \
		echo "$(COLOR_YELLOW)Error: ROLE variable not set$(COLOR_RESET)"; \
		echo "Usage: make lint-role ROLE=role-name"; \
		echo "Available roles:"; \
		ls -1 $(ROLES_DIR)/; \
		exit 1; \
	fi
	$(call print_header,Linting Role - $(ROLE))
	@$(ANSIBLE_LINT) $(ROLES_DIR)/$(ROLE)/
	@echo "$(COLOR_GREEN)✓ Role linting completed$(COLOR_RESET)"

.PHONY: lint-playbook
lint-playbook: venv-create ## Lint specific playbook (use PLAYBOOK=name.yml)
	@if [ -z "$(PLAYBOOK)" ]; then \
		echo "$(COLOR_YELLOW)Error: PLAYBOOK variable not set$(COLOR_RESET)"; \
		echo "Usage: make lint-playbook PLAYBOOK=playbook-name.yml"; \
		exit 1; \
	fi
	$(call print_header,Linting Playbook - $(PLAYBOOK))
	@$(ANSIBLE_LINT) $(PLAYBOOKS_DIR)/$(PLAYBOOK)
	@echo "$(COLOR_GREEN)✓ Playbook linting completed$(COLOR_RESET)"

#####################################################
# Dry-Run Test Targets (Check Mode)
#####################################################

.PHONY: test-playbook-check
test-playbook-check: venv-create ## Test playbook in check mode (use PLAYBOOK=name.yml, optional: INVENTORY=path TAGS=tag1,tag2)
	@if [ -z "$(PLAYBOOK)" ]; then \
		echo "$(COLOR_YELLOW)Error: PLAYBOOK variable not set$(COLOR_RESET)"; \
		echo "Usage: make test-playbook-check PLAYBOOK=playbook-name.yml [INVENTORY=path] [TAGS=tag1,tag2]"; \
		exit 1; \
	fi
	$(call print_header,Dry-Run Test - $(PLAYBOOK))
	@CMD="$(ANSIBLE_PLAYBOOK) --check -i $(INVENTORY) $(PLAYBOOKS_DIR)/$(PLAYBOOK)"; \
	if [ -n "$(TAGS)" ]; then CMD="$$CMD --tags $(TAGS)"; fi; \
	if [ -n "$(SKIP_TAGS)" ]; then CMD="$$CMD --skip-tags $(SKIP_TAGS)"; fi; \
	if [ -n "$(LIMIT)" ]; then CMD="$$CMD --limit $(LIMIT)"; fi; \
	echo "$(COLOR_YELLOW)Running: $$CMD$(COLOR_RESET)"; \
	eval $$CMD
	@echo "$(COLOR_GREEN)✓ Dry-run test completed$(COLOR_RESET)"

.PHONY: test-role-check
test-role-check: venv-create ## Test specific role in check mode (use ROLE=role-name PLAYBOOK=playbook.yml)
	@if [ -z "$(ROLE)" ] || [ -z "$(PLAYBOOK)" ]; then \
		echo "$(COLOR_YELLOW)Error: ROLE and PLAYBOOK variables must be set$(COLOR_RESET)"; \
		echo "Usage: make test-role-check ROLE=role-name PLAYBOOK=playbook-name.yml"; \
		exit 1; \
	fi
	$(call print_header,Dry-Run Test - Role $(ROLE) in $(PLAYBOOK))
	@$(ANSIBLE_PLAYBOOK) --check -i $(INVENTORY) --tags $(ROLE) $(PLAYBOOKS_DIR)/$(PLAYBOOK)
	@echo "$(COLOR_GREEN)✓ Role dry-run test completed$(COLOR_RESET)"

#####################################################
# Role-Specific Targets
#####################################################

.PHONY: list-roles
list-roles: ## List all available roles
	$(call print_header,Available Roles)
	@ls -1 $(ROLES_DIR)/ | grep -v README.md
	@echo ""

.PHONY: show-role-structure
show-role-structure: ## Show structure of a specific role (use ROLE=role-name)
	@if [ -z "$(ROLE)" ]; then \
		echo "$(COLOR_YELLOW)Error: ROLE variable not set$(COLOR_RESET)"; \
		echo "Usage: make show-role-structure ROLE=role-name"; \
		exit 1; \
	fi
	$(call print_header,Role Structure - $(ROLE))
	@tree $(ROLES_DIR)/$(ROLE)/ || ls -laR $(ROLES_DIR)/$(ROLE)/

.PHONY: validate-role
validate-role: ## Validate specific role (syntax + lint) (use ROLE=role-name)
	@if [ -z "$(ROLE)" ]; then \
		echo "$(COLOR_YELLOW)Error: ROLE variable not set$(COLOR_RESET)"; \
		echo "Usage: make validate-role ROLE=role-name"; \
		exit 1; \
	fi
	$(call print_header,Validating Role - $(ROLE))
	@$(MAKE) lint-role ROLE=$(ROLE)
	@echo "$(COLOR_GREEN)✓ Role validation completed$(COLOR_RESET)"

#####################################################
# Playbook-Specific Targets
#####################################################

.PHONY: list-playbooks
list-playbooks: ## List all available playbooks
	$(call print_header,Available Playbooks)
	@ls -1 $(PLAYBOOKS_DIR)/*.yml
	@echo ""

.PHONY: validate-playbook
validate-playbook: ## Validate specific playbook (syntax + lint) (use PLAYBOOK=name.yml)
	@if [ -z "$(PLAYBOOK)" ]; then \
		echo "$(COLOR_YELLOW)Error: PLAYBOOK variable not set$(COLOR_RESET)"; \
		echo "Usage: make validate-playbook PLAYBOOK=playbook-name.yml"; \
		exit 1; \
	fi
	$(call print_header,Validating Playbook - $(PLAYBOOK))
	@$(MAKE) syntax-check-playbook PLAYBOOK=$(PLAYBOOK)
	@$(MAKE) lint-playbook PLAYBOOK=$(PLAYBOOK)
	@echo "$(COLOR_GREEN)✓ Playbook validation completed$(COLOR_RESET)"

#####################################################
# Inventory Targets
#####################################################

.PHONY: list-inventory
list-inventory: venv-create ## List inventory hosts (use INVENTORY=path to specify)
	$(call print_header,Inventory List)
	@$(ANSIBLE_INVENTORY) -i $(INVENTORY) --list

.PHONY: graph-inventory
graph-inventory: venv-create ## Show inventory as a graph (use INVENTORY=path to specify)
	$(call print_header,Inventory Graph)
	@$(ANSIBLE_INVENTORY) -i $(INVENTORY) --graph

.PHONY: validate-inventory
validate-inventory: venv-create ## Validate inventory configuration
	$(call print_header,Validating Inventory)
	@$(ANSIBLE_INVENTORY) -i $(INVENTORY) --list > /dev/null 2>&1 && \
		echo "$(COLOR_GREEN)✓ Inventory is valid$(COLOR_RESET)" || \
		{ echo "$(COLOR_YELLOW)✗ Inventory validation failed$(COLOR_RESET)"; exit 1; }


#####################################################
# Quick Test Targets
#####################################################

.PHONY: quick-check
quick-check: venv-create ## Quick validation (syntax + basic lint on changed files)
	$(call print_header,Quick Validation Check)
	@echo "$(COLOR_YELLOW)Checking Git status for changed files...$(COLOR_RESET)"
	@CHANGED_PLAYBOOKS=$$(git diff --name-only --diff-filter=ACM | grep "^ansible/playbooks/.*\.yml$$" || true); \
	CHANGED_ROLES=$$(git diff --name-only --diff-filter=ACM | grep "^ansible/roles/" | cut -d'/' -f3 | sort -u || true); \
	if [ -n "$$CHANGED_PLAYBOOKS" ]; then \
		echo "$(COLOR_YELLOW)Validating changed playbooks:$(COLOR_RESET)"; \
		for playbook in $$CHANGED_PLAYBOOKS; do \
			echo "  - $$playbook"; \
			$(ANSIBLE_PLAYBOOK) --syntax-check $$playbook || exit 1; \
			$(ANSIBLE_LINT) $$playbook || exit 1; \
		done; \
	fi; \
	if [ -n "$$CHANGED_ROLES" ]; then \
		echo "$(COLOR_YELLOW)Validating changed roles:$(COLOR_RESET)"; \
		for role in $$CHANGED_ROLES; do \
			echo "  - $$role"; \
			$(ANSIBLE_LINT) $(ROLES_DIR)/$$role/ || exit 1; \
		done; \
	fi; \
	if [ -z "$$CHANGED_PLAYBOOKS" ] && [ -z "$$CHANGED_ROLES" ]; then \
		echo "$(COLOR_GREEN)No Ansible files changed$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_GREEN)✓ Quick validation completed$(COLOR_RESET)"; \
	fi

#####################################################
# Documentation Targets
#####################################################

.PHONY: show-config
show-config: venv-create ## Show current Ansible configuration
	$(call print_header,Ansible Configuration)
	@$(ANSIBLE_CONFIG) dump --only-changed

.PHONY: show-version
show-version: venv-create ## Show Ansible version information
	$(call print_header,Ansible Version)
	@$(VENV_PYTHON) -c "import ansible; print(f'Ansible {ansible.__version__}')"
	@echo "Python: $$($(VENV_PYTHON) --version)"

#####################################################
# Cleanup Targets
#####################################################

.PHONY: clean
clean: ## Clean up temporary files and caches
	$(call print_header,Cleaning Up)
	@echo "Removing temporary files..."
	@find . -type f -name "*.retry" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@rm -rf /tmp/ansible_facts 2>/dev/null || true
	@rm -rf /tmp/.ansible-* 2>/dev/null || true
	@echo "$(COLOR_GREEN)✓ Cleanup completed$(COLOR_RESET)"

.PHONY: clean-collections
clean-collections: ## Remove installed collections
	$(call print_header,Removing Collections)
	@rm -rf $(COLLECTIONS_DIR)/*
	@echo "$(COLOR_GREEN)✓ Collections removed$(COLOR_RESET)"

#####################################################
# Development Targets
#####################################################

.PHONY: watch
watch: ## Watch for changes and run validation (requires entr)
	@if ! command -v entr >/dev/null 2>&1; then \
		echo "$(COLOR_YELLOW)Error: entr not found. Install with: apt-get install entr$(COLOR_RESET)"; \
		exit 1; \
	fi
	$(call print_header,Watching for Changes)
	@echo "$(COLOR_YELLOW)Watching for changes in playbooks and roles...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Press Ctrl+C to stop$(COLOR_RESET)"
	@find $(PLAYBOOKS_DIR) $(ROLES_DIR) -name "*.yml" -o -name "*.yaml" | entr make quick-check

#####################################################
# CI/CD Integration Targets
#####################################################

.PHONY: ci-validate
ci-validate: venv-create ## Full validation for CI/CD pipeline
	$(call print_header,CI/CD Validation)
	@$(MAKE) check-requirements
	@$(MAKE) syntax-check-all
	@$(MAKE) lint-all
	@$(MAKE) validate-inventory
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ CI/CD validation completed successfully!$(COLOR_RESET)"

.PHONY: pre-commit
pre-commit: venv-create ## Run pre-commit checks (quick validation)
	@$(MAKE) quick-check
