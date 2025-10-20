---
alwaysApply: true
---
# Commit Workflow: User Approval Required

## Critical Rule

**NEVER commit without user approval.** Always present changes for review first.

## Required Process

1. **Complete the task** - Create, modify, or delete files as requested
2. **Present changes** - List modified/new/deleted files with brief descriptions
3. **Explain rationale** - Why changes were made and what problem was solved
4. **Provide commit message** - Well-structured conventional commit format
5. **Await approval** - Wait for explicit user approval before staging/committing

## Never Auto-Commit

Do not stage or commit without approval, even if:

- Changes are minor
- User said "commit this" (present summary first)
- Only one file changed

## Conventional Commits

Use conventional commit format:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `style:` - Formatting
- `refactor:` - Code restructuring
- `perf:` - Performance
- `test:` - Tests
- `chore:` - Maintenance

## Summary

Always present summary and wait for explicit approval before any git operations.
