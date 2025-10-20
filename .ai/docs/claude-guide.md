# Claude Code CLI Guide

This guide is specific to using **Claude Code CLI** within this repository.

## Quick Start

```bash
# From repository root
claude code

# Claude will automatically load .claude/settings.json
```

## Configuration

Claude Code is configured via `.claude/settings.json` with:

- **Permission mode**: `default` (requires approval for edits/commands)
- **Shared rules**: References `.ai/rules/` directory
- **Context files**: Automatically loads project overview and quick reference
- **Safety features**: Prevents auto-commit, force push, merge conflict continuation

## Permission Modes

Claude Code supports different permission modes:

| Mode | Use Case | Auto-Edit | Auto-Execute |
|------|----------|-----------|--------------|
| `default` | Safe review mode | No | No |
| `acceptEdits` | Rapid development | Yes | No |
| `plan` | Planning only | No | No |
| `bypassPermissions` | Trusted automation | Yes | Yes |

**Current mode**: `default` (recommended for infrastructure-as-code projects)

## Workflows

Predefined workflows in settings.json:

```bash
# Build workflow
claude code --workflow build

# Test workflow
claude code --workflow test

# Commit workflow (interactive)
claude code --workflow commit
```

## Shared Rules

Claude uses the same rules as Cursor from `.ai/rules/`:

- `git-workflow.md` - Git workflow, safety, and merge conflict handling
- `commit-workflow.md` - Commit approval workflow
- `build-container.md` - Container build requirements
- `precommit-workflow.md` - Pre-commit workflow and staging rules

## Environment Variables

Claude loads environment variables from `.env.ai`:

```bash
AI_BUILD_CONTAINER="make run-docker"
AI_TEST_COMMAND="cd tests && make test"
AI_PREVENT_AUTO_COMMIT="1"
AI_REQUIRE_CONTAINER_BUILDS="1"
```

## Safety Features

Claude is configured to:

- ✅ Require approval before commits
- ✅ Prevent force push operations
- ✅ Prevent destructive operations
- ✅ Require container for builds
- ✅ Delegate merge conflict continuations to user

## Usage Examples

### Ask for help

```bash
claude code "How do I provision a cluster?"
```

### Review changes

```bash
claude code "Review my changes and suggest improvements"
```

### Get test suggestions

```bash
claude code "What tests should I add for this feature?"
```

### Debug issues

```bash
claude code "Why is the Ansible playbook failing?"
```

## Troubleshooting

### Claude not loading config

```bash
# Check config syntax
claude code --check-config

# Verify you're in repository root
pwd
```

### Rules not being followed

```bash
# Verify shared rules directory exists
ls -la .ai/rules/

# Check settings.json references
cat .claude/settings.json | grep sharedRulesDirectory
```

### Permission issues

```bash
# Check current permission mode
grep permissionMode .claude/settings.json

# Temporarily use different mode
claude code --mode acceptEdits
```

## More Information

- Main guide: `AI-AGENT-GUIDE.md` (repository root)
- Shared rules: `.ai/rules/`
- Shared context: `.ai/context/`
- Official docs: https://docs.claude.com/en/docs/claude-code/settings
