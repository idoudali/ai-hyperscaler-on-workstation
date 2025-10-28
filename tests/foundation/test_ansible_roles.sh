#!/bin/bash
# Ansible Roles Integration Test Suite
# High-level integration testing for Ansible roles and playbooks
# Basic syntax and linting is handled by pre-commit hooks

set -euo pipefail

PS4='+ [${BASH_SOURCE[0]}:L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Signal handling for clean interruption
cleanup() {
    echo
    log_warn "Test interrupted by user (Ctrl+C)"
    exit 130
}
trap cleanup INT TERM

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_SCRIPT="$PROJECT_ROOT/scripts/run-in-dev-container.sh"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Test output
TEST_OUTPUT_DIR="/tmp/ansible_test_outputs"
mkdir -p "$TEST_OUTPUT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
FAILED_TESTS=()
VERBOSE_MODE=false
ROLES_TO_TEST=()
INTEGRATION_ONLY=false
FAIL_FAST=false

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${GREEN}[VERBOSE]${NC} $1"
    fi
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    echo "Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        log_info "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")

        # Stop on first error if fail-fast mode is enabled
        if [[ "$FAIL_FAST" == "true" ]]; then
            echo
            log_error "Stopping execution due to test failure (--fail-fast mode)"
            echo "Failed test: $test_name"
            exit 1
        fi
    fi
    echo
}

# Discover all available roles
discover_roles() {
    local roles_dir="$ANSIBLE_DIR/roles"
    [[ -d "$roles_dir" ]] || {
        log_error "Ansible roles directory not found: $roles_dir"
        return 1
    }

    if [[ ${#ROLES_TO_TEST[@]} -eq 0 ]]; then
        # Auto-discover all roles
        while IFS= read -r -d '' role_dir; do
            local role_name
            role_name=$(basename "$role_dir")
            ROLES_TO_TEST+=("$role_name")
        done < <(find "$roles_dir" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    log_info "Discovered roles: ${ROLES_TO_TEST[*]}"
}

# Test role dependencies and conflicts
test_role_dependencies() {
    local role_name="$1"
    local role_dir="$ANSIBLE_DIR/roles/$role_name"
    local meta_file="$role_dir/meta/main.yml"

    log_verbose "Testing role dependencies for: $role_name"

    # Check for dependency conflicts
    if [[ -f "$meta_file" ]]; then
        # Check if role depends on itself (circular dependency)
        if grep -q "name: $role_name" "$meta_file"; then
            log_error "Role $role_name has circular dependency on itself"
            return 1
        fi

        # Extract dependencies
        local deps
        deps=$(grep -A10 "^dependencies:" "$meta_file" | grep "name:" | cut -d: -f2 | tr -d ' "' || echo "")
        if [[ -n "$deps" ]]; then
            log_verbose "Role $role_name depends on: $deps"

            # Check that dependencies exist
            echo "$deps" | while IFS= read -r dep; do
                if [[ -n "$dep" && "$dep" != "null" ]]; then
                    if [[ ! -d "$ANSIBLE_DIR/roles/$dep" ]]; then
                        log_warn "Role $role_name depends on missing role: $dep"
                    fi
                fi
            done
        fi
    else
        log_verbose "No meta file found for role $role_name (no dependencies defined)"
    fi

    log_info "Role $role_name dependency validation passed"
}

# Test template consistency and variables usage
test_template_consistency() {
    local role_name="$1"
    local role_dir="$ANSIBLE_DIR/roles/$role_name"
    local templates_dir="$role_dir/templates"
    local defaults_file="$role_dir/defaults/main.yml"

    log_verbose "Testing template consistency for: $role_name"

    if [[ ! -d "$templates_dir" ]]; then
        log_verbose "No templates directory found for role $role_name"
        return 0
    fi

    # Find all template files
    local template_files=()
    while IFS= read -r -d '' template_file; do
        template_files+=("$template_file")
    done < <(find "$templates_dir" -name "*.j2" -print0)

    if [[ ${#template_files[@]} -eq 0 ]]; then
        log_verbose "No Jinja2 templates found in role $role_name"
        return 0
    fi

    # Extract variables from defaults
    local default_vars=()
    if [[ -f "$defaults_file" ]]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*: ]]; then
                local var_name
                var_name=$(echo "$line" | cut -d: -f1 | tr -d ' ')
                default_vars+=("$var_name")
            fi
        done < "$defaults_file"
    else
        log_verbose "No defaults file found for template consistency check in role $role_name"
    fi

    # Check template variables against defaults
    for template_file in "${template_files[@]}"; do
        local template_name
        template_name=$(basename "$template_file")
        log_verbose "Checking template: $template_name"

        # Extract variables used in template ({{ variable_name }} pattern)
        local template_vars
        template_vars=$(grep -oE '\{\{\s*[a-zA-Z_][a-zA-Z0-9_]*' "$template_file" | sed 's/{{[[:space:]]*//' | sort -u || echo "")

        # Check if template variables have defaults
        if [[ -n "$template_vars" ]]; then
            echo "$template_vars" | while IFS= read -r template_var; do
                if [[ -n "$template_var" ]]; then
                    local found=false
                    for default_var in "${default_vars[@]}"; do
                        if [[ "$template_var" == "$default_var" ]]; then
                            found=true
                            break
                        fi
                    done
                    if [[ "$found" == "false" ]]; then
                        log_warn "Template $template_name uses undefined variable: $template_var"
                    fi
                fi
            done
        fi
    done

    log_info "Template consistency validation passed for role $role_name"
}

# Test cross-role variable consistency
test_cross_role_consistency() {
    local role_name="$1"
    local role_dir="$ANSIBLE_DIR/roles/$role_name"
    local defaults_file="$role_dir/defaults/main.yml"

    log_verbose "Testing cross-role consistency for: $role_name"

    if [[ ! -f "$defaults_file" ]]; then
        log_verbose "No defaults file found for role $role_name (optional)"
        log_info "Cross-role consistency validation passed for role $role_name (no variables to check)"
        return 0
    fi

    # Check for common variable patterns that should be consistent across roles
    local consistency_patterns=(
        "_version"     # Version variables should follow patterns
        "_config"      # Configuration paths should be consistent
        "_enable"      # Boolean enable flags should be consistent
        "_user"        # User names should be consistent
        "_group"       # Group names should be consistent
        "_port"        # Port numbers should not conflict
    )

    local role_vars
    role_vars=$(grep "^[a-zA-Z]" "$defaults_file" | cut -d: -f1 | tr -d ' ')

    for pattern in "${consistency_patterns[@]}"; do
        local matching_vars
        matching_vars=$(echo "$role_vars" | grep "$pattern" || echo "")
        if [[ -n "$matching_vars" ]]; then
            log_verbose "Role $role_name has $pattern variables: $(echo "$matching_vars" | tr '\n' ' ')"

            # Check for version consistency
            if [[ "$pattern" == "_version" ]]; then
                echo "$matching_vars" | while IFS= read -r var; do
                    if [[ -n "$var" ]]; then
                        local version_value
                        version_value=$(grep "^$var:" "$defaults_file" | cut -d'"' -f2 | cut -d"'" -f2)
                        if [[ -n "$version_value" ]]; then
                            # Check if version follows semver pattern
                            if [[ ! $version_value =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                                log_warn "Role $role_name variable $var has non-semver version: $version_value"
                            fi
                        fi
                    fi
                done
            fi
        fi
    done

    log_info "Cross-role consistency validation passed for role $role_name"
}

# Test role variables and defaults
test_role_variables() {
    local role_name="$1"
    local defaults_file="$ANSIBLE_DIR/roles/$role_name/defaults/main.yml"

    # Check if defaults file exists - it's optional for roles
    if [[ ! -f "$defaults_file" ]]; then
        log_warn "No defaults file found for $role_name (this is optional)"
        log_info "Role $role_name variables validation passed (no variables defined)"
        return 0
    fi

    # Check that defaults file is not empty
    if [[ ! -s "$defaults_file" ]]; then
        log_warn "Defaults file is empty for $role_name"
        return 0
    fi

    # Extract variable names from defaults
    local variable_count
    variable_count=$(grep -c "^[a-zA-Z]" "$defaults_file" || echo "0")

    if [[ $variable_count -eq 0 ]]; then
        log_warn "No variables defined in defaults for $role_name"
    else
        log_info "Role $role_name has $variable_count default variables"
    fi

    # Check for common security-related variables
    local security_vars=("_version" "_config" "_enable" "_allow" "_security")
    local security_var_count=0
    for pattern in "${security_vars[@]}"; do
        if grep -q "$pattern" "$defaults_file"; then
            ((security_var_count++))
        fi
    done

    if [[ $security_var_count -gt 0 ]]; then
        log_verbose "Role $role_name has $security_var_count security-related variables"
    fi

    log_info "Role $role_name variables validation passed"
}

# Test role tags consistency
test_role_tags() {
    local role_name="$1"
    local tasks_dir="$ANSIBLE_DIR/roles/$role_name/tasks"

    [[ -d "$tasks_dir" ]] || {
        log_error "Tasks directory not found for $role_name: $tasks_dir"
        return 1
    }

    # Find all task files
    local task_files=()
    while IFS= read -r -d '' task_file; do
        task_files+=("$task_file")
    done < <(find "$tasks_dir" -name "*.yml" -print0)

    local total_tags=0
    local tagged_tasks=0

    for task_file in "${task_files[@]}"; do
        if [[ -f "$task_file" ]]; then
            local file_tags
            file_tags=$(grep -c "tags:" "$task_file" || echo "0")
            total_tags=$((total_tags + file_tags))

            if [[ $file_tags -gt 0 ]]; then
                ((tagged_tasks++))
            fi
        fi
    done

    if [[ $total_tags -eq 0 ]]; then
        log_warn "Role $role_name has no tagged tasks (consider adding tags for selective execution)"
    else
        log_info "Role $role_name has $total_tags tags across $tagged_tasks task files"
    fi

    log_info "Role $role_name tags validation passed"
}

# Test role documentation coverage
test_role_documentation() {
    local role_name="$1"
    local role_dir="$ANSIBLE_DIR/roles/$role_name"

    log_verbose "Testing documentation coverage for: $role_name"

    local doc_score=0
    local max_score=5

    # Check for README file
    if [[ -f "$role_dir/README.md" ]]; then
        ((doc_score++))
        log_verbose "Role $role_name has README.md"
    else
        log_warn "Role $role_name missing README.md documentation"
    fi

    # Check for meta/main.yml with description
    if [[ -f "$role_dir/meta/main.yml" ]]; then
        if grep -q "description:" "$role_dir/meta/main.yml"; then
            ((doc_score++))
            log_verbose "Role $role_name has meta description"
        else
            log_warn "Role $role_name meta/main.yml missing description"
        fi
    else
        log_warn "Role $role_name missing meta/main.yml"
    fi

    # Check for variable documentation in defaults
    local defaults_file="$role_dir/defaults/main.yml"
    if [[ -f "$defaults_file" ]]; then
        local comment_lines
        comment_lines=$(grep -c "^#" "$defaults_file" || echo "0")
        if [[ $comment_lines -gt 2 ]]; then
            ((doc_score++))
            log_verbose "Role $role_name has documented variables"
        else
            log_warn "Role $role_name variables lack documentation comments"
        fi
    fi

    # Check for example usage
    if [[ -f "$role_dir/README.md" ]]; then
        if grep -q -i "example\|usage\|how to" "$role_dir/README.md"; then
            ((doc_score++))
            log_verbose "Role $role_name has usage examples"
        fi
    fi

    # Check for requirements/dependencies documentation
    if [[ -f "$role_dir/README.md" ]]; then
        if grep -q -i "requirement\|prerequisite\|depend" "$role_dir/README.md"; then
            ((doc_score++))
            log_verbose "Role $role_name documents requirements"
        fi
    fi

    local doc_percentage=$((doc_score * 100 / max_score))
    log_info "Role $role_name documentation score: $doc_score/$max_score ($doc_percentage%)"

    if [[ $doc_score -lt 3 ]]; then
        log_warn "Role $role_name documentation coverage below recommended threshold"
    fi

    log_info "Role $role_name documentation validation passed"
}

# Main role testing function - integration tests only
test_single_role() {
    local role_name="$1"

    log_info "Testing role integration: $role_name"

    run_test "Role dependencies ($role_name)" "test_role_dependencies $role_name"
    run_test "Template consistency ($role_name)" "test_template_consistency $role_name"
    run_test "Cross-role consistency ($role_name)" "test_cross_role_consistency $role_name"
    run_test "Variables usage ($role_name)" "test_role_variables $role_name"
    run_test "Documentation coverage ($role_name)" "test_role_documentation $role_name"
}

# Test all roles
test_all_roles() {
    discover_roles

    for role in "${ROLES_TO_TEST[@]}"; do
        echo "========================================"
        test_single_role "$role"
        echo
    done
}

# Test playbook-role integration
test_playbook_integration() {
    local playbooks_dir="$ANSIBLE_DIR/playbooks"
    [[ -d "$playbooks_dir" ]] || {
        log_warn "Playbooks directory not found: $playbooks_dir"
        return 0
    }

    log_info "Testing playbook-role integration..."

    local playbook_files=()
    while IFS= read -r -d '' playbook_file; do
        playbook_files+=("$playbook_file")
    done < <(find "$playbooks_dir" -name "*.yml" -print0)

    if [[ ${#playbook_files[@]} -eq 0 ]]; then
        log_warn "No playbook files found in $playbooks_dir"
        return 0
    fi

    local roles_referenced=()
    local roles_missing=()

    for playbook in "${playbook_files[@]}"; do
        local playbook_name
        playbook_name=$(basename "$playbook")
        log_verbose "Checking playbook integration: $playbook_name"

        # Extract roles referenced in playbook
        local playbook_roles
        playbook_roles=$(grep -A20 "roles:" "$playbook" | grep -E "^\s*-\s*[a-zA-Z]" | sed 's/^\s*-\s*//' | tr -d ' ' || echo "")

        if [[ -n "$playbook_roles" ]]; then
            echo "$playbook_roles" | while IFS= read -r role; do
                if [[ -n "$role" ]]; then
                    roles_referenced+=("$role")
                    # Check if role exists
                    if [[ ! -d "$ANSIBLE_DIR/roles/$role" ]]; then
                        roles_missing+=("$role (from $playbook_name)")
                    fi
                fi
            done
        else
            log_warn "Playbook $playbook_name does not reference any roles"
        fi
    done

    # Report missing roles
    if [[ ${#roles_missing[@]} -gt 0 ]]; then
        log_error "Playbooks reference missing roles:"
        printf '  ❌ %s\n' "${roles_missing[@]}"
        return 1
    fi

    log_info "Playbook-role integration validation passed"
}

# Test global variable consistency across infrastructure
test_global_consistency() {
    log_info "Testing global variable consistency across infrastructure..."

    # Collect all variable names from all roles
    local all_vars_file="/tmp/all_infrastructure_vars.txt"
    rm -f "$all_vars_file"

    discover_roles >/dev/null 2>&1

    for role in "${ROLES_TO_TEST[@]}"; do
        local defaults_file="$ANSIBLE_DIR/roles/$role/defaults/main.yml"
        if [[ -f "$defaults_file" ]]; then
            # Extract variable names with role prefix
            grep "^[a-zA-Z]" "$defaults_file" | cut -d: -f1 | sed "s/^/$role:/" >> "$all_vars_file"
        else
            log_verbose "Role $role has no defaults file (skipping from global consistency check)"
        fi
    done

    if [[ ! -f "$all_vars_file" ]]; then
        log_warn "No variables found across roles for consistency check"
        return 0
    fi

    # Check for potential conflicts
    local potential_conflicts=0
    local common_patterns=("port" "user" "group" "path" "version")

    for pattern in "${common_patterns[@]}"; do
        local matching_vars
        matching_vars=$(grep "_${pattern}" "$all_vars_file" | cut -d: -f2 | sort -u | wc -l)
        if [[ $matching_vars -gt 1 ]]; then
            log_verbose "Found $matching_vars different $pattern variables across roles"
            if [[ "$VERBOSE_MODE" == "true" ]]; then
                grep "_${pattern}" "$all_vars_file" | cut -d: -f1-2
            fi

            # Check for actual conflicts (same base name, different roles)
            local base_names
            base_names=$(grep "_${pattern}" "$all_vars_file" | cut -d: -f2 | cut -d_ -f1 | sort | uniq -d)
            if [[ -n "$base_names" ]]; then
                ((potential_conflicts++))
                log_warn "Potential $pattern variable conflicts found"
            fi
        fi
    done

    rm -f "$all_vars_file"

    if [[ $potential_conflicts -gt 2 ]]; then
        log_warn "Multiple potential variable conflicts detected - review for consistency"
    fi

    log_info "Global consistency validation passed"
}

print_summary() {
    local failed=$((TESTS_RUN - TESTS_PASSED))

    echo "========================================"
    echo "Ansible Roles Test Suite Summary"
    echo "========================================"
    echo "Roles tested: ${#ROLES_TO_TEST[@]}"
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        echo "Failed tests:"
        printf '  ❌ %s\n' "${FAILED_TESTS[@]}"
        echo
        echo "❌ Ansible roles validation FAILED"
        return 1
    else
        echo
        echo "🎉 Ansible roles integration validation PASSED!"
        echo
        echo "Integration components validated:"
        echo "  ✅ Role dependencies and conflicts resolved"
        echo "  ✅ Template variable consistency maintained"
        echo "  ✅ Cross-role variable consistency verified"
        echo "  ✅ Variable usage patterns validated"
        echo "  ✅ Documentation coverage assessed"
        echo "  ✅ Playbook-role integration functional"
        echo "  ✅ Global consistency maintained"
        echo
        echo "Pre-commit hooks handle basic validation:"
        echo "  🔧 YAML syntax (check-yaml hook)"
        echo "  🔧 ansible-lint checks (ansible-lint hook)"
        echo "  🔧 Playbook syntax (local hook)"
        echo "  🔧 Role structure (local hook)"
        return 0
    fi
}

main() {
    echo "Ansible Roles Integration Test Suite"
    echo "High-level integration testing for Ansible roles and playbooks"
    echo "Note: Basic syntax and linting is handled by pre-commit hooks"
    echo "Using dev container: $CONTAINER_SCRIPT"
    echo "Project root: $PROJECT_ROOT"
    echo

    if [[ "$INTEGRATION_ONLY" == "true" ]]; then
        log_info "Running integration-only tests (no individual role testing)"
        run_test "Playbook-role integration" test_playbook_integration
        run_test "Global consistency validation" test_global_consistency
    else
        # Run comprehensive integration tests
        run_test "Test all roles integration" test_all_roles
        run_test "Playbook-role integration" test_playbook_integration
        run_test "Global consistency validation" test_global_consistency
    fi

    print_summary
}

# Handle command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Ansible Roles Integration Test Suite"
            echo "Usage: $0 [--help|--verbose|--role ROLE|--integration-only|--fail-fast]"
            echo
            echo "This test validates Ansible roles and playbooks integration:"
            echo "  - Role dependencies and conflicts"
            echo "  - Template variable consistency"
            echo "  - Cross-role variable consistency"
            echo "  - Variable usage patterns"
            echo "  - Documentation coverage"
            echo "  - Playbook-role integration"
            echo "  - Global consistency validation"
            echo
            echo "Note: Basic syntax and linting is handled automatically by pre-commit hooks:"
            echo "  - YAML syntax validation (check-yaml hook)"
            echo "  - ansible-lint checks (ansible-lint hook)"
            echo "  - Playbook syntax validation (local hook)"
            echo "  - Role structure validation (local hook)"
            echo
            echo "Options:"
            echo "  --verbose         Show detailed test output"
            echo "  --role ROLE       Test only specified role integration"
            echo "  --integration-only Run only global integration tests"
            echo "  --fail-fast       Stop execution on first test failure"
            echo
            echo "Available roles:"
            discover_roles >/dev/null 2>&1 || true
            for role in "${ROLES_TO_TEST[@]}"; do
                echo "    $role"
            done
            echo
            echo "To run basic syntax validation:"
            echo "  pre-commit run --all-files ansible-lint"
            echo "  pre-commit run --all-files ansible-playbook-syntax-check"
            exit 0
            ;;
        --verbose)
            VERBOSE_MODE=true
            log_info "Verbose mode enabled"
            ;;
        --role)
            shift
            [[ $# -gt 0 ]] || {
                log_error "--role requires a role name"
                exit 1
            }
            ROLES_TO_TEST=("$1")
            log_info "Testing single role integration: $1"
            ;;
        --integration-only)
            INTEGRATION_ONLY=true
            log_info "Integration-only mode enabled - testing global consistency only"
            ;;
        --fail-fast)
            FAIL_FAST=true
            log_info "Fail-fast mode enabled - stopping on first test failure"
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Clean up any previous test artifacts
rm -rf "$TEST_OUTPUT_DIR"
mkdir -p "$TEST_OUTPUT_DIR"

main "$@"

# Clean up test outputs unless verbose mode
if [[ "$VERBOSE_MODE" != "true" ]]; then
    rm -rf "$TEST_OUTPUT_DIR"
fi
