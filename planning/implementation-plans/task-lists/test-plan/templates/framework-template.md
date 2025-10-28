# Test Framework Template

## Overview

This document provides a template for creating new test framework documentation following the standardized format used
throughout the HPC SLURM test infrastructure.

## Template Usage

1. Copy this template when creating documentation for a new test framework
2. Replace all `[PLACEHOLDER]` values with actual content
3. Remove sections that don't apply
4. Follow the structure to maintain consistency

---

## [Framework Name] Test Framework

### Purpose

[Describe the purpose of this test framework in 1-2 sentences. What does it validate?]

### Scope

**Components Tested**:

- [Component 1] - [Brief description]
- [Component 2] - [Brief description]
- [Component 3] - [Brief description]

**Test Type**: [Packer Image Validation | Runtime Configuration | Storage | Hardware | Integration]

**Deployment Phase**: [Packer Build | Ansible Runtime | End-to-End]

### Configuration

**Location**: `tests/test-infra/configs/[config-file].yaml`

**Key Settings**:

```yaml
cluster:
  name: [test-cluster-name]
  controller_count: [number]
  compute_count: [number]

images:
  controller: [controller-image].qcow2
  compute: [compute-image].qcow2

resources:
  controller_cpus: [number]
  controller_memory: [number in MB]
  compute_cpus: [number]
  compute_memory: [number in MB]

test_options:
  [option_name]: [value]
  [option_name]: [value]
```

### Test Suites

#### Test Suite 1: [Suite Name]

**Location**: `tests/suites/[suite-directory]/`

**Purpose**: [What this test suite validates]

**Test Scripts**:
| Script | Validates | Auto |
|--------|-----------|------|
| `[script-name].sh` | [What it tests] | ✅/❌ |
| `[script-name].sh` | [What it tests] | ✅/❌ |
| `[script-name].sh` | [What it tests] | ✅/❌ |

#### Test Suite 2: [Suite Name]

[Repeat structure for each test suite]

### CLI Interface

#### Standard Commands

```bash
# Complete end-to-end test with cleanup
./test-[framework-name]-framework.sh e2e

# Modular workflow for debugging
./test-[framework-name]-framework.sh start-cluster
./test-[framework-name]-framework.sh deploy-ansible
./test-[framework-name]-framework.sh run-tests
./test-[framework-name]-framework.sh stop-cluster

# List available tests
./test-[framework-name]-framework.sh list-tests

# Run specific test
./test-[framework-name]-framework.sh run-test [test-name].sh

# Show cluster status
./test-[framework-name]-framework.sh status

# Display help
./test-[framework-name]-framework.sh --help
```

#### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --verbose` | Enable verbose output |
| `--no-cleanup` | Skip cleanup after tests |
| `--interactive` | Enable interactive prompts |

### Implementation Details

**File**: `tests/test-[framework-name]-framework.sh`

**Size**: ~[number]K lines

**Dependencies**:

- `tests/test-infra/utils/test-framework-utils.sh` - Common utilities
- `tests/test-infra/utils/framework-cli.sh` - CLI handling
- `tests/test-infra/utils/framework-orchestration.sh` - Orchestration

**Ansible Playbook**: `ansible/playbooks/[playbook-name].yml`

**Key Functions**:

```bash
# Main test execution function
run_[component]_tests() {
    # Test execution logic
}

# [Add other key functions]
```

### Execution Time

**Estimated Duration**: [time range] minutes

**Breakdown**:

- Cluster startup: ~[number] minutes
- Ansible deployment: ~[number] minutes
- Test execution: ~[number] minutes
- Cleanup: ~[number] minutes

### Prerequisites

**Required**:

- [Prerequisite 1]
- [Prerequisite 2]
- [Prerequisite 3]

**Optional**:

- [Optional prerequisite 1]
- [Optional prerequisite 2]

### Validation Criteria

**Must Pass**:

- [ ] [Validation criterion 1]
- [ ] [Validation criterion 2]
- [ ] [Validation criterion 3]

**Should Pass**:

- [ ] [Nice-to-have validation 1]
- [ ] [Nice-to-have validation 2]

### Known Limitations

- [Limitation 1 and workaround if any]
- [Limitation 2 and workaround if any]

### Troubleshooting

#### Issue 1: [Common Issue]

**Symptoms**: [How to recognize this issue]

**Cause**: [What causes this issue]

**Solution**: [How to fix it]

#### Issue 2: [Another Issue]

[Repeat structure for each common issue]

### Examples

#### Example 1: [Use Case Name]

```bash
# [Description of what this example demonstrates]
[commands]
```

**Expected Output**:

```text
[Show expected output]
```

#### Example 2: [Another Use Case]

[Repeat structure for each example]

### Integration

**Integrates With**:

- [Other framework or component 1]
- [Other framework or component 2]

**Required By**:

- [Framework or process that depends on this]

**Follows**:

- [Framework that should run before this one]

### Makefile Target

```makefile
# Add to tests/Makefile
test-[framework-name]:
\t./test-[framework-name]-framework.sh e2e
```

**Usage**:

```bash
make test-[framework-name]
```

### Documentation References

- Main test documentation: `tests/README.md`
- Component matrix: `task-lists/test-plan/02-component-matrix.md`
- Framework specifications: `task-lists/test-plan/03-framework-specifications.md`
- [Component-specific documentation]

### Change History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| YYYY-MM-DD | 1.0 | Initial creation | [Name] |
| YYYY-MM-DD | 1.1 | [Changes made] | [Name] |

---

## Template Checklist

When using this template, ensure you:

- [ ] Replace all [PLACEHOLDER] values
- [ ] Remove unused sections
- [ ] Update CLI examples with actual commands
- [ ] Add actual test scripts to test suite tables
- [ ] Document all configuration options
- [ ] Include troubleshooting for common issues
- [ ] Add integration information
- [ ] Update change history
- [ ] Review for consistency with other framework docs
- [ ] Test all examples before publishing

---

## Notes

- Keep documentation concise and actionable
- Use consistent terminology across all framework docs
- Include examples for common use cases
- Document known limitations and workarounds
- Update documentation when framework changes
