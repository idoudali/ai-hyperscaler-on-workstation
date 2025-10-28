#!/bin/bash
#
# SLURM PMIx Configuration Validation Script
# Task 011 - Quick validation of SLURM PMIx configuration templates
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# BLUE='\033[0;34m'  # Currently unused, reserved for future enhancements
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Test configuration
SLURM_CONF_TEMPLATE="ansible/roles/slurm-controller/templates/slurm.conf.j2"
PMIX_CONF_TEMPLATE="ansible/roles/slurm-controller/templates/pmix.conf.j2"
DEFAULTS_FILE="ansible/roles/slurm-controller/defaults/main.yml"
CONFIGURE_TASK="ansible/roles/slurm-controller/tasks/configure.yml"

log_info "Validating SLURM PMIx configuration templates..."

# Check if template files exist
if [ ! -f "$SLURM_CONF_TEMPLATE" ]; then
    log_error "SLURM configuration template not found: $SLURM_CONF_TEMPLATE"
    exit 1
fi

if [ ! -f "$PMIX_CONF_TEMPLATE" ]; then
    log_error "PMIx configuration template not found: $PMIX_CONF_TEMPLATE"
    exit 1
fi

if [ ! -f "$DEFAULTS_FILE" ]; then
    log_error "Defaults file not found: $DEFAULTS_FILE"
    exit 1
fi

if [ ! -f "$CONFIGURE_TASK" ]; then
    log_error "Configure task not found: $CONFIGURE_TASK"
    exit 1
fi

log_success "All required files found"

# Check for required PMIx configuration elements in SLURM template
log_info "Checking SLURM configuration template for PMIx settings..."

required_slurm_settings=(
    "MpiDefault"
    "MpiParams"
    "GresTypes"
    "SelectType"
    "ProctrackType"
    "pmix_enabled"
)

missing_slurm_settings=()
for setting in "${required_slurm_settings[@]}"; do
    if ! grep -q "$setting" "$SLURM_CONF_TEMPLATE"; then
        missing_slurm_settings+=("$setting")
    fi
done

if [ ${#missing_slurm_settings[@]} -gt 0 ]; then
    log_error "Missing PMIx settings in SLURM template: ${missing_slurm_settings[*]}"
    exit 1
fi

log_success "All required PMIx settings found in SLURM template"

# Check for required PMIx configuration elements in PMIx template
log_info "Checking PMIx configuration template..."

required_pmix_settings=(
    "pmix_server_addr"
    "pmix_server_port"
    "pmix_client_addr"
    "pmix_client_port"
)

missing_pmix_settings=()
for setting in "${required_pmix_settings[@]}"; do
    if ! grep -q "$setting" "$PMIX_CONF_TEMPLATE"; then
        missing_pmix_settings+=("$setting")
    fi
done

if [ ${#missing_pmix_settings[@]} -gt 0 ]; then
    log_error "Missing PMIx settings in PMIx template: ${missing_pmix_settings[*]}"
    exit 1
fi

log_success "All required PMIx settings found in PMIx template"

# Check for required variables in defaults file
log_info "Checking defaults file for PMIx variables..."

required_defaults=(
    "pmix_enabled"
    "pmix_ports"
    "slurm_mpi_default"
    "slurm_mpi_params"
    "gres_types"
    "select_type"
)

missing_defaults=()
for var in "${required_defaults[@]}"; do
    if ! grep -q "$var:" "$DEFAULTS_FILE"; then
        missing_defaults+=("$var")
    fi
done

if [ ${#missing_defaults[@]} -gt 0 ]; then
    log_error "Missing PMIx variables in defaults: ${missing_defaults[*]}"
    exit 1
fi

log_success "All required PMIx variables found in defaults file"

# Check configure task for PMIx validation
log_info "Checking configure task for PMIx validation..."

required_validation=(
    "slurm_config_validation"
    "pmix_library_paths"
    "slurm_mpi_list"
    "mpi_ports_check"
)

missing_validation=()
for validation in "${required_validation[@]}"; do
    if ! grep -q "$validation" "$CONFIGURE_TASK"; then
        missing_validation+=("$validation")
    fi
done

if [ ${#missing_validation[@]} -gt 0 ]; then
    log_error "Missing PMIx validation in configure task: ${missing_validation[*]}"
    exit 1
fi

log_success "All required PMIx validation found in configure task"

# Check YAML syntax
log_info "Checking YAML syntax..."

if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('$DEFAULTS_FILE'))" >/dev/null 2>&1; then
        log_success "Defaults file YAML syntax is valid"
    else
        log_error "Defaults file YAML syntax is invalid"
        exit 1
    fi

    if python3 -c "import yaml; yaml.safe_load(open('$CONFIGURE_TASK'))" >/dev/null 2>&1; then
        log_success "Configure task YAML syntax is valid"
    else
        log_error "Configure task YAML syntax is invalid"
        exit 1
    fi
elif command -v yamllint >/dev/null 2>&1; then
    if yamllint "$DEFAULTS_FILE" >/dev/null 2>&1; then
        log_success "Defaults file YAML syntax is valid"
    else
        log_error "Defaults file YAML syntax is invalid"
        exit 1
    fi

    if yamllint "$CONFIGURE_TASK" >/dev/null 2>&1; then
        log_success "Configure task YAML syntax is valid"
    else
        log_error "Configure task YAML syntax is invalid"
        exit 1
    fi
else
    log_warn "Neither python3 nor yamllint available, skipping YAML syntax validation"
fi

log_success "SLURM PMIx configuration validation completed successfully!"
log_info "Configuration templates are ready for deployment"

exit 0
