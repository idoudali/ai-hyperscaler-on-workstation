# CLAUDE.md - Redirect

**Note**: This file has been superseded by a unified AI agent guide.

## Please see: `AI-AGENT-GUIDE.md`

The comprehensive guide for both Cursor IDE and Claude Code CLI is now located in:

**`AI-AGENT-GUIDE.md`**

This unified guide includes:

- Complete project overview
- Core development commands
- AI agent configuration (both Cursor and Claude)
- Critical safety rules
- Project architecture details
- Development environment setup
- Code quality standards
- Component-specific development guidance
- Troubleshooting guides

---

## Quick Links

- **Main Guide**: [AI-AGENT-GUIDE.md](./AI-AGENT-GUIDE.md)
- **Claude-Specific Config**: [.claude/settings.json](./.claude/settings.json)
- **Shared Agent Rules**: [.ai/rules/](./.ai/rules/)
- **Claude Guide**: [.ai/docs/claude-guide.md](./.ai/docs/claude-guide.md)
- **Project README**: [README.md](./README.md)

---

## Component-Specific Workflows

### Ansible Development

When working with Ansible playbooks and roles, always run validation checks:

```bash
# Syntax check
ansible-playbook --syntax-check playbooks/<playbook>.yml

# Lint check
ansible-lint roles/<role-name>/

# Dry-run test
ansible-playbook --check playbooks/<playbook>.yml
```

See agent rules in `.cursor/rules/auto/ansible-*.mdc` for complete validation requirements.

**Note**: A `ansible/Makefile` can be added to standardize these commands.

### Python Development

When working with Python files in the ai-how module, always run validation checks using nox.

See shared rule in [`.ai/rules/python-lint-reminder.md`](./.ai/rules/python-lint-reminder.md)
for complete validation requirements and available commands.

---

## Why the change?

The project now supports both Cursor IDE and Claude Code CLI with:

- **Shared rules** in `.ai/rules/` to avoid duplication
- **Unified documentation** in `AI-AGENT-GUIDE.md`
- **Agent-specific configs** in `.cursor/` and `.claude/`
- **Consistent behavior** across both agents

This reduces duplication and provides a single source of truth for agent configuration and project documentation.
