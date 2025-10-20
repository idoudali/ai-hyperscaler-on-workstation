---
alwaysApply: true
---
# Pre-commit Workflow

## Critical Rules

### 🚫 Never Run on All Files

**PROHIBITED**: `pre-commit run --all-files`

Unless explicitly requested, NEVER run pre-commit on all files.

### ✅ Always Run on Staged Files Only

```bash
# Run on staged files
pre-commit run

# Run on specific files
pre-commit run --files <file1> <file2>

# Run specific hook
pre-commit run <hook-name> --files <file1>
```

### 🚫 Never Auto-Stage Fixes

After fixing pre-commit errors, DO NOT auto-stage with `git add`.

## Workflow

1. **Identify errors** - Show pre-commit output
2. **Fix issues** - Edit files to resolve errors
3. **Verify fixes** - Run `pre-commit run --files <modified-files>`
4. **Report to user** - List fixed files
5. **Delegate staging** - Tell user to run `git add <files>`

## Why These Rules?

**Never --all-files**:

- Modifies unrelated files
- Mixes unrelated changes
- Wastes time on unchanged files

**Never auto-stage**:

- Removes user control
- Prevents review of fixes
- Violates user approval rule

## When to Use --all-files

ONLY when user explicitly requests:

- "run pre-commit on all files"
- Setting up pre-commit initially
- After changing configuration

Even then, NEVER auto-stage results.

## Summary

- ✅ Run on staged files only
- ✅ Run on specific modified files
- ✅ Inform user, let them stage
- ❌ Never --all-files without request
- ❌ Never auto-stage fixes
