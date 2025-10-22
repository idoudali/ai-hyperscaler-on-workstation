# Remove Pharos References - Task List

**Objective:** Systematically remove or replace all "pharos" references throughout the repository to make it
vendor-neutral and more generic.

**Status:** Planning Phase
**Created:** 2025-10-16
**Total Tasks:** 12 tasks across 4 phases
**Completed Tasks:** 0

## Overview

This document provides a detailed plan for removing all pharos-specific references from the codebase, making the project
more generic and suitable for broader use. The changes will be organized by file type and impact level to ensure a
systematic and safe refactoring process.

## Task Execution Principles

- **Non-Breaking Changes**: Prioritize changes that don't break functionality
- **Systematic Approach**: Group changes by file type and impact level
- **Clear Replacement Strategy**: Define what replaces each pharos reference
- **Testing After Each Phase**: Validate system still works after each phase
- **Documentation Updates**: Keep documentation accurate throughout the process

## Scope Analysis

**Files Affected:** 26 files containing pharos references

**Categories:**

- Configuration files: 2 files (mkdocs.yml, pyproject.toml)
- Documentation: 8 files (README, design docs, task lists)
- Scripts: 3 files (run-in-dev-container.sh, entrypoint.sh, setup scripts)
- Python code: 1 file (**init**.py)
- Docker files: 1 file (Dockerfile)
- Test files: 2 files (README.md, test scripts)
- Log/generated files: 9 files (can be regenerated or cleaned)

## Replacement Strategy

The following replacement strategy will be used throughout:

- **Project Name**: `pharos.ai-hyperscaler-on-workskation` → `ai-hyperscaler-on-workskation` ✅
- **Short Name**: New → `ai-how` ✅
- **Docker Image Name**: `pharos-dev` → `ai-how-dev` ✅
- **Team/Author**: `Pharos.ai Team` → `AI-HOW Team` ✅
- **Site Name**: `Pharos.ai Hyperscaler on Workstation` → `AI-HOW: AI Hyperscaler on Workstation` ✅
- **Site/Repo URLs**: `pharos-ai/hyperscaler-on-workstation` → ⏳ **PENDING** (see decisions needed below)
- **Copyright**: `Pharos.ai` → ⏳ **PENDING** (see decisions needed below)

## Phase 1: Configuration Files (Tasks 001-003)

### TASK-001: Update MkDocs Configuration

- **ID**: TASK-001
- **Phase**: 1 - Configuration Files
- **Dependencies**: None
- **Estimated Time**: 30 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update `mkdocs.yml` to remove pharos branding and replace with generic project information.

**Files to Modify:**

- `mkdocs.yml`

**Changes Required:**

1. Update site name: `Pharos.ai Hyperscaler on Workstation` → `AI-HOW: AI Hyperscaler on Workstation`
2. Update site author: `Pharos.ai Team` → `AI-HOW Team`
3. Update site URL: `https://pharos-ai.github.io/hyperscaler-on-workstation`
→ `https://idoudali.github.io/ai-hyperscaler-on-workskation` ✅
4. Update repo name: `pharos.ai/hyperscaler-on-workstation` → `idoudali/ai-hyperscaler-on-workskation` ✅
5. Update repo URL: `https://github.com/pharos-ai/hyperscaler-on-workstation`
→ `https://github.com/idoudali/ai-hyperscaler-on-workskation` ✅
6. Update copyright: `Copyright &copy; 2024 Pharos.ai` → `Copyright &copy; 2024-2025 AI-HOW Team` ✅
7. Update social links: `https://github.com/pharos-ai` → `https://github.com/idoudali` ✅

**Validation:**

```bash
# Verify YAML syntax is valid
yamllint mkdocs.yml

# Test MkDocs build
mkdocs build --strict
```

**Notes:**

- Keep URLs as placeholders (e.g., `idoudali/hyperscaler-on-workstation`) if final URLs are not yet determined
- Ensure all links in documentation remain functional

---

### TASK-002: Update Python Package Configuration

- **ID**: TASK-002
- **Phase**: 1 - Configuration Files
- **Dependencies**: None
- **Estimated Time**: 20 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update Python package configuration files to remove pharos references.

**Files to Modify:**

- `python/ai_how/pyproject.toml`
- `python/ai_how/mkdocs.yml`

**Changes Required:**

1. In `pyproject.toml`:
   - Update package metadata (authors, URLs, descriptions)
   - Update any pharos-specific configuration values
   - Review and update documentation URLs

2. In `python/ai_how/mkdocs.yml`:
   - Update site information similar to main mkdocs.yml
   - Update any pharos-specific links or references

**Validation:**

```bash
# Verify pyproject.toml syntax
cd python/ai_how
python -m pip install --dry-run -e .

# Test package metadata
python -m build --wheel --sdist
```

**Notes:**

- Ensure package name doesn't conflict with existing PyPI packages
- Consider keeping backward compatibility for existing users

---

### TASK-003: Update Docker Configuration

- **ID**: TASK-003
- **Phase**: 1 - Configuration Files
- **Dependencies**: None
- **Estimated Time**: 30 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update Docker-related configuration to use generic image names and remove pharos branding.

**Files to Modify:**

- `scripts/run-in-dev-container.sh`
- `docker/entrypoint.sh`
- `Makefile`
- `containers/images/pytorch-cuda12.1-mpi4.1/Docker/Dockerfile`

**Changes Required:**

1. In `run-in-dev-container.sh`:
   - Change `IMAGE_NAME="pharos-dev"` → `IMAGE_NAME="ai-how-dev"`
   - Update help text and comments from pharos to AI-HOW

2. In `docker/entrypoint.sh`:
   - Update comment: `pharos development Docker container` → `AI-HOW development Docker container`
   - Update log messages from pharos to AI-HOW

3. In `Makefile`:
   - Update `IMAGE_NAME` variable if present to `ai-how-dev`
   - Update any pharos-related comments

4. In `Dockerfile`:
   - Update LABEL maintainer: `Pharos AI Hyperscaler Team` → `AI-HOW Team`
   - Update description labels to reference AI-HOW

**Validation:**

```bash
# Rebuild Docker image with new name
make build-docker

# Verify image exists with new name
docker images | grep ai-how-dev

# Test container functionality
make shell-docker
exit
```

**Notes:**

- Old `pharos-dev` image will remain until manually removed
- New image name: `ai-how-dev`
- Update documentation referencing the image name
- Consider adding image tag migration guide

---

## Phase 2: Documentation Files (Tasks 004-007)

### TASK-004: Update Root Documentation

- **ID**: TASK-004
- **Phase**: 2 - Documentation Files
- **Dependencies**: TASK-001, TASK-003
- **Estimated Time**: 45 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update root-level documentation files to remove pharos references.

**Files to Modify:**

- `README.md`
- `docker/README.md`
- `ansible/README-packer-ansible.md`

**Changes Required:**

1. In `README.md`:
   - Update project title and description to AI-HOW
   - Update directory tree: `pharos.ai-hyperscaler-on-workskation/` → `ai-hyperscaler-on-workskation/`
   - Update any pharos-specific URLs or links
   - Review and update badges if present

2. In `docker/README.md`:
   - Update references from pharos development container to AI-HOW development container
   - Update image names in examples from `pharos-dev` to `ai-how-dev`

3. In `ansible/README-packer-ansible.md`:
   - Update any pharos-specific paths or examples
   - Update image names to `ai-how-dev`

**Validation:**

```bash
# Verify markdown syntax
markdownlint README.md docker/README.md ansible/README-packer-ansible.md

# Check for any remaining pharos references
grep -ri "pharos" README.md docker/README.md ansible/README-packer-ansible.md
```

**Notes:**

- Update all code examples to use new paths/names
- Ensure all hyperlinks remain functional

---

### TASK-005: Update Design Documentation

- **ID**: TASK-005
- **Phase**: 2 - Documentation Files
- **Dependencies**: TASK-004
- **Estimated Time**: 1 hour
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update design documentation to remove pharos references.

**Files to Modify:**

- `docs/design-docs/hyperscaler-on-workstation.md`
- `docs/design-docs/open-source-solutions.md`
- `docs/CLUSTER-DEPLOYMENT-WORKFLOW.md`
- `docs/cursor-agent-setup.md`

**Changes Required:**

1. Search and replace pharos references in all design docs with AI-HOW
2. Update file paths in examples: `/path/to/pharos.ai-hyperscaler-on-workskation` → `/path/to/ai-hyperscaler-on-workskation`
3. Update any pharos-specific architectural decisions or references to AI-HOW project
4. Review and update diagrams or architecture descriptions

**Validation:**

```bash
# Verify markdown syntax
markdownlint docs/design-docs/*.md docs/*.md

# Check for remaining pharos references
grep -ri "pharos" docs/design-docs/ docs/CLUSTER-DEPLOYMENT-WORKFLOW.md docs/cursor-agent-setup.md
```

**Notes:**

- Preserve technical accuracy while removing branding
- Update any references to pharos-specific infrastructure

---

### TASK-006: Update Task Lists and Implementation Plans

- **ID**: TASK-006
- **Phase**: 2 - Documentation Files
- **Dependencies**: TASK-005
- **Estimated Time**: 1 hour
- **Difficulty**: Medium
- **Status**: ⏳ PENDING

**Description:** Update task lists and implementation plans to remove pharos-specific path references.

**Files to Modify:**

- `docs/implementation-plans/task-lists/hpc-slurm-task-list.md`

**Changes Required:**

1. Update all absolute path references:
   - `/home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation` → Generic relative paths
   - `/home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation-2` → Generic relative paths

2. Make examples more generic and portable
3. Use environment variables or placeholders for user-specific paths

**Example Replacement:**

```markdown
# Before
cd /home/doudalis/Projects/pharos.ai-hyperscaler-on-workskation
make config

# After
cd ${PROJECT_ROOT}  # or /path/to/ai-hyperscaler-on-workskation
make config
```

**Validation:**

```bash
# Verify markdown syntax
markdownlint docs/implementation-plans/task-lists/*.md

# Check for remaining pharos references
grep -ri "pharos" docs/implementation-plans/
```

**Notes:**

- Consider using `${PROJECT_ROOT}` placeholder for paths
- Maintain accuracy of command examples
- This file is very large (59,000+ tokens), focus on systematic replacements

---

### TASK-007: Update Test Documentation

- **ID**: TASK-007
- **Phase**: 2 - Documentation Files
- **Dependencies**: TASK-006
- **Estimated Time**: 30 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update test documentation to remove pharos references.

**Files to Modify:**

- `tests/README.md`
- `scripts/experiments/README.md`

**Changes Required:**

1. Update path references in test documentation
2. Replace pharos-specific paths with generic ones
3. Update any pharos-related test descriptions

**Validation:**

```bash
# Verify markdown syntax
markdownlint tests/README.md scripts/experiments/README.md

# Check for remaining pharos references
grep -ri "pharos" tests/README.md scripts/experiments/
```

---

## Phase 3: Source Code Files (Tasks 008-009)

### TASK-008: Update Python Source Code

- **ID**: TASK-008
- **Phase**: 3 - Source Code Files
- **Dependencies**: TASK-002
- **Estimated Time**: 20 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update Python source code to remove pharos references.

**Files to Modify:**

- `containers/tools/hpc_extensions/__init__.py`

**Changes Required:**

1. Update `__author__` field:

   ```python
   # Before
   __author__ = "Pharos AI Hyperscaler Team"
   
   # After
   __author__ = "AI-HOW Team"
   ```

2. Review and update any pharos-specific code comments to reference AI-HOW
3. Update docstrings if they reference pharos to use AI-HOW instead

**Validation:**

```bash
# Verify Python syntax
python -m py_compile containers/tools/hpc_extensions/__init__.py

# Run unit tests if available
python -m pytest containers/tools/hpc_extensions/

# Check for remaining pharos references
grep -ri "pharos" containers/tools/hpc_extensions/
```

**Notes:**

- Ensure no breaking changes to the API
- Update version number if this is a significant change

---

### TASK-009: Update Shell Scripts

- **ID**: TASK-009
- **Phase**: 3 - Source Code Files
- **Dependencies**: TASK-003, TASK-006
- **Estimated Time**: 30 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Update shell scripts to remove pharos references beyond already handled configuration.

**Files to Modify:**

- `scripts/setup-host-dependencies.sh`
- `scripts/experiments/start-test-vm.sh`
- `tests/test-ansible-hpc-integration.sh`

**Changes Required:**

1. Update comments and documentation strings
2. Replace pharos-specific variable names if present
3. Update any pharos-specific logic or references
4. Update error messages and log output

**Validation:**

```bash
# Verify shell script syntax
shellcheck scripts/setup-host-dependencies.sh
shellcheck scripts/experiments/start-test-vm.sh
shellcheck tests/test-ansible-hpc-integration.sh

# Check for remaining pharos references
grep -ri "pharos" scripts/ tests/*.sh
```

**Notes:**

- Test scripts in isolated environment if possible
- Ensure no hard-coded pharos paths remain

---

## Phase 4: Cleanup and Validation (Tasks 010-012)

### TASK-010: Clean Generated Files

- **ID**: TASK-010
- **Phase**: 4 - Cleanup and Validation
- **Dependencies**: All previous tasks
- **Estimated Time**: 15 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Clean or regenerate files that contain pharos references from previous builds/runs.

**Files to Handle:**

- `LOG`
- `LOG_RUN`
- `BUILD_LOG`
- `DIFF`
- `gh-review.md`

**Actions:**

1. **Delete or clean log files:**

   ```bash
   rm -f LOG LOG_RUN BUILD_LOG
   ```

2. **Handle DIFF file:**
   - Review if needed for history
   - Delete or move to archive if not needed

3. **Handle gh-review.md:**
   - Review if needed
   - Update or delete as appropriate

4. **Update .gitignore:**
   - Ensure log files are properly ignored
   - Add patterns for generated files

**Validation:**

```bash
# Verify log files are in .gitignore
grep -E "(LOG|BUILD_LOG|DIFF)" .gitignore

# Check for remaining pharos references in tracked files only
git ls-files | xargs grep -l "pharos" 2>/dev/null
```

**Notes:**

- These files will be regenerated with new names automatically
- Archive important logs before deletion if needed

---

### TASK-011: Global Verification and Testing

- **ID**: TASK-011
- **Phase**: 4 - Cleanup and Validation
- **Dependencies**: TASK-010
- **Estimated Time**: 1 hour
- **Difficulty**: Medium
- **Status**: ⏳ PENDING

**Description:** Perform comprehensive verification that all pharos references have been removed and the system still
functions correctly.

**Verification Steps:**

1. **Search for Remaining References:**

   ```bash
   # Case-insensitive search in all tracked files
   git ls-files | xargs grep -li "pharos" 2>/dev/null
   
   # Search in specific file types
   find . -type f \( -name "*.md" -o -name "*.py" -o -name "*.sh" -o -name "*.yml" \) \
     -not -path "*/.*" -not -path "*/build/*" \
     -exec grep -l "pharos" {} \;
   ```

2. **Build Testing:**

   ```bash
   # Clean and rebuild
   make clean-docker
   make build-docker
   
   # Test configuration
   make config
   
   # Test basic build
   make run-docker COMMAND="cmake --build build --target help"
   ```

3. **Documentation Build:**

   ```bash
   # Build documentation
   mkdocs build --strict
   
   # Build Python package docs
   cd python/ai_how
   mkdocs build --strict
   ```

4. **Container Testing:**

   ```bash
   # Test new container image
   make shell-docker
   # Run some basic commands inside
   exit
   ```

5. **Linting and Validation:**

   ```bash
   # Run linters
   markdownlint docs/**/*.md README.md
   shellcheck scripts/**/*.sh
   yamllint *.yml ansible/**/*.yml
   ```

**Expected Results:**

- ✅ No pharos references in tracked source files
- ✅ Docker container builds successfully with new name
- ✅ Documentation builds without errors
- ✅ All linters pass
- ✅ Basic functionality tests pass

**Issues to Address:**

- Any remaining pharos references found
- Broken links or references in documentation
- Build failures
- Test failures

---

### TASK-012: Update Version Control and Documentation

- **ID**: TASK-012
- **Phase**: 4 - Cleanup and Validation
- **Dependencies**: TASK-011
- **Estimated Time**: 30 minutes
- **Difficulty**: Easy
- **Status**: ⏳ PENDING

**Description:** Final updates to version control, changelog, and migration documentation.

**Deliverables:**

1. **Create Migration Guide:**
   - Document: `docs/MIGRATION-FROM-PHAROS.md`
   - Include:
     - What changed (file names, image names, paths)
     - How to update existing deployments
     - Backward compatibility notes
     - Cleanup steps for old pharos artifacts

2. **Update CHANGELOG:**
   - Add entry for pharos removal
   - Note breaking changes (image names, paths)
   - Document replacement values

3. **Update README:**
   - Add note about name change if relevant
   - Update any remaining setup instructions

4. **Version Bump:**
   - Update version numbers in appropriate files
   - Consider this a major version if breaking changes

**Migration Guide Template:**

```markdown
# Migration Guide: Pharos to AI-HOW Rebranding

## Overview
This guide helps users migrate from the old pharos-branded version to the
new AI-HOW (AI Hyperscaler on Workstation) version.

## Breaking Changes

### Docker Image Name
- Old: `pharos-dev:latest`
- New: `ai-how-dev:latest`

### Project Name
- Old: `pharos.ai-hyperscaler-on-workskation`
- New: `ai-hyperscaler-on-workskation`
- Short name: `ai-how`

### Team/Author
- Old: `Pharos AI Hyperscaler Team`
- New: `AI-HOW Team`

## Migration Steps

1. Pull latest changes
2. Rebuild Docker image: `make build-docker`
3. Remove old image: `docker rmi pharos-dev:latest`
4. Update any custom scripts referencing old names
5. Update environment variables if you have PROJECT_ROOT set
6. Run tests to verify: `make test`

## Backward Compatibility
- No API changes in Python packages
- Configuration file formats unchanged
- Ansible playbooks remain compatible
- Only branding/naming changes
```

**Validation:**

```bash
# Verify migration guide completeness
markdownlint docs/MIGRATION-FROM-PHAROS.md

# Final comprehensive check
git ls-files | xargs grep -li "pharos"

# Verify no unexpected changes
git status
git diff
```

**Notes:**

- Keep migration guide for at least one major version
- Consider adding automated migration script if needed
- Update release notes with migration information

---

## Summary of Changes by File Type

### Configuration Files (3 files)

- mkdocs.yml - Site configuration and branding
- pyproject.toml - Python package metadata
- Makefile - Docker image naming

### Documentation (8 files)

- README.md - Main project documentation
- Various design docs - Technical documentation
- Task lists - Implementation guides
- Test documentation - Testing guides

### Scripts (5 files)

- Docker scripts - Container management
- Setup scripts - Environment setup
- Test scripts - Testing infrastructure

### Source Code (2 files)

- Python init file - Package metadata
- Dockerfile - Container labels

### Generated Files (9 files)

- Log files - Will be regenerated
- Diff files - Can be cleaned
- Review files - Can be updated or removed

---

## Testing Strategy

### Unit Testing

After each phase, verify:

- File syntax is valid
- No broken references
- Functionality preserved

### Integration Testing

After Phase 3, verify:

- Docker containers build and run
- Documentation builds successfully
- Scripts execute correctly
- Tests pass

### End-to-End Testing

After Phase 4, verify:

- Complete workflow works
- No pharos references remain
- All tools function properly
- Documentation is accurate

---

## Rollback Strategy

If issues arise during implementation:

1. **Per-Task Rollback:**

   ```bash
   git checkout HEAD -- <modified-files>
   ```

2. **Phase Rollback:**

   ```bash
   git reset --hard <commit-before-phase>
   ```

3. **Complete Rollback:**

   ```bash
   git reset --hard <commit-before-refactoring>
   ```

**Prevention:**

- Commit after each completed task
- Test thoroughly after each phase
- Keep backup of working state

---

## Post-Implementation Checklist

- [ ] All pharos references removed from source code
- [ ] All pharos references removed from documentation
- [ ] Docker image rebuilt with new name
- [ ] Old Docker images cleaned up
- [ ] Documentation builds successfully
- [ ] All tests pass
- [ ] Migration guide created
- [ ] CHANGELOG updated
- [ ] Version numbers updated
- [ ] Final verification complete
- [ ] Changes committed and pushed
- [ ] Team notified of changes

---

## Notes and Considerations

### Decisions Made ✅

1. **Project Name:** `ai-hyperscaler-on-workskation` (keeping the original spelling)
2. **Short Name:** `ai-how`
3. **Docker Image:** `ai-how-dev`
4. **Team Name:** `AI-HOW Team`

### Important Decisions Still Needed ⏳

1. **GitHub Organization/Username:** What should replace `pharos-ai` in URLs? ✅ RESOLVED
   - Example: `github.com/idoudali/ai-hyperscaler-on-workskation`
   - Affects: mkdocs.yml, pyproject.toml, documentation links

2. **GitHub Pages URL:** Where will documentation be hosted? ✅ RESOLVED
   - Example: `idoudali.github.io/ai-hyperscaler-on-workskation`
   - Or: Custom domain?
   - Affects: mkdocs.yml site_url

3. **Copyright Statement:** How should copyright be handled?
   - Option A: `Copyright © 2024-2025 AI-HOW Team`
   - Option B: Remove copyright statement entirely
   - Option C: Your specific copyright text
   - Affects: mkdocs.yml, documentation footers

4. **PyPI Package Name:** If publishing to PyPI, what should the package name be?
   - Current: `ai-how` (in python/ai_how/)
   - This seems good, just confirming it's available on PyPI

### Impact Assessment

**Low Impact:**

- Documentation changes
- Comment changes
- Log messages

**Medium Impact:**

- Docker image name changes
- Python package metadata
- Configuration files

**High Impact:**

- None expected - all changes are primarily cosmetic and don't affect functionality

### Timeline Estimate

- Phase 1 (Configuration): ~1.5 hours
- Phase 2 (Documentation): ~3.5 hours
- Phase 3 (Source Code): ~1 hour
- Phase 4 (Cleanup & Validation): ~2 hours
- **Total Estimated Time:** ~8 hours

### Dependencies and Prerequisites

- Git working directory should be clean
- Docker should be available
- Build environment should be set up
- All tests should be passing before starting

---

## References

- **TODO**: **Workspace Rules: Commit Workflow** - Create .cursorrules file with commit workflow rules
- **TODO**: **Markdown Formatting Standards** - Create .cursorrules file with markdown formatting standards
- [Development Container Configuration](../../docker/README.md)

---

**Last Updated:** 2025-10-16
**Status:** Ready for implementation
**Next Action:** Review plan and begin with TASK-001
