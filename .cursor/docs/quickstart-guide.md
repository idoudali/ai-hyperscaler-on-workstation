# Cursor Agent Quick Start Guide

This guide helps you quickly set up essential Cursor agent rules for this project.

## Project Structure

This project already has Cursor rules in `.cursor/rules/` organized into:

- `.cursor/rules/agent/` - Agent-requestable rules
- `.cursor/rules/always/` - Always-applied rules  
- `.cursor/rules/auto/` - Auto-applied rules based on file globs
- `.cursor/rules/manual/` - Manually triggered rules

This guide shows you how to add additional safety rules for agent operations.

## Quick Setup (5 Minutes)

### Step 1: Review Existing Rules

Your project already has rules in `.cursor/rules/`. Review them:

```bash
ls -la .cursor/rules/*/*.mdc
```

### Step 2: Add Additional Safety Rules (Optional)

These additional rules complement your existing setup. Copy and paste these commands to add extra safety rules:

**Note:** The rules below use `.md` extension for clarity, but you can use `.mdc` to match your existing pattern.

#### Git Safety Rule

```bash
cat > .cursor/rules/git-safety.md << 'EOF'
---
description: Prevent destructive git operations
globs: "**/*"
alwaysApply: true
---

# Git Safety Rules

## 🚫 Prohibited Commands

NEVER execute these destructive git commands without explicit user approval:

- `git push --force` or `git push -f`
- `git reset --hard`
- `git clean -fd`
- `git rebase` (requires approval)

## ✅ Safe Commands

These commands are safe to use:

- `git status`
- `git diff`
- `git log`
- `git add`
- `git commit -m "message"`
- `git checkout -b <branch>`
- `git stash` / `git stash pop`

## Commit Workflow

Before committing changes:

1. Present a summary of all changes to the user
2. Provide context and rationale
3. Suggest a commit message
4. Wait for explicit user approval
5. Only then execute `git add` and `git commit`
EOF
```

#### Container Build Requirements

```bash
cat > .cursor/rules/container-builds.md << 'EOF'
---
description: All build commands must use development container
globs: "**/*"
alwaysApply: true
---

# Container Build Requirements

## Development Environment

This project uses a Docker-based development container for ALL build operations.

## 🚫 Prohibited

NEVER run build commands directly on the host system.

## ✅ Required Commands

All build operations MUST use:

- `make run-docker COMMAND="..."` - Execute commands in container
- `make shell-docker` - Interactive container shell
- `./scripts/run-in-dev-container.sh` - Container script

## Build Workflow

1. Ensure container is built: `make build-docker`
2. Configure CMake: `make config`
3. Run builds in container: `make run-docker COMMAND="cmake --build build --target <target>"`

## CMake Configuration

- **Build System**: CMake with Ninja generator
- **Build Directory**: `build/`
- **Configuration Command**: `make config` (runs `cmake -G Ninja -S . -B build`)

## Examples

```bash
# Configure CMake
make config

# Build specific target
make run-docker COMMAND="cmake --build build --target packer-head-node"

# List available targets
make run-docker COMMAND="cmake --build build --target help"
```

EOF

```text
```

#### Protected Configuration Files

```bash
cat > .cursor/rules/protect-config-files.md << 'EOF'
---
description: Protect critical configuration files from accidental modification
globs:
  - "Makefile"
  - "CMakeLists.txt"
  - "package.json"
  - "requirements.txt"
  - "docker-compose.yml"
  - ".gitignore"
  - ".cursor-agent-allow.yaml"
alwaysApply: true
---

# Protected Configuration Files

These files are critical to the project and require EXPLICIT USER APPROVAL before modification:

## Build System

- `Makefile` - Build system configuration
- `CMakeLists.txt` - CMake build configuration

## Dependency Management

- `package.json` - Node.js dependencies
- `requirements.txt` - Python dependencies

## Container Configuration

- `docker-compose.yml` - Docker services configuration

## Project Configuration

- `.gitignore` - Git ignore patterns
- `.cursor-agent-allow.yaml` - Agent permission policy

## Process

Before modifying any of these files:

1. Ask user for explicit permission
2. Explain why the change is necessary
3. Show what will be changed
4. Wait for approval
5. Only then make the modification
EOF
```

#### Infrastructure Validation

```bash
cat > .cursor/rules/iac-validation.md << 'EOF'
---
description: Validate infrastructure code before committing
globs:
  - "terraform/**/*.tf"
  - "ansible/**/*.yml"
  - "ansible/**/*.yaml"
  - "packer/**/*.pkr.hcl"
alwaysApply: true
---

# Infrastructure as Code Validation

## Pre-Commit Checklist

Before committing any infrastructure code changes:

1. ✅ Run validation commands
2. ✅ Check code formatting
3. ✅ Scan for hardcoded secrets
4. ✅ Update documentation in `/docs` if needed

## Terraform Safety

### 🚫 Never Run Without Approval

- `terraform apply`
- `terraform destroy`
- `terraform state rm`

### ✅ Always Run Before Commit

- `terraform validate`
- `terraform fmt`
- `terraform plan` (review output)

## Ansible Safety

### 🚫 Never Run Without Approval

- `ansible-playbook <playbook>` (without `--check`)
- Any playbook with `--force` flag

### ✅ Always Run Before Commit

- `ansible-playbook --syntax-check <playbook>`
- `ansible-lint <playbook>`
- `ansible-playbook --check <playbook>` (dry run)

## Packer Safety

### 🚫 Never Run Without Approval

- `packer build <template>` (without validation first)

### ✅ Always Run Before Commit

- `packer validate <template>`
- `packer fmt <template>`

## Documentation Updates

After modifying infrastructure code, check if these need updating:

- `/docs/design/` - Design documents
- `/docs/implementation-plans/` - Implementation plans
- `README.md` files in affected directories
EOF
```

#### Documentation Standards

```bash
cat > .cursor/rules/documentation-standards.md << 'EOF'
---
description: Markdown formatting and documentation standards
globs:
  - "**/*.md"
alwaysApply: true
---

# Markdown Formatting Standards

When generating or modifying markdown content, follow these rules to ensure compliance with `.markdownlint.yaml`:

## Headers

- Use ATX style headers with `#` symbols
- Maximum line length: 120 characters
- No trailing punctuation in headers
- Allow duplicate headings in different sections

## Lists

- Use dash (`-`) for unordered lists
- Use ordered numbers for ordered lists
- Indent list items with exactly 2 spaces
- Allow multiple spaces after list markers

## Code Blocks

- Use fenced code blocks with triple backticks
- Include language identifier for syntax highlighting
- Maximum code block line length: 120 characters

## Line Length

- Maximum line length: 120 characters for all content
- Allow 2 trailing spaces for line breaks
- No trailing spaces otherwise

## Task Lists

Use consistent checkbox format:

```markdown
- [ ] Pending task
- [x] Completed task
  - [ ] Sub-task (2-space indent)
```

## Code Citations

When citing code, use this EXACT format:

```text
```12:15:app/components/Todo.tsx
// ... existing code ...
\`\`\`
```

Format: \`\`\`startLine:endLine:filepath

## Tables

- Use proper alignment
- Include headers for all columns
- Keep tables within 120 character line length
- Use HTML tables for complex data when needed

## Validation

Before finalizing markdown content, verify:

- [ ] All headers use ATX style (`#`)
- [ ] Lists use dash (`-`) for unordered items
- [ ] Proper 2-space indentation
- [ ] No lines exceed 120 characters
- [ ] Code blocks properly fenced
- [ ] No trailing spaces (except 2 for line breaks)
EOF

```text
```

### Step 3: Verify Rules Are Loaded

```bash
# List the rules you just created
ls -la .cursor/rules/

# Should show:
# - git-safety.md
# - container-builds.md
# - protect-config-files.md
# - iac-validation.md
# - documentation-standards.md
```

### Step 4: Test the Rules

Open Cursor and test that the agent respects the rules:

1. Ask the agent to show you what rules it has loaded
2. Try asking it to run a prohibited command (it should refuse)
3. Verify it mentions the rules when explaining why it can't do something

## What These Rules Do

### 1. Git Safety (Critical)

Prevents the agent from:

- Force pushing to remote
- Hard resetting branches
- Performing destructive git operations

### 2. Container Builds (Project-Specific)

Ensures the agent:

- Uses the development container for all builds
- Never runs build commands on host
- Follows correct CMake/Ninja workflow

### 3. Protected Files (Safety)

Requires explicit approval before modifying:

- Build configuration files
- Dependency files
- Critical project configuration

### 4. Infrastructure Validation (IaC)

Ensures the agent:

- Validates before committing
- Never runs destructive infrastructure commands
- Updates documentation when needed

### 5. Documentation Standards (Quality)

Ensures the agent:

- Follows markdown linting rules
- Uses consistent formatting
- Maintains line length limits

## Next Steps

### Add More Rules (Optional)

Based on `.cursor-agent-allow.yaml`, you can create additional rules for:

- Specific file access patterns
- Testing requirements
- Code formatting standards
- Security scanning

See `.cursor-agent-allow.md` for more examples and the full migration guide.

### Customize Existing Rules

Edit any of the created rules to match your specific needs:

```bash
# Edit a rule
code .cursor/rules/git-safety.md

# Rules are automatically reloaded by Cursor
```

### Review Rule Effectiveness

After using Cursor for a while:

1. Check if agent respects the rules
2. Adjust rules that are too restrictive
3. Add rules for gaps you discover
4. Share effective rules with team

## Troubleshooting

### Rules Not Loading

```bash
# Check rules directory exists
ls -la .cursor/rules/

# Check file format (must be .md)
file .cursor/rules/*.md

# Verify YAML frontmatter is valid
head -n 10 .cursor/rules/git-safety.md
```

### Agent Not Respecting Rules

1. Restart Cursor
2. Check Cursor settings → Rules
3. Verify rule files are listed
4. Try being more explicit in the rule text

### Rule Conflicts

If multiple rules conflict:

1. Use more specific `globs` patterns
2. Set `alwaysApply: true` for critical rules
3. Create rule hierarchy (general → specific)

## Official Documentation

- **[Cursor Rules](https://docs.cursor.com/context/rules)** - Official rules documentation
- **[Cursor Context](https://docs.cursor.com/en/context)** - Context system overview

## Support

If you need help:

1. Review `.cursor/docs/agent-allow-guide.md` for detailed documentation
2. Check `.cursor/agent-allow-reference.yaml` for reference configuration
3. Review existing rules in `.cursor/rules/` for patterns
4. Consult Cursor's official documentation at [docs.cursor.com/context/rules](https://docs.cursor.com/context/rules)
5. Ask in Cursor community forums

## Summary

You now have 5 essential rules protecting your project:

- ✅ Git safety prevents destructive operations
- ✅ Container builds enforce proper development workflow
- ✅ Protected files prevent accidental configuration changes
- ✅ IaC validation ensures infrastructure code quality
- ✅ Documentation standards maintain consistent formatting

These rules will help the Cursor agent work safely and effectively within your project constraints.
