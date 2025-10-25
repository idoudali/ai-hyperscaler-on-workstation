# Ansible Debugging Guide

**Last Updated:** 2025-10-26

Complete guide to debugging Ansible playbooks, understanding task skipping, and troubleshooting execution issues.

## Quick Reference

| What You Want | Command/Setting |
|---------------|----------------|
| See skipped tasks | `display_skipped_hosts = True` in ansible.cfg |
| See why tasks skip | `ansible-playbook -vvv` |
| See all task output | `display_ok_hosts = True` in ansible.cfg |
| Debug specific task | Add `debugger: on_failed` or `on_skipped` |
| Check variable values | `ansible-playbook --start-at-task="task name" -vvv` |
| See task arguments | `display_args_to_stdout = True` in ansible.cfg |

## 1. Configuration Settings (ansible.cfg)

### Current Settings

```ini
# ansible/ansible.cfg

[defaults]
# DEBUG: Display all task execution (including skipped)
display_skipped_hosts = True   # ← CHANGED: Show skipped tasks in output
display_ok_hosts = True         # ← CHANGED: Show successful tasks

# Additional debug options (uncomment as needed):
# display_args_to_stdout = False  # Show task arguments
# verbosity = 0                   # Set to 1-4 for more details
```

### What Each Setting Does

```yaml
display_skipped_hosts: True
  # Before: TASK [name] ***  (nothing shown if skipped)
  # After:  skipping: [hostname] => (item=value)

display_ok_hosts: True
  # Before: TASK [name] ***  (nothing shown if ok)
  # After:  ok: [hostname] => (item=value)

display_args_to_stdout: True
  # Shows the actual arguments passed to each task
  # Example: TASK [debug] *** (msg="Hello World", var="test")
```

## 2. Verbosity Levels (-v, -vv, -vvv, -vvvv)

### Usage

```bash
# Level 1: Show task results
ansible-playbook playbook.yml -v

# Level 2: Show task input/output
ansible-playbook playbook.yml -vv

# Level 3: Show task execution details (including skip reasons)
ansible-playbook playbook.yml -vvv

# Level 4: Show connection debugging
ansible-playbook playbook.yml -vvvv
```

### What Each Level Shows

#### `-v` (Level 1)

```text
TASK [Check file exists] ***
ok: [host1] => {"changed": false, "stat": {"exists": true}}
```

#### `-vv` (Level 2)

```text
TASK [Check file exists] ***
task path: /path/to/role/tasks/main.yml:42
ok: [host1] => {"changed": false, "stat": {"exists": true, "path": "/etc/config"}}
```

#### `-vvv` (Level 3) - **MOST USEFUL FOR DEBUGGING SKIPPED TASKS**

```text
TASK [Install package] ***
task path: /path/to/role/tasks/main.yml:52
skipping: [host1] => {
    "changed": false,
    "skip_reason": "Conditional check failed",
    "skipped": true
}
```

#### `-vvvv` (Level 4)

```text
(Shows SSH commands, connection details, raw module output)
```

## 3. Understanding Why Tasks Are Skipped

### Common Skip Reasons

#### 1. **`when` Condition Failed**

```yaml
- name: Install package
  apt:
    name: nginx
  when: ansible_os_family == "Debian"
```

**Debug with `-vvv`:**

```text
skipping: [host1] => {
    "changed": false,
    "skip_reason": "Conditional result was False"
}
```

**How to debug:**

```bash
# Check the variable value
ansible all -i inventory -m debug -a "var=ansible_os_family"

# Or add a debug task before:
- name: DEBUG - Show OS family
  debug:
    var: ansible_os_family
```

#### 2. **Tag Filtering** (Our BeeGFS Issue!)

```yaml
- name: Check something
  stat:
    path: /file
  register: check_result
  tags: [check]  # ← Missing 'install' tag

- name: Install something
  apt:
    name: package
  when: check_result.stat.exists
  tags: [install]  # ← Has 'install' tag
```

**When running:** `ansible-playbook playbook.yml --tags install`

- First task skipped (no 'install' tag)
- `check_result` is undefined
- Second task skipped (undefined variable evaluates as False)

**How to debug:**

```bash
# See which tasks would run with specific tags
ansible-playbook playbook.yml --tags install --list-tasks

# Run with all tags to see everything
ansible-playbook playbook.yml --tags all -vvv
```

#### 3. **Undefined Variable**

```yaml
- name: Do something
  command: echo "test"
  when: my_undefined_var | default(false)
```

**Debug with `-vvv`:**

```text
skipping: [host1] => {
    "skip_reason": "Conditional result was False"
}
```

**How to debug:**

```yaml
# Add debug task to check if variable exists
- name: DEBUG - Check variable
  debug:
    msg: "Variable defined: {{ my_var is defined }}, Value: {{ my_var | default('UNDEFINED') }}"
```

#### 4. **Item Loop with No Matches**

```yaml
- name: Process files
  file:
    path: "{{ item }}"
    state: directory
  loop: "{{ files_list }}"
  when: item != ""
```

**Debug with `-vvv`:**

```text
skipping: [host1] => (item=)
skipping: [host1] => (item=)
```

## 4. Advanced Debugging Techniques

### Method 1: Interactive Debugger

```yaml
- name: Task to debug
  command: some_command
  debugger: on_skipped  # or: on_failed, always, never
```

**When task skips, you get interactive prompt:**

```python
[host1] TASK: Task to debug (debug)> p task.args
[host1] TASK: Task to debug (debug)> p task_vars['my_variable']
[host1] TASK: Task to debug (debug)> c  # continue
```

### Method 2: Assert Module for Validation

```yaml
- name: Validate prerequisites
  assert:
    that:
      - my_var is defined
      - my_var != ""
      - my_list | length > 0
    fail_msg: "Prerequisites not met: my_var={{ my_var | default('UNDEFINED') }}"
    success_msg: "All prerequisites OK"
```

### Method 3: Debug Task to Show Variables

```yaml
- name: DEBUG - Show all registered variables
  debug:
    msg: |
      beegfs_client_installed: {{ beegfs_client_installed | default('UNDEFINED') }}
      beegfs_kernel_module_early_check: {{ beegfs_kernel_module_early_check | default('UNDEFINED') }}
      packages_dir_check: {{ packages_dir_check | default('UNDEFINED') }}
  tags: [debug, always]  # ← always tag means it runs regardless
```

### Method 4: Check Task Execution with --step

```bash
# Prompts before each task
ansible-playbook playbook.yml --step
```

### Method 5: Start from Specific Task

```bash
# Skip earlier tasks
ansible-playbook playbook.yml --start-at-task="Install packages"
```

### Method 6: Check Variable State with ansible Command

```bash
# Check single variable
ansible all -i inventory -m debug -a "var=ansible_kernel"

# Check multiple facts
ansible all -i inventory -m setup -a "filter=ansible_os*"

# Check custom variable from inventory
ansible all -i inventory -m debug -a "var=hostvars[inventory_hostname]"
```

## 5. Common Debugging Workflow

### Step 1: Enable Verbose Output

```bash
# Edit ansible.cfg
display_skipped_hosts = True
display_ok_hosts = True
```

### Step 2: Run with Verbosity

```bash
ansible-playbook playbook.yml -vvv 2>&1 | tee debug.log
```

### Step 3: Search Log for Skip Reasons

```bash
# Find all skipped tasks
grep -A 5 "skipping:" debug.log

# Find specific task
grep -B 5 -A 10 "TASK \[Your Task Name\]" debug.log

# Find skip reasons
grep "skip_reason" debug.log
```

### Step 4: Check Variable Registration

```yaml
- name: DEBUG - Check if variables are registered
  debug:
    msg:
      - "Variable name: {{ var_name is defined }}"
      - "Value: {{ var_name | default('NOT DEFINED') }}"
      - "Type: {{ var_name | type_debug }}"
  tags: [debug, always]
```

### Step 5: Validate `when` Conditions

```yaml
- name: DEBUG - Test condition
  debug:
    msg: "Condition would be: {{ (condition_expression) | bool }}"
  tags: [debug, always]
```

## 6. Real Example: Debugging Our BeeGFS Issue

### The Problem

```yaml
# Check task (line 45 in install.yml)
- name: Check if BeeGFS kernel module exists
  find:
    paths: "/lib/modules/{{ ansible_kernel }}"
    patterns: "beegfs.ko*"
  register: beegfs_kernel_module_early_check
  tags: [beegfs, beegfs-client, check]  # ← Missing 'install' tag!

# Install task (line 148)
- name: Install packages
  apt:
    name: beegfs-client
  when: (beegfs_kernel_module_early_check.matched | default(0)) == 0
  tags: [beegfs, beegfs-client, install]
```

### How to Debug This

```bash
# 1. Run with verbosity to see skip reasons
ansible-playbook playbook.yml --tags install -vvv

# Output shows:
# TASK [Check if BeeGFS kernel module exists] ***
# (nothing - task was filtered out by tags)
#
# TASK [Install packages] ***
# skipping: [host] => {
#     "skip_reason": "Conditional result was False"
# }
```

```bash
# 2. Check which tasks would run with 'install' tag
ansible-playbook playbook.yml --tags install --list-tasks

# Output shows:
# TASK: Update apt cache...
# TASK: Install packages
# TASK: FAIL if module not built
# (Notice: Check task NOT listed!)
```

```bash
# 3. Add debug task to show variable state
- name: DEBUG - Check variable registration
  debug:
    msg: >-
      beegfs_kernel_module_early_check is
      {{ 'defined' if beegfs_kernel_module_early_check is defined else 'UNDEFINED' }}
  tags: [beegfs, beegfs-client, install, debug]

# Output shows:
# ok: [host] => {
#     "msg": "beegfs_kernel_module_early_check is UNDEFINED"
# }
```

### The Fix

```yaml
# Add 'install' tag to check task so it runs with install tasks
- name: Check if BeeGFS kernel module exists
  find:
    paths: "/lib/modules/{{ ansible_kernel }}"
    patterns: "beegfs.ko*"
  register: beegfs_kernel_module_early_check
  tags: [beegfs, beegfs-client, install, check]  # ← Added 'install' tag
```

## 7. Best Practices

### DO:

- ✅ Set `display_skipped_hosts = True` during development
- ✅ Use `-vvv` when debugging unexpected behavior
- ✅ Add debug tasks with `tags: [debug, always]`
- ✅ Use `assert` to validate prerequisites early
- ✅ Give check tasks the same tags as tasks that depend on them
- ✅ Use descriptive task names that appear clearly in logs
- ✅ Log output to files: `ansible-playbook ... 2>&1 | tee log.txt`

### DON'T:

- ❌ Run with `display_skipped_hosts = False` when debugging
- ❌ Assume undefined variables will fail loudly
- ❌ Use `ignore_errors: true` without understanding why it failed
- ❌ Mix tasks with incompatible tags when they have dependencies
- ❌ Use `failed_when: false` to hide problems
- ❌ Forget to check tag filtering when tasks mysteriously skip

## 8. Quick Debugging Checklist

When a task unexpectedly skips:

```text
□ Is display_skipped_hosts = True in ansible.cfg?
□ Did I run with -vvv to see skip reason?
□ Does the task have compatible tags with my --tags filter?
□ Are all variables in the 'when' condition defined?
□ Did previous tasks that register variables actually run?
□ Is the 'when' condition syntactically correct?
□ Are there conflicting conditions (e.g., var == true AND var == false)?
□ Is the task in a block with a parent 'when' condition?
□ Did I check the actual variable values with debug?
□ Is there a parent include/import with a 'when' condition?
```

## 9. Useful Ansible Commands

```bash
# List all tasks in playbook
ansible-playbook playbook.yml --list-tasks

# List tasks that would run with specific tags
ansible-playbook playbook.yml --tags install --list-tasks

# Dry run (check mode)
ansible-playbook playbook.yml --check

# Show differences (what would change)
ansible-playbook playbook.yml --check --diff

# Limit to specific hosts
ansible-playbook playbook.yml --limit hostname

# Show all variables for a host
ansible all -i inventory -m debug -a "var=hostvars[inventory_hostname]"

# Test connection to hosts
ansible all -i inventory -m ping

# Get facts from hosts
ansible all -i inventory -m setup
```

## 10. References

- [Ansible Debugging Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html)
- [Ansible Verbosity](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-verbosity)
- [Ansible Tags](https://docs.ansible.com/ansible/latest/user_guide/playbooks_tags.html)
- [Ansible Conditionals](https://docs.ansible.com/ansible/latest/user_guide/playbooks_conditionals.html)

---

**Related Issues:** BeeGFS client installation tag filtering (ansible-deploy.log)
