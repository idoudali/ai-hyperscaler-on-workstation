# Open Source Preparation Plan

This document outlines the comprehensive plan to remove all Pharos references from the hyperscaler-on-workstation
repository to prepare it for open-source release.

## Executive Summary

**Analysis Results:**

- **44 direct "Pharos" references** found across **11 files**
- **Additional company references** found in **23 files** total
- **22 distinct tasks** identified for complete sanitization
- **Apache 2.0 License** already in place ✅
- **No sensitive data or API keys** detected ✅

**Timeline Estimate:** 4-6 hours for complete cleanup

## Analysis Overview

### Critical Findings

The repository contains extensive references to "Pharos" and "pharos.ai" primarily in:

1. **Infrastructure naming** (directory names, Docker images, network configs)
2. **Documentation** (design docs with 25+ references)
3. **Configuration files** (Python packages, MkDocs, scripts)
4. **Temporary files** (logs, build outputs, diffs)

### Repository Strengths for Open Source

✅ **Clean Technical Architecture** - Core infrastructure code is well-designed and company-agnostic  
✅ **Comprehensive Documentation** - Extensive design docs and implementation guides  
✅ **Professional Tooling** - Pre-commit hooks, linting, conventional commits  
✅ **Open Source License** - Apache 2.0 already applied  
✅ **No Security Issues** - No hardcoded secrets or proprietary APIs found  

## Task Breakdown

### 🔴 High Priority Tasks (Must Complete)

These tasks are critical for open-source readiness and must be completed first:

#### 1. Core Infrastructure Renaming

- **Task:** Rename root directory from `pharos.ai-hyperscaler-on-workskation` to `hyperscaler-on-workstation`
- **Impact:** Critical - affects all path references
- **Files:** Root directory

#### 2. Build Configuration Updates

- **Task:** Update Docker image name from `pharos-dev` to generic name in Makefile
- **Impact:** High - affects build process
- **Files:** `Makefile`

#### 3. Python Package Metadata

- **Task:** Remove Pharos.ai author references from python/ai_how/pyproject.toml
- **Impact:** High - visible in package distribution
- **Files:** `python/ai_how/pyproject.toml`

#### 4. Documentation System

- **Task:** Update mkdocs.yml to remove pharos-ai GitHub references and site_author
- **Impact:** High - affects documentation generation
- **Files:** `python/ai_how/mkdocs.yml`

#### 5. Design Documentation Overhaul

- **Task:** Remove/replace 25+ Pharos references in design documents
- **Impact:** Critical - most visible to users
- **Files:** `docs/design-docs/hyperscaler-on-workstation.md`

#### 6. Script Path Updates

- **Task:** Update hardcoded paths in experimental scripts
- **Impact:** Medium - affects script functionality
- **Files:** `scripts/experiments/start-gpu-passthrough-vm.sh`

### 🟡 Medium Priority Tasks (Important)

#### 7. Implementation Documentation

- **Task:** Clean company references from implementation plans and task lists
- **Files:**
  - `docs/implementation-plans/task-lists/hpc-slurm-task-list.md`
  - `docs/design-docs/project-plan.md`
  - `docs/implementation-plans/` (various files)

#### 8. Container Documentation

- **Task:** Update container-related documentation
- **Files:**
  - `scripts/experiments/README.md`
  - `docker/README.md`
  - `docker/Dockerfile`

#### 9. Infrastructure Configuration

- **Task:** Check Packer configuration files for company references
- **Files:** `packer/hpc-base/hpc-base.pkr.hcl`, `packer/cloud-base/cloud-base.pkr.hcl`

#### 10. Legacy Directory Cleanup

- **Task:** Remove empty 'pharosctl' directory
- **Files:** `pharosctl/` (empty directory)

### 🟢 Low Priority Tasks (Cleanup)

#### 11-18. Temporary File Cleanup

- **Task:** Clean or remove temporary files containing references
- **Files:**
  - `LOG` (multiple instances)
  - `BUILD_LOG`
  - `DIFF`
  - `review.md`
  - `python/ai_how/LICENSE`

#### 19-22. Final Preparations

- **Task:** Final scan, README review, license verification, contribution guide
- **Files:** `README.md`, `LICENSE`, potential new `CONTRIBUTING.md`

## Implementation Strategy

### Phase 1: Core Infrastructure (Days 1-2)

1. Rename root directory
2. Update all build configurations
3. Fix Python package metadata
4. Update documentation system configs

### Phase 2: Documentation Overhaul (Days 2-3)

1. Systematically clean design documents
2. Update all implementation plans
3. Fix script documentation
4. Review Docker/Packer files

### Phase 3: Cleanup & Validation (Day 4)

1. Remove temporary files
2. Final comprehensive scan
3. Test all build processes
4. Verify documentation generation

### Phase 4: Enhancement (Optional)

1. Add CONTRIBUTING.md
2. Enhance README for open source community
3. Add issue templates
4. Set up GitHub Actions (if using GitHub)

## Quality Assurance Checklist

### Pre-Release Validation

- [ ] All grep searches for "pharos" return zero results
- [ ] All build processes work with new names
- [ ] Documentation builds successfully
- [ ] All scripts run with updated paths
- [ ] License compliance verified
- [ ] README reflects open-source status

### Testing Strategy

- [ ] Full build test with `make` commands
- [ ] Documentation generation test
- [ ] Python package installation test
- [ ] Script execution test with new paths
- [ ] Grep validation for missed references

## Risk Assessment

### Low Risk Items

- Documentation updates (easily reversible)
- Temporary file removal
- Directory renaming (with proper git handling)

### Medium Risk Items

- Build configuration changes (test thoroughly)
- Python package metadata changes
- Script path updates

### Mitigation Strategies

- Create feature branch for all changes
- Test each change incrementally
- Maintain backup of original repository
- Document all changes made

## Success Metrics

1. **Zero References:** No "pharos" or company-specific terms found in repository
2. **Full Functionality:** All build processes and scripts work correctly
3. **Clean Documentation:** All docs read naturally without company references
4. **Professional Presentation:** Repository looks polished and welcoming to contributors

## Next Steps

1. **Create working branch:** `git checkout -b prepare-open-source`
2. **Begin with high-priority tasks**
3. **Test each change before proceeding**
4. **Complete validation checklist**
5. **Create pull request for review**

## File Change Summary

### Files Requiring Major Changes

- `docs/design-docs/hyperscaler-on-workstation.md` (25+ references)
- `python/ai_how/mkdocs.yml` (GitHub repos, site author)
- `python/ai_how/pyproject.toml` (author field)
- `scripts/experiments/start-gpu-passthrough-vm.sh` (hardcoded paths)

### Files Requiring Minor Changes

- `Makefile` (Docker image name)
- `scripts/experiments/README.md` (project reference)
- Various documentation files (scattered references)

### Files for Removal/Cleanup

- `LOG` files (multiple)
- `BUILD_LOG`
- `DIFF`
- `review.md`
- `pharosctl/` directory

## Repository Value Proposition

This repository will provide significant value to the open-source community:

- **Advanced GPU Infrastructure:** Complete MIG GPU partitioning and management
- **Hybrid Architecture:** HPC SLURM + Kubernetes cloud on single workstation
- **Production Ready:** Professional tooling, testing, and documentation
- **Educational Resource:** Comprehensive guides for complex infrastructure setup
- **Automation Focus:** Fully automated deployment with Ansible, Packer, Terraform

The cleanup effort will unlock this valuable technical resource for the broader community.
