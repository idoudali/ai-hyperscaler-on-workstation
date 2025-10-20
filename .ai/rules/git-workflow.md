---
alwaysApply: true
---
# Git Workflow: Safety, Staging, and Conflict Resolution

## 🚫 Prohibited Operations

### Force Operations

- `git push --force` or `git push -f`
- `git reset --hard`

### After Merge Conflicts

- `git rebase --continue`
- `git cherry-pick --continue`
- `git merge --continue`
- `git am --continue`
- `git revert --continue`
- `git rebase --abort/--skip`
- `git cherry-pick --abort/--skip`
- `git merge --abort`

### Staging Operations

- `git add` (without explicit user approval)
- `git add .` or `git add -A`
- Any automatic staging of files

## ✅ Safe Operations

- `git status`, `git diff`, `git log`
- `git fetch`, `git pull`
- `git branch`, `git checkout -b`
- `git stash`, `git stash pop`

## Git Staging: Never Auto-Stage

### Critical Rule

**NEVER automatically stage files with `git add`**

### Required Process

1. Complete changes
2. Present modified/created/deleted files
3. Provide staging commands: `$ git add <files>`
4. Wait for user to stage

### Exception

Only auto-stage when:

- User explicitly requests: "stage the files"
- User approved commit: "proceed with commit"

## Merge Conflict Handling

### What You CAN Do

1. Run `git status` - identify conflicts
2. Show conflict markers
3. Explain conflict
4. Suggest resolution
5. Edit files if requested
6. Stage resolved files: `git add <files>`
7. **STOP** - tell user to run continuation command

### Required Workflow

```text
1. Present conflicts to user
2. Help resolve if requested
3. Stage: git add <resolved-files>
4. Tell user: "Run: git rebase --continue"
```

### Conflict Detection

- `git status` shows "rebase/cherry-pick/merge in progress"
- Files contain `<<<<<<<`, `=======`, `>>>>>>>`
- `.git/rebase-merge`, `.git/CHERRY_PICK_HEAD` exists

## Summary

- ❌ Never force push or hard reset
- ❌ Never auto-continue after conflicts
- ❌ Never auto-stage files
- ✅ Present files with staging commands
- ✅ Let user stage and continue operations
- ✅ Explain commands user must run
