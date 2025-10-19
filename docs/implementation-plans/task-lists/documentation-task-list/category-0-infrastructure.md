# Documentation Infrastructure (Category 0)

**Status:** Planning
**Created:** 2025-10-16
**Last Updated:** 2025-10-16

**Priority:** 0 - Foundation (MUST complete before all other phases)

Create the foundational documentation structure before content population.

## Overview

Category 0 tasks establish the documentation infrastructure and directory structure. These tasks must be completed
before any content creation begins.

## TASK-DOC-000: Create Documentation Structure with Placeholder Files

**Description:** Create all directories and placeholder files for the new documentation structure

**Content:**

- Create 5 new high-level documentation directories in `docs/`:
  - `docs/getting-started/` - User onboarding
  - `docs/tutorials/` - End-to-end learning paths
  - `docs/architecture/` - System-wide architecture
  - `docs/operations/` - Cross-component operations
  - `docs/troubleshooting/` - Cross-component troubleshooting
- Create `docs/workflows/` and move existing workflow files
- Create 31 placeholder markdown files with consistent format
  **Note:** Component-specific documentation (CLI reference, Ansible roles, etc.) lives next to code, not in docs/
- Each placeholder includes:
  - Document title
  - Status: TODO marker
  - Last Updated date
  - Brief overview of intended content
- Create structure documentation files:
  - `DOCUMENTATION-STRUCTURE.md` - Complete structure overview
  - `STRUCTURE-VERIFICATION.md` - Verification checklist
  - `PLACEHOLDER-CREATION-SUMMARY.md` - Creation summary

**Files Created:**

**Getting Started (7 files):**

- prerequisites.md
- installation.md
- quickstart-5min.md
- quickstart-cluster.md
- quickstart-gpu.md
- quickstart-containers.md
- quickstart-monitoring.md

**Tutorials (7 files):**

- 01-first-cluster.md
- 02-distributed-training.md
- 03-gpu-partitioning.md
- 04-container-management.md
- 05-custom-images.md
- 06-monitoring-setup.md
- 07-job-debugging.md

**Architecture (7 files):**

- overview.md
- network.md
- storage.md
- gpu.md
- containers.md
- slurm.md
- monitoring.md

**Operations (6 files):**

- deployment.md
- maintenance.md
- backup-recovery.md
- scaling.md
- security.md
- performance-tuning.md

**Troubleshooting (4 files):**

- common-issues.md
- debugging-guide.md
- faq.md
- error-codes.md

**Placeholder Format:**

```markdown
# [Document Title]

**Status:** TODO
**Last Updated:** 2025-10-16

## Overview

TODO: Brief description of document content.
```

**Success Criteria:**

- [ ] All 5 new high-level directories created in docs/
- [ ] All 31 placeholder files created with consistent format
- [ ] Existing workflow files organized into workflows/ directory
- [ ] Structure documentation files created
- [ ] Directory structure verified with `tree` command
- [ ] All placeholders searchable with `grep -r "Status: TODO"`
- [ ] Structure approved before content population begins
- [ ] Component-specific documentation remains in component directories

**Verification Commands:**

```bash
# Verify high-level documentation structure
cd docs && tree -L 2 --dirsfirst

# Count placeholder files (31 expected)
find docs/{getting-started,tutorials,architecture,operations,troubleshooting} \
  -type f -name "*.md" | wc -l

# Find all TODO placeholders
grep -r "Status: TODO" docs/{getting-started,tutorials,architecture,operations,troubleshooting}

# Verify workflows organized
ls -1 docs/workflows/

# Verify component-specific docs remain with code
ls -1 ansible/README.md packer/README.md python/ai_how/README.md containers/README.md config/README.md
```

**Benefits:**

- **Visual Structure:** Complete documentation organization visible before writing
- **Early Feedback:** Structure can be reviewed and adjusted before content investment
- **Clear Scope:** Shows exactly what documentation will be created
- **Parallel Work:** Multiple contributors can work on different sections
- **Progress Tracking:** Easy to see which documents are complete vs TODO

## TASK-DOC-001: Update MkDocs Configuration

**File:** `mkdocs.yml`

**Description:** Update MkDocs configuration to reflect new documentation structure, creating navigation that will
be populated as content is added

**Prerequisites:** TASK-DOC-000 completed (directory structure created)

**Current State Analysis:**

The current `mkdocs.yml` has:

- Outdated navigation structure
- Mostly commented-out design and implementation plan sections
- Component docs navigation (correct - these stay with code)
- Missing navigation for new high-level docs (getting-started, tutorials, architecture, operations, workflows, troubleshooting)

**Content:**

Update `mkdocs.yml` navigation to include:

```yaml
nav:
  - Home: index.md
  - Getting Started:
      - Prerequisites: getting-started/prerequisites.md
      - Installation: getting-started/installation.md
      - 5-Minute Quickstart: getting-started/quickstart-5min.md
      - Cluster Quickstart: getting-started/quickstart-cluster.md
      - GPU Quickstart: getting-started/quickstart-gpu.md
      - Container Quickstart: getting-started/quickstart-containers.md
      - Monitoring Quickstart: getting-started/quickstart-monitoring.md
  - Tutorials:
      - First Cluster: tutorials/01-first-cluster.md
      - Distributed Training: tutorials/02-distributed-training.md
      - GPU Partitioning: tutorials/03-gpu-partitioning.md
      - Container Management: tutorials/04-container-management.md
      - Custom Images: tutorials/05-custom-images.md
      - Monitoring Setup: tutorials/06-monitoring-setup.md
      - Job Debugging: tutorials/07-job-debugging.md
  - Architecture:
      - Overview: architecture/overview.md
      - Network: architecture/network.md
      - Storage: architecture/storage.md
      - GPU: architecture/gpu.md
      - Containers: architecture/containers.md
      - SLURM: architecture/slurm.md
      - Monitoring: architecture/monitoring.md
  - Operations:
      - Deployment: operations/deployment.md
      - Maintenance: operations/maintenance.md
      - Backup & Recovery: operations/backup-recovery.md
      - Scaling: operations/scaling.md
      - Security: operations/security.md
      - Performance Tuning: operations/performance-tuning.md
  - Workflows:
      - Cluster Deployment: workflows/CLUSTER-DEPLOYMENT-WORKFLOW.md
      - GPU GRES: workflows/GPU-GRES-WORKFLOW.md
      - SLURM Compute: workflows/SLURM-COMPUTE-WORKFLOW.md
      - Apptainer Conversion: workflows/APPTAINER-CONVERSION-WORKFLOW.md
      - Virtio-FS Integration: workflows/VIRTIO-FS-INTEGRATION.md
  - Troubleshooting:
      - Common Issues: troubleshooting/common-issues.md
      - Debugging Guide: troubleshooting/debugging-guide.md
      - FAQ: troubleshooting/faq.md
      - Error Codes: troubleshooting/error-codes.md
  - Design Documents:
      - Project Plan: design-docs/project-plan.md
      - Hyperscaler on Workstation: design-docs/hyperscaler-on-workstation.md
      - Open Source Solutions: design-docs/open-source-solutions.md
  - Components:
      - Ansible:
          - Overview: ../ansible/README.md
          - Roles Index: ../ansible/roles/README.md
          - Playbooks Index: ../ansible/playbooks/README.md
      - Packer:
          - Overview: ../packer/README.md
          - Base Image: ../packer/hpc-base/README.md
          - Controller Image: ../packer/hpc-controller/README.md
          - Compute Image: ../packer/hpc-compute/README.md
      - Containers:
          - Overview: ../containers/README.md
      - Configuration:
          - Overview: ../config/README.md
      - Scripts:
          - Overview: ../scripts/README.md
          - System Checks: ../scripts/system-checks/README.md
  - CLI (ai-how):
      - Overview: ../python/ai_how/README.md
      - Getting Started: ../python/ai_how/docs/index.md
      - Examples: ../python/ai_how/docs/examples.md
      - Development: ../python/ai_how/docs/development.md
      - Network Configuration: ../python/ai_how/docs/network_configuration.md
      - PCIe Validation: ../python/ai_how/docs/pcie-passthrough-validation.md
  - Testing:
      - Overview: ../tests/README.md
```

**Key Changes:**

1. **New High-Level Sections:**
   - Getting Started (7 pages)
   - Tutorials (7 pages)
   - Architecture (7 pages)
   - Operations (6 pages)
   - Workflows (5 pages, organized from scattered locations)
   - Troubleshooting (4 pages)

2. **Component References:**
   - Keep component docs in their original locations
   - Use relative paths (`../ansible/`, `../packer/`, etc.)
   - This follows the principle: component docs stay with code

3. **Removed/Reorganized:**
   - Remove commented-out sections
   - Uncomment and organize design docs properly
   - Update paths to reflect new structure

4. **Site Metadata Updates:**
   - Update site_name to remove "Pharos.ai" prefix (if needed)
   - Verify repo URLs are correct
   - Update copyright if needed

**Rationale for Early Execution:**

Setting up MkDocs navigation early allows:

- Pages appear in navigation as they're created
- Consistent structure from the start
- Easy verification that files are in the right place
- Contributors can see the overall documentation plan
- MkDocs build can validate file locations incrementally

**Success Criteria:**

- [ ] MkDocs configuration updated with new navigation structure
- [ ] All high-level docs properly linked (getting-started, tutorials, architecture, operations, workflows, troubleshooting)
- [ ] Component docs referenced via relative paths
- [ ] Site builds successfully (`mkdocs build`) with placeholder files
- [ ] Navigation is logical and user-friendly
- [ ] Placeholder links work (even if content is empty)
- [ ] Search functionality works
- [ ] Site can be served locally (`mkdocs serve`)

**Testing Commands:**

```bash
# Install/update dependencies
pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin \
    mkdocs-include-markdown-plugin mkdocstrings[python]

# Build and test locally
mkdocs build
mkdocs serve

# Verify navigation structure in browser at http://127.0.0.1:8000
# Empty pages are expected at this stage
```

**Notes:**

- Component docs (ansible/, packer/, python/ai_how/, etc.) are referenced, not moved
- This maintains the principle of keeping component docs with code
- MkDocs can reference files outside the docs/ directory using relative paths
- Empty placeholder files will show in navigation - this is expected and correct
- As content is added to each file, it will automatically appear on the site

## Next Steps

After completing Category 0 tasks:

1. Structure is ready for content population
2. MkDocs navigation shows complete documentation plan
3. Contributors can begin working on Phase 1 content
4. Progress can be tracked by filling in placeholders

See [Implementation Priority](../implementation-priority.md) for next phase details.
