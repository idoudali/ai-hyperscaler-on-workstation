# Cursor Agent Whitelist Configuration

This document explains the `.cursor/agent-allow-reference.yaml` configuration file and how to use it to control
@Cursor Background Agent permissions and operations.

## Important Note: Cursor's Official Rules System

**Official Cursor Approach:**  
Cursor uses a `.cursor/rules/` directory where each rule is a **Markdown file with YAML frontmatter** (typically
`.mdc` extension). The official documentation is at [docs.cursor.com/context/rules](https://docs.cursor.com/context/rules).

**This YAML Configuration:**  
The `.cursor/agent-allow-reference.yaml` file provided here is a **comprehensive reference template** that documents
best practices and permission structures in a centralized format. While Cursor's native system uses individual
Markdown rule files (`.mdc`), this YAML template serves as:

- A **single source of truth** for your agent permission policies
- A **reference guide** for creating individual `.cursor/rules/*.mdc` files
- A **planning document** before implementing granular rules

**Implementation Approaches:**

1. **Use this YAML as reference** to create individual Markdown rule files in `.cursor/rules/`
2. **Maintain this YAML** as documentation alongside native Cursor rules
3. **Convert sections** of this YAML into specific Cursor rule files as needed

See the [Official Cursor Documentation](#official-cursor-documentation) section for links to Cursor's native rules
system.

## Overview

The `.cursor/agent-allow-reference.yaml` file defines a comprehensive whitelist of allowed operations, commands, and
file access for @Cursor Background Agents. This provides fine-grained control over what the agent can and cannot do
in your project.

## Configuration Structure

### Permissions

Basic permission flags that control agent capabilities:

- `read`: Allow reading files
- `write`: Allow modifying files
- `execute`: Allow executing commands
- `create`: Allow creating new files
- `delete`: Allow deleting files (disabled by default for safety)

### Models

Define which AI models the agent can use:

```yaml
models:
  allowed:
    - claude-sonnet-4.5
    - gpt-4
  default: claude-sonnet-4.5
```

### File System Access Control

Control which files and directories the agent can access:

- `allowed_paths`: Directories the agent can read/write
- `denied_paths`: Explicitly blocked paths (overrides allowed_paths)
- `protected_files`: Files requiring explicit approval before modification

#### Path Patterns

Use glob patterns for flexible path matching:

- `**` - Match any number of directories
- `*` - Match any characters in a directory/file name
- Examples:
  - `docs/**` - All files in docs directory and subdirectories
  - `*.md` - All markdown files in current directory
  - `**/*.py` - All Python files anywhere in the project

### Command Whitelists

Define allowed commands by category:

#### Docker Commands

```yaml
docker:
  allowed: true
  whitelist:
    - "make build-docker"
    - "make run-docker COMMAND=*"
  denied:
    - "docker system prune"
```

#### Git Commands

```yaml
git:
  allowed: true
  whitelist:
    - "git status"
    - "git commit -m *"
  denied:
    - "git push --force"
    - "git reset --hard"
```

#### Infrastructure Commands

Separate controls for Terraform, Ansible, and Packer commands.

### Safety Features

Multiple safety mechanisms to prevent accidental damage:

- `confirm_destructive`: Require confirmation for destructive operations
- `dry_run`: Preview changes without applying them
- `max_files_per_session`: Limit number of files modified in one session
- `max_commands_per_session`: Limit number of commands executed
- `operation_timeout`: Timeout for long-running operations (in minutes)

### Project-Specific Rules

Custom rules aligned with your project workflow:

#### Infrastructure as Code

```yaml
iac:
  validate_before_commit: true
  auto_lint: true
  secret_detection: true
```

#### Documentation

```yaml
documentation:
  auto_update_docs: true
  docs_paths:
    - "docs/**"
  markdown_lint: true
```

#### Container Builds

```yaml
containers:
  use_dev_container: true
  container_script: "./scripts/run-in-dev-container.sh"
```

## Creating Cursor Rules from This Template

To implement these permissions using Cursor's official rules system, create Markdown files in `.cursor/rules/`:

### Example 1: Protect Critical Files

Create `.cursor/rules/protect-config-files.md`:

```markdown
---
description: Prevent modification of critical configuration files
globs: 
  - "Makefile"
  - "CMakeLists.txt"
  - "package.json"
  - ".gitignore"
alwaysApply: true
---

# Protected Configuration Files

The following files are critical to the project and require explicit approval before modification:

- **Makefile**: Build system configuration
- **CMakeLists.txt**: CMake build configuration
- **package.json**: Node.js dependencies
- **.gitignore**: Git ignore patterns

Please request explicit permission before modifying these files.
```

### Example 2: Container Build Requirements

Create `.cursor/rules/container-builds.md`:

```markdown
---
description: All build commands must use development container
globs: "**/*.{tf,yml,yaml}"
alwaysApply: true
---

# Container Build Requirements

All build operations MUST be executed inside the development container:

- Use `make run-docker COMMAND="..."` for build commands
- Use `./scripts/run-in-dev-container.sh` for interactive sessions
- Never run build commands directly on the host

## Allowed Container Commands

- `make build-docker` - Build development container
- `make shell-docker` - Interactive container shell
- `make run-docker COMMAND="..."` - Execute command in container
```

### Example 3: Git Safety Rules

Create `.cursor/rules/git-safety.md`:

```markdown
---
description: Prevent destructive git operations
globs: "**/*"
alwaysApply: true
---

# Git Safety Rules

## Prohibited Commands

Never execute the following destructive git commands:

- `git push --force` or `git push -f`
- `git reset --hard`
- `git clean -fd`
- `git rebase` (without explicit approval)

## Allowed Commands

Safe git operations include:

- `git status`, `git diff`, `git log`
- `git add`, `git commit`
- `git checkout -b <branch-name>`
- `git stash`, `git stash pop`
```

### Example 4: Infrastructure Validation

Create `.cursor/rules/iac-validation.md`:

```markdown
---
description: Validate infrastructure code before committing
globs:
  - "terraform/**/*.tf"
  - "ansible/**/*.yml"
  - "packer/**/*.pkr.hcl"
alwaysApply: true
---

# Infrastructure as Code Validation

Before committing any infrastructure code changes:

1. **Run validation**: `terraform validate`, `ansible-lint`, `packer validate`
2. **Check formatting**: `terraform fmt`, `ansible-playbook --syntax-check`
3. **Scan for secrets**: Ensure no secrets are hardcoded
4. **Update documentation**: Reflect changes in `/docs`

## Terraform Safety

- ❌ Never run `terraform apply` without explicit approval
- ❌ Never run `terraform destroy` 
- ✅ Always run `terraform plan` first
- ✅ Use `terraform fmt` before committing

## Ansible Safety

- ❌ Never run playbooks without `--check` flag first
- ✅ Always use `ansible-playbook --syntax-check`
- ✅ Use `ansible-lint` to catch issues
```

## Usage

### 1. Basic Usage - Official Cursor Rules

Create rules in `.cursor/rules/` directory as shown above. Cursor will automatically load and enforce them.

### 2. Using the YAML Template as Reference

Edit `.cursor/agent-allow-reference.yaml` to plan and document your permission policies:

```bash
# Open configuration in your editor
code .cursor/agent-allow-reference.yaml
```

### 3. Migration Guide: YAML to Cursor Rules

To migrate this YAML template to actual Cursor rules:

#### Step 1: Create Rules Directory

```bash
mkdir -p .cursor/rules
```

#### Step 2: Convert YAML Sections to Rule Files

For each major section in the YAML (filesystem, commands, safety), create a corresponding rule file:

**Command Whitelist → Rule File:**

```bash
# From YAML section:
# commands:
#   docker:
#     allowed: true
#     whitelist:
#       - "make build-docker"

# Create: .cursor/rules/docker-commands.md
cat > .cursor/rules/docker-commands.md << 'EOF'
---
description: Docker command restrictions
globs: "**/*"
alwaysApply: true
---

# Docker Command Whitelist

Allowed Docker commands:
- `make build-docker`
- `make shell-docker`
- `make run-docker COMMAND=*`

Denied commands:
- `docker system prune`
- `docker rm -f`
EOF
```

#### Step 3: Verify Rules

Check that Cursor loads your rules:

1. Open Cursor settings
2. Navigate to Rules section
3. Verify your `.cursor/rules/*.md` files are listed
4. Test with a simple agent command

### 4. Testing Configuration

To test if a rule is working:

1. Ask agent to perform an operation that should be restricted
2. Verify agent respects the rule
3. Check rule appears in agent's context
4. Review Cursor logs for rule enforcement

### 5. Temporary Overrides

For one-time operations requiring different permissions:

1. Temporarily modify or rename the rule file
2. Run the agent operation
3. Restore the original rule

### 6. Multiple Environments

Create environment-specific rule sets:

```bash
.cursor/rules/
├── common/              # Always applied
│   ├── git-safety.md
│   └── protect-config.md
├── dev/                 # Development-specific
│   ├── allow-experiments.md
│   └── relaxed-tests.md
└── prod/                # Production-specific
    ├── strict-validation.md
    └── require-reviews.md
```

Symlink appropriate environment:

```bash
# Development
ln -sf dev/* .cursor/rules/

# Production
ln -sf prod/* .cursor/rules/
```

## Best Practices

### Security

- Keep `delete` permission disabled unless absolutely necessary
- Always deny destructive git commands (`push --force`, `reset --hard`)
- Protect sensitive files and directories (`.env`, `secrets/`, `.git/`)
- Enable `secret_detection` for infrastructure code
- Review denied commands regularly

### File Access

- Use the most specific path patterns possible
- Deny build artifacts and dependencies (`node_modules/`, `build/`, `venv/`)
- Protect configuration files that affect agent behavior
- Regularly audit `allowed_paths` to ensure minimal access

### Commands

- Whitelist specific command patterns rather than wildcards
- Require approval for infrastructure changes (Terraform apply, Ansible playbook runs)
- Allow validation and checking commands freely
- Deny system-level commands that could affect host

### Rate Limiting

- Set appropriate rate limits for your project size
- Monitor agent.log for rate limit violations
- Adjust limits if agent is frequently throttled

### Logging

- Keep logging enabled at `info` level or higher
- Review logs periodically for unusual activity
- Increase to `debug` level when troubleshooting
- Set appropriate retention period for your needs

## Common Scenarios

### Allow Agent to Update Documentation

```yaml
filesystem:
  allowed_paths:
    - "docs/**"
    - "README.md"
    - "*.md"
```

### Allow Agent to Run Tests

```yaml
commands:
  testing:
    allowed: true
    whitelist:
      - "pytest *"
      - "npm test"
      - "make test"
```

### Allow Agent to Format Code

```yaml
commands:
  formatting:
    allowed: true
    whitelist:
      - "terraform fmt"
      - "black *.py"
      - "prettier --write *.js"
```

### Restrict Agent to Read-Only Mode

```yaml
permissions:
  read: true
  write: false
  execute: false
  create: false
  delete: false
```

## Troubleshooting

### Agent Cannot Perform Operation

1. Check if the operation is whitelisted in the relevant section
2. Verify the file/path is in `allowed_paths` and not in `denied_paths`
3. Review the agent log for specific permission denial messages
4. Temporarily enable debug logging to see detailed permission checks

### Agent Exceeds Rate Limits

1. Review current rate limit settings
2. Check agent.log for frequency of operations
3. Increase limits if agent is performing legitimate operations
4. Investigate if agent is stuck in a loop

### Protected File Modifications

If agent needs to modify a protected file:

1. Temporarily remove file from `protected_files` list
2. Have agent perform the operation
3. Review changes carefully
4. Re-add file to protected list

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Validate Cursor Agent Config
  run: |
    # Validate YAML syntax
    yamllint .cursor/agent-allow-reference.yaml
```

### Pre-commit Hooks

```bash
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-cursor-agent-config
        name: Validate Cursor Agent Config
        entry: yamllint .cursor-agent-allow.yaml
        language: system
```

## Version History

- `1.0` - Initial whitelist configuration with comprehensive controls

## Support

For issues or questions about the Cursor Agent whitelist configuration:

1. Review this documentation
2. Check the agent log at `.cursor/agent.log`
3. Consult Cursor documentation
4. Open an issue in the project repository

## Quick Reference: YAML vs Cursor Rules

### Format Comparison

**YAML Template (This Project):**

```yaml
# .cursor/agent-allow-reference.yaml
permissions:
  read: true
  write: true
  
filesystem:
  allowed_paths:
    - "docs/**"
  denied_paths:
    - "**/.git/**"
    
commands:
  git:
    whitelist:
      - "git status"
    denied:
      - "git push --force"
```

**Cursor Official Rules:**

```markdown
<!-- .cursor/rules/git-safety.md -->
---
description: Git command safety rules
globs: "**/*"
alwaysApply: true
---

# Git Safety

Never use destructive commands:
- `git push --force`

Safe commands:
- `git status`
```

### Conversion Table

| YAML Section | Cursor Rule Approach |
|--------------|---------------------|
| `permissions` | Document in rule content with "allowed" / "prohibited" lists |
| `filesystem.allowed_paths` | Use `globs` in frontmatter to specify file patterns |
| `filesystem.denied_paths` | Create rules stating "do not modify" for those patterns |
| `commands.*.whitelist` | List allowed commands in rule markdown content |
| `commands.*.denied` | List prohibited commands in rule markdown content |
| `protected_files` | Create rule with specific globs and "require approval" text |
| `safety.confirm_destructive` | Document in rule: "require explicit confirmation" |

### When to Use Each

**Use YAML Template:**

- Planning comprehensive permission policies
- Documenting overall security strategy
- Reference guide for team members
- Central policy documentation

**Use Cursor Rules:**

- Active enforcement by Cursor agent
- Context-specific restrictions
- File-pattern-based rules
- Direct integration with Cursor IDE

## Related Files

- `.cursor/agent-allow-reference.yaml` - Permission policy template (reference)
- `.cursor/docs/agent-allow-guide.md` - This documentation file
- `.cursor/docs/quickstart-guide.md` - Quick start guide for setting up rules
- `.cursor/rules/*.mdc` - Active Cursor rules (existing project rules)
- `.cursor/agent.log` - Agent operation log (if exists)
- `docs/implementation-plans/` - Project implementation plans
- `.markdownlint.yaml` - Markdown linting rules

## Official Cursor Documentation

### Primary References

- **[Cursor Rules Documentation](https://docs.cursor.com/context/rules)** - Official guide to creating and managing rules
- **[Cursor Context System](https://docs.cursor.com/en/context)** - Understanding how Cursor uses context and rules
- **[Cursor Background Agents](https://docs.cursor.com/background-agents)** - Background agent configuration and usage

### Cursor Rules System

Cursor's official approach uses a `.cursor/rules` directory where each rule is a Markdown file with frontmatter:

```markdown
---
description: Rule description
globs: pattern/*.ext
alwaysApply: true
---
Rule content in markdown...
```

**Key Documentation Points:**

- **Rule Structure**: Each rule file uses YAML frontmatter with markdown content
- **Globs**: File patterns to apply rules to specific files
- **AlwaysApply**: Boolean flag to enforce rule universally
- **Rule Discovery**: Cursor automatically loads rules from `.cursor/rules/`

### Additional Resources

- **[YAML Specification](https://yaml.org/spec/)** - YAML syntax reference
- **[Glob Pattern Matching](https://en.wikipedia.org/wiki/Glob_(programming))** - Understanding glob patterns
- **[Markdown Guide](https://www.markdownguide.org/)** - Markdown syntax for rule content

### Community Resources

- **Cursor Community Forum** - Discussions on best practices
- **Cursor GitHub Issues** - Known issues and feature requests
- **Cursor Discord** - Real-time community support
