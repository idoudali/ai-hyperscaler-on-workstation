# Cursor Configuration Directory

This directory contains Cursor IDE configuration, rules, and documentation.

## Structure

```text
.cursor/
├── README.md                        # This file
├── agent-allow-reference.yaml       # Reference template for agent permissions
├── docs/                            # Documentation
│   ├── agent-allow-guide.md        # Comprehensive guide to agent permissions
│   └── quickstart-guide.md         # Quick setup guide
└── rules/                           # Active Cursor rules
    ├── agent/                       # Agent-requestable rules
    │   ├── conventional-commit-messages.mdc
    │   ├── documentation-updates.mdc
    │   └── slurm-gpu-config.mdc
    ├── always/                      # Always-applied rules
    │   ├── commit-approval-required.mdc
    │   ├── dev-container-build.mdc
    │   └── markdown-formatting.mdc
    ├── auto/                        # Auto-applied rules (file glob-based)
    │   ├── ansible-best-practices.mdc
    │   ├── docker-package-sorting.mdc
    │   ├── kubernetes-gpu-resources.mdc
    │   ├── python.mdc
    │   ├── shell-script-best-practices.mdc
    │   └── terraform-best-practices.mdc
    └── manual/                      # Manually-triggered rules
        └── review-diff.mdc
```

## File Descriptions

### Rules (`rules/`)

Cursor rules are organized by activation type:

- **`agent/`** - Rules that can be requested by the agent when needed
- **`always/`** - Rules that are always active for every agent interaction
- **`auto/`** - Rules that activate based on file patterns (globs)
- **`manual/`** - Rules that must be manually invoked by the user

All rule files use `.mdc` extension (Markdown with Cursor extensions) and include:

- YAML frontmatter with metadata (`description`, `globs`, `alwaysApply`)
- Markdown content describing the rule

### Documentation (`docs/`)

- **`agent-allow-guide.md`** - Comprehensive guide explaining:
  - How Cursor's rules system works
  - Permission structures and best practices
  - Migration guide from YAML to Cursor rules
  - Troubleshooting and examples

- **`quickstart-guide.md`** - Quick start guide for:
  - Setting up essential safety rules
  - Adding additional agent restrictions
  - Testing and verifying rules

### Reference (`agent-allow-reference.yaml`)

A YAML template documenting comprehensive permission policies. This is NOT directly used by Cursor, but serves as:

- Central policy documentation
- Reference for creating Cursor rule files
- Planning template for permission structures

## Quick Links

### Getting Started

1. **Review existing rules**: Browse `rules/` subdirectories
2. **Read quickstart**: See `docs/quickstart-guide.md` for setup
3. **Understand system**: Read `docs/agent-allow-guide.md` for details

### Common Tasks

**Add a new rule:**

```bash
# Create file in appropriate subdirectory
cat > .cursor/rules/auto/my-rule.mdc << 'EOF'
---
globs:
  - "**/*.ext"
description: "Description of rule"
---

# Rule Content
Rule instructions in markdown...
EOF
```

**Review all active rules:**

```bash
ls -la .cursor/rules/*/*.mdc
```

**Check rule is loaded:**
Open Cursor → Settings → Rules → Verify your rule appears in the list

### Rule Categories Explained

#### Always-Applied Rules

Current always-applied rules:

- `commit-approval-required.mdc` - Requires user approval before committing
- `dev-container-build.mdc` - Enforces Docker container for builds
- `markdown-formatting.mdc` - Ensures markdown quality standards

#### Auto-Applied Rules

Rules that activate based on file types:

- `ansible-best-practices.mdc` - For `**/*.yml`, `**/*.yaml` in ansible/
- `terraform-best-practices.mdc` - For `terraform/**/*.tf`
- `python.mdc` - For Python development
- `shell-script-best-practices.mdc` - For `**/*.sh`
- `kubernetes-gpu-resources.mdc` - For Kubernetes YAML files
- `docker-package-sorting.mdc` - For Dockerfiles

#### Agent-Requestable Rules

Rules the agent can reference when needed:

- `conventional-commit-messages.mdc` - Commit message format guidelines
- `documentation-updates.mdc` - Reminds to update docs after IaC changes
- `slurm-gpu-config.mdc` - SLURM GPU configuration specifics

#### Manual Rules

Rules you explicitly invoke:

- `review-diff.mdc` - Comprehensive code review process

## Official Documentation

- [Cursor Rules Documentation](https://docs.cursor.com/context/rules)
- [Cursor Context System](https://docs.cursor.com/en/context)

## Best Practices

1. **Keep rules focused** - One responsibility per rule
2. **Use descriptive names** - Clear file names help discoverability
3. **Document thoroughly** - Explain why the rule exists
4. **Test rules** - Verify they work as expected
5. **Review regularly** - Update as project evolves

## Troubleshooting

**Rules not loading?**

- Restart Cursor
- Check YAML frontmatter syntax
- Verify file has `.mdc` extension
- Check Cursor Settings → Rules

**Rule not activating?**

- Verify `globs` pattern matches your files
- Check `alwaysApply` is set correctly
- Review rule in Cursor Settings

**Need help?**

- See `docs/agent-allow-guide.md` for comprehensive guidance
- Review existing rules for patterns
- Check Cursor's official documentation

## Contributing

When adding new rules:

1. Choose appropriate subdirectory (`agent/`, `always/`, `auto/`, `manual/`)
2. Use `.mdc` extension
3. Include proper YAML frontmatter
4. Write clear, actionable markdown content
5. Test the rule works as expected
6. Update this README if adding new categories

## Version History

- Initial setup with comprehensive rule organization
- Reference documentation and quick start guide added
- Aligned with project's infrastructure-as-code workflow
