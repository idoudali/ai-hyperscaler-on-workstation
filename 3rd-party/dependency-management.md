# Dependency Management Strategy

**Status:** Production
**Created:** 2025-10-24
**Last Updated:** 2025-10-24

## Overview

This document outlines the strategy for managing third-party dependencies in the AI-HOW project,
including version control, security updates, and integration into the build system.

## Dependency Inventory

### System Dependencies (OS-Level)

System dependencies are specified in `docker/Dockerfile` and installed at build time:

| Dependency | Version | Purpose | License |
|------------|---------|---------|---------|
| build-essential | latest | C/C++ compilation tools | GPL |
| python3-dev | 3.11 | Python development headers | Python Software Foundation |
| libvirt-dev | latest | Libvirt client libraries | LGPL 2.1 |
| libevent-dev | latest | Event processing library | BSD |
| pkg-config | latest | Library discovery tool | GPL |
| zlib1g-dev | latest | Compression library | zlib license |

### Third-Party Components Built from Source

| Component | Version | Location | License | Notes |
|-----------|---------|----------|---------|-------|
| BeeGFS | 7.4.10 | `3rd-party/beegfs/` | BeeGFS EULA | Distributed filesystem |
| SLURM | 24.11.0 | `3rd-party/slurm/` | SLURM Apache 2.0 | Workload manager |

### Python Dependencies

Python dependencies are specified in `python/ai_how/pyproject.toml` and managed through uv/pip:

See `python/ai_how/pyproject.toml` for complete list with versions and licenses.

## Version Management Strategy

### Fixed Versions

Critical dependencies use pinned, tested versions:

```yaml
# Build-time (docker/Dockerfile)
PYTHON_VERSION: 3.11.x

# Third-party components (CMakeLists.txt)
BEEGFS_VERSION: 7.4.10
SLURM_VERSION: 24.11.0
```

**Rationale**: Infrastructure components require stability. Careful testing and documentation required for updates.

### Flexible Versions

Less critical components use flexible version specifications:

```python
# Development tools (python/ai_how/pyproject.toml)
pytest>=7.0.0       # Accept patch updates
ruff>=0.1.0         # Accept minor updates
```

**Rationale**: Development tools benefit from latest bug fixes. Minimal breaking change risk.

## Version Update Procedures

### Step 1: Check for Updates

```bash
# For Python dependencies
pip list --outdated | grep <package>

# For system libraries
apt-cache policy <package>

# For third-party components
# Check official websites for new releases
```

### Step 2: Review Release Notes

Before updating any dependency:

1. **Read Official Release Notes**: Check for breaking changes, security fixes, new features
2. **Check Changelog**: Look for items affecting our use cases
3. **Review Security Advisories**: Check CVE databases for security updates
4. **Test Compatibility**: Ensure updated version works with other dependencies

### Step 3: Update Configuration

**For Python dependencies** (`python/ai_how/pyproject.toml`):

```toml
[project.optional-dependencies]
dev = [
    "pytest>=7.5.0",  # Update version constraint
    "mypy>=1.8.0",
]
```

**For third-party components** (`3rd-party/CMakeLists.txt` or specific component):

```cmake
set(SLURM_VERSION 24.12.0)  # Update version
set(SLURM_DOWNLOAD_URL "https://download.schedmd.com/slurm/slurm-24.12.0.tar.bz2")
```

**For system dependencies** (`docker/Dockerfile`):

```dockerfile
RUN apt-get install -y libvirt-dev=X.Y.Z  # Specify exact version if needed
```

### Step 4: Test Updates Locally

```bash
# For Python dependencies
make venv-create
make lint-ai-how
make test-ai-how

# For third-party components
cmake --build build --target build-beegfs-packages
cmake --build build --target build-slurm-packages

# For Docker image
make build-docker
```

### Step 5: Document and Commit

```bash
# Update this file with change notes
# Add entry to version history

git add python/ai_how/pyproject.toml 3rd-party/CMakeLists.txt DEPENDENCY-MANAGEMENT.md
git commit -m "feat: update dependencies

- Update pytest from 7.0 to 7.5 (adds new assertion types)
- Update SLURM from 24.11.0 to 24.12.0 (includes GPU autodetect improvements)

See DEPENDENCY-MANAGEMENT.md for full changelog"
```

## Security Update Process

### Vulnerability Disclosure

When a security vulnerability is discovered:

1. **Assess Impact**: Does the vulnerability affect our use of this component?
2. **Evaluate Fix**: Is a patched version available? What's the risk?
3. **Update Priority**: Security fixes are higher priority than feature updates
4. **Test Thoroughly**: Extra testing required for security updates
5. **Document and Deploy**: Add notes to this file, commit, and update deployments

### Critical Security Updates

For critical vulnerabilities affecting deployed systems:

1. **Immediate Assessment**: Determine if systems are vulnerable
2. **Risk Evaluation**: Balance update risk vs. security risk
3. **Emergency Update**: May bypass normal testing procedures if necessary
4. **Deployment Communication**: Notify operations team
5. **Post-Incident Review**: Document what happened and lessons learned

### Regular Audits

Perform security audits regularly:

```bash
# Python dependency security scan
pip audit

# OS-level package updates
apt-cache policy <package>  # Check for available updates

# Check CVE databases
# https://cve.mitre.org/
# https://nvd.nist.gov/
```

## Customization and Patching

### When to Patch

Patch third-party components when:

- A bug fix is available but not yet released
- Custom configuration needed for our infrastructure
- Security patch needed before official release
- Performance optimization required

### Patch Application Process

**For BeeGFS**:

1. Extract source from built package or download
2. Apply patch using `patch` command
3. Rebuild with modified source
4. Test thoroughly
5. Document patch in `3rd-party/beegfs/README.md`

```bash
cd build/3rd-party/beegfs/beegfs-7.4.10
patch -p1 < /path/to/custom.patch
cd ../../../
cmake --build build --target build-beegfs-packages
```

**For SLURM**:

1. Extract SLURM source
2. Apply patch using `patch` command
3. Rebuild packages
4. Test on compute nodes
5. Document patch in `3rd-party/slurm/README.md`

```bash
cd build/3rd-party/slurm/slurm-24.11.0
patch -p1 < /path/to/custom.patch
cd ../../../
cmake --build build --target build-slurm-packages
```

**For Python Dependencies**:

1. Report issue upstream (preferred)
2. If patch needed immediately, pin to forked version in `pyproject.toml`
3. Update once official fix is available

```toml
# Temporary patch version
problematic-package = {git = "https://github.com/ourorg/fork.git", rev = "patch-name"}

# After official fix
problematic-package = ">=1.2.3"
```

### Patch Documentation

Document all patches in this file:

```markdown
## Active Patches

### BeeGFS 7.4.10

- **Patch**: GPU performance fix
  - **File**: `build/3rd-party/beegfs/0001-gpu-optimization.patch`
  - **Reason**: Improves BeeGFS performance on GPU nodes
  - **Status**: Submitted upstream, pending review
  - **Impact**: No breaking changes

### SLURM 24.11.0

- None currently
```

## Adding New Dependencies

### When to Add

Add new dependencies only when:

- Required functionality not available in current dependencies
- Solves significant architectural problem
- Benefits outweigh added complexity
- License compatible with project license

### Evaluation Checklist

Before adding new dependency:

- [ ] Verify license compatibility
- [ ] Check security history (CVE databases)
- [ ] Evaluate maintenance status (active development?)
- [ ] Confirm version stability (avoid beta/alpha versions)
- [ ] Test with existing dependencies
- [ ] Document purpose and integration
- [ ] Identify potential alternatives
- [ ] Get team approval

### Integration Process

1. **Add to Configuration**
   - Update `docker/Dockerfile` for system dependencies
   - Update `pyproject.toml` for Python packages
   - Update `CMakeLists.txt` for third-party components

2. **Update Documentation**
   - Add to inventory table in this file
   - Document licensing implications
   - Note integration points
   - Include build/install instructions

3. **Test and Commit**

   ```bash
   # Test build
   make build-docker
   make venv-create
   make test-ai-how

   # Commit
   git add Dockerfile pyproject.toml DEPENDENCY-MANAGEMENT.md
   git commit -m "feat: add new dependency xyz

   - Purpose: [specific reason]
   - Version: [specific version]
   - License: [license type]

   See DEPENDENCY-MANAGEMENT.md for details"
   ```

## Version History

Track significant dependency updates here:

| Date | Component | Old → New | Reason | Status |
|------|-----------|-----------|--------|--------|
| 2025-10-24 | SLURM | 24.11.0 → 24.11.0 | Initial documentation | Active |
| 2025-10-24 | BeeGFS | 7.4.10 → 7.4.10 | Initial documentation | Active |
| 2025-01-20 | Python | 3.11 → 3.11 | Project initialization | Active |

## Dependency Conflicts

When two dependencies have conflicting requirements:

1. **Identify Conflict**: Determine which constraints conflict
2. **Evaluate Options**:
   - Update one or both to compatible versions
   - Find alternative packages with different constraints
   - Use conditional dependencies or separate environments
3. **Document Decision**: Add notes to this file explaining resolution
4. **Test Thoroughly**: Extra testing needed for conflict resolutions

## License Compliance

All dependencies must have licenses compatible with this project:

- **Project License**: Verify with `LICENSE` file
- **Dependency Licenses**: Document in inventory above
- **Compliance**: Ensure all dependencies can be legally used together
- **Attribution**: Include in `LICENSE` file or documentation as needed

## Tools and Commands

### Check for Outdated Dependencies

```bash
# Python packages
pip list --outdated

# OS packages
apt list --upgradable

# Security vulnerabilities
pip audit
```

### Build and Test

```bash
# Full build
make clean build-docker

# Python test suite
make test-ai-how
make lint-ai-how

# Third-party packages
cmake --build build --target build-beegfs-packages
cmake --build build --target build-slurm-packages
```

### Documentation

```bash
# View this document
cat 3rd-party/DEPENDENCY-MANAGEMENT.md

# View component docs
cat 3rd-party/beegfs/README.md
cat 3rd-party/slurm/README.md

# View Python dependencies
cat python/ai_how/pyproject.toml
```

## Related Documentation

- **Build System**: `docs/architecture/build-system.md`
- **BeeGFS Build**: `3rd-party/beegfs/README.md`
- **SLURM Build**: `3rd-party/slurm/README.md`
- **Custom Builds**: `3rd-party/CUSTOM-BUILDS.md`
- **Docker Environment**: `docker/README.md`
- **Python Setup**: `python/ai_how/docs/development.md`

## Contact and Questions

For questions about dependency management:

1. Review this document first
2. Check component-specific READMEs
3. Review recent commits for similar changes
4. Ask on project discussion forum/channels
