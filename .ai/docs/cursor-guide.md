# Cursor IDE Guide

This guide is specific to using **Cursor IDE** within this repository.

## Quick Start

Cursor automatically loads configuration from `.cursor/` when you open this workspace.

## Configuration

Cursor is configured via:

- **`.cursor/rules/`** - Rules (symlinked to `.ai/rules/` for shared rules)
- **`.cursor/rules/agent/`** - Agent-requestable rules
- **`.cursor/rules/auto/`** - File-type specific rules
- **`.cursor/rules/manual/`** - Manual trigger rules

## Shared Rules

Cursor's `.cursor/rules/always/` contains symlinks to shared rules in `.ai/rules/`:

- `git-workflow.mdc` → `.ai/rules/git-workflow.md`
- `commit-workflow.mdc` → `.ai/rules/commit-workflow.md`
- `build-container.mdc` → `.ai/rules/build-container.md`
- `precommit-workflow.mdc` → `.ai/rules/precommit-workflow.md`

This ensures Cursor and Claude follow the same rules without duplication.

## Agent-Requestable Rules

Additional rules available via `@rule-name`:

- `@agent/documentation-updates` - Documentation update requirements
- `@agent/slurm-gpu-config` - SLURM GPU configuration guidance
- `@auto/ansible-best-practices` - Ansible playbook best practices
- `@auto/kubernetes-gpu-resources` - Kubernetes MIG GPU resources
- `@auto/shell-script-best-practices` - Shell scripting standards
- `@auto/terraform-best-practices` - Terraform code standards

## Usage in Cursor

### Chat Mode

```text
How do I provision a cluster?
```

### Composer Mode

```text
Add GPU support to the SLURM configuration
@agent/slurm-gpu-config
```

### Command Palette

- `Cursor: Chat` - Open chat
- `Cursor: Composer` - Open composer
- `Cursor: Apply` - Apply suggested changes

## Safety Features

Cursor is configured to:

- ✅ Require approval before commits (via rules)
- ✅ Prevent force push operations
- ✅ Prevent destructive operations  
- ✅ Require container for builds
- ✅ Delegate merge conflict continuations to user

## Cursor-Specific Features

### Symbol Search

- `@symbol` - Reference specific symbols
- `@file` - Reference specific files
- `@folder` - Reference entire folders

### Context

- `@Codebase` - Search entire codebase
- `@Docs` - Reference documentation
- `@Git` - Git information
- `@Web` - Web search

## Troubleshooting

### Rules not being applied

```bash
# Verify symlinks exist
ls -la .cursor/rules/always/

# Should show symlinks like:
# git-safety.mdc -> ../../../.ai/rules/git-safety.md
```

### Recreate symlinks

```bash
cd .cursor/rules/always/
rm -f git-safety.mdc commit-workflow.mdc build-container.mdc merge-conflicts.mdc
ln -sf ../../../.ai/rules/git-safety.md git-safety.mdc
ln -sf ../../../.ai/rules/commit-workflow.md commit-workflow.mdc
ln -sf ../../../.ai/rules/build-container.md build-container.mdc
ln -sf ../../../.ai/rules/merge-conflicts.md merge-conflicts.mdc
```

### Rules not loading

1. Restart Cursor IDE
2. Check Settings → Cursor Settings → Rules
3. Verify `.cursor/rules/` directory exists

## More Information

- Main guide: `AI-AGENT-GUIDE.md` (repository root)
- Shared rules: `.ai/rules/`
- Shared context: `.ai/context/`
- Cursor docs: https://docs.cursor.com/
