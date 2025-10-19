# Component-Specific Documentation (Category 5)

**Status:** Planning
**Created:** 2025-10-16
**Last Updated:** 2025-10-16

**Priority:** 2-3 - Component References

Documentation that lives next to the code implementing each component.

## Overview

Category 5 focuses on creating and enhancing documentation that lives with the code components. Following the
principle that "component documentation lives with the component, not in docs/".

## TASK-DOC-028: Ansible Documentation

**Files:** `ansible/README.md`, `ansible/roles/README.md`, `ansible/playbooks/README.md`, role-specific READMEs

**Description:** Comprehensive Ansible documentation next to playbooks and roles

**Content:**

- `ansible/README.md`: Ansible overview, directory structure, usage guide
- `ansible/roles/README.md`: Roles index, how to use roles, common patterns
- `ansible/playbooks/README.md`: Playbooks index, usage examples, common workflows
- Individual role READMEs: Purpose, variables, dependencies, examples, tags

**Success Criteria:**

- [ ] Main Ansible README updated
- [ ] Roles index created
- [ ] Playbooks index created
- [ ] All major roles have README files
- [ ] Variables and dependencies documented
- [ ] Usage examples included

## TASK-DOC-029: Packer Documentation ✅ COMPLETED

**Files:** `packer/README.md`, `packer/hpc-base/README.md`, `packer/hpc-controller/README.md`, `packer/hpc-compute/README.md`

**Description:** Packer template documentation next to templates

**Content:**

- `packer/README.md`: Packer overview, build system, usage guide
- Image-specific READMEs: Purpose, provisioners, variables, build instructions, testing

**Success Criteria:**

- [x] Main Packer README updated
- [x] Base image documentation created
- [x] Controller image documentation created
- [x] Compute image documentation created
- [x] Build instructions clear
- [x] Variables documented

**Completion Notes:**

- Comprehensive documentation overhaul completed in commit ac82167a3b912a489384a46a98ab678874808d9a
- All Packer image READMEs updated from TODO to Production status
- Added Docker container build workflow and detailed build instructions
- Documented Debian 13 base image configuration and shared role-based architecture
- Added comprehensive troubleshooting, customization, and design decision sections
- All success criteria met with extensive documentation coverage

## TASK-DOC-030: Container Documentation

**Files:** `containers/README.md`, per-container READMEs

**Description:** Container definitions and build instructions

**Content:**

- `containers/README.md`: Container overview, build system, registry deployment
- Container-specific READMEs: Purpose, base image, dependencies, build instructions, usage

**Success Criteria:**

- [ ] Main containers README updated
- [ ] Build process documented
- [ ] Deployment process documented
- [ ] Major containers have documentation
- [ ] Usage examples included

## TASK-DOC-031: Python CLI Documentation

**Files:** `python/ai_how/README.md`, `python/ai_how/docs/*`

**Description:** Enhance existing CLI documentation

**Note:** python/ai_how already has comprehensive documentation in its docs/ subdirectory

**Content:**

- Ensure CLI reference is complete
- Document all commands with examples
- Configuration file reference
- Development guide
- API documentation

**Success Criteria:**

- [ ] CLI reference complete (already exists)
- [ ] All commands documented
- [ ] Configuration reference updated
- [ ] Development guide current
- [ ] API docs generated

## TASK-DOC-032: Scripts Documentation

**Files:** `scripts/README.md`, `scripts/system-checks/README.md`

**Description:** Utility scripts documentation

**Content:**

- `scripts/README.md`: Scripts overview, categories, usage patterns
- `scripts/system-checks/README.md`: System check scripts purpose and usage
- Script-level docstrings/comments

**Success Criteria:**

- [ ] Main scripts README created
- [ ] System checks documented
- [ ] Common patterns explained
- [ ] Usage examples provided

## TASK-DOC-033: Configuration Documentation

**File:** `config/README.md`

**Description:** Configuration files reference

**Content:**

- Configuration file format and schema
- Available options and defaults
- Validation rules
- Examples for common scenarios
- Environment-specific configurations

**Success Criteria:**

- [ ] Configuration schema documented
- [ ] All options explained
- [ ] Examples provided
- [ ] Validation rules clear

## Component Documentation Standards

**Component Documentation Should:**

- **Live with the code** - README files in component directories
- **Focus on implementation details** - how the component works
- **Include usage examples** - practical code/command examples
- **Document configuration options** - all available settings
- **Reference related components** - integration points
- **Include development guidelines** - contributing to the component

**Component Documentation Structure:**

- **Main README:** Component overview and directory structure
- **Sub-component READMEs:** Specific roles/templates/containers
- **Usage examples:** Practical implementation guides
- **Configuration reference:** All options and defaults
- **Development guide:** How to extend or modify

**Target Audience:**

- Contributors working on specific components
- Developers integrating with component APIs
- Operations teams configuring components
- Users customizing component behavior

**Success Metrics:**

- Contributors can work on components independently
- Integration between components is well documented
- Configuration options are discoverable and understandable
- Development workflow for each component is clear

## Integration with Other Categories

**Components -> High-Level Docs:**

- Component docs provide technical implementation details
- High-level docs provide user-facing usage guides
- Architecture docs explain integration between components

**Components -> Operations:**

- Component docs focus on configuration and setup
- Operations docs focus on management and maintenance
- Integration ensures operational procedures work with component capabilities

**Components -> Troubleshooting:**

- Component docs help understand component behavior
- Troubleshooting uses component knowledge for diagnosis
- Bridge provides context for both normal and error conditions

See [Implementation Priority](../implementation-priority.md) for timeline integration.
