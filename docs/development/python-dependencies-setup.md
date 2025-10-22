# Python Dependencies Setup Guide

This document explains how to set up the Python dependencies for the AI-HOW project
and resolve common issues.

## Overview

The AI-HOW project requires several Python packages, with `libvirt-python` being
the most critical as it provides Python bindings for libvirt virtualization
management.

## Required System Packages

Before installing Python packages, ensure these system packages are installed:

```bash
# Core virtualization packages
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    ebtables \
    dnsmasq-base

# Python development dependencies
sudo apt-get install -y \
    python3-dev \
    python3-pip \
    python3-venv \
    build-essential \
    python3-setuptools \
    python3-wheel

# libvirt development libraries (CRITICAL for libvirt-python)
sudo apt-get install -y \
    libvirt-dev \
    pkg-config
```

## Resolving the libvirt Issue

The error you encountered:

```text
pkg-config --libs-only-L libvirt
Package libvirt was not found in the pkg-config search path.
```

This indicates that the `libvirt-dev` package is not installed. This package provides:

- Header files (`/usr/include/libvirt/libvirt.h`)
- pkg-config configuration files (`/usr/lib/pkgconfig/libvirt.pc`)
- Development libraries needed to compile `libvirt-python`

### Quick Fix

```bash
sudo apt-get update
sudo apt-get install -y libvirt-dev pkg-config
```

### Verification

After installation, verify that libvirt is properly configured:

```bash
# Check if pkg-config can find libvirt
pkg-config --exists libvirt && echo "libvirt found" || echo "libvirt not found"

# Get compilation flags
pkg-config --cflags libvirt

# Get library flags
pkg-config --libs libvirt

# Check if headers are available
ls -la /usr/include/libvirt/libvirt.h
```

## Python Environment Setup

Once system dependencies are installed, set up the Python environment:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip and build tools
pip install --upgrade pip setuptools wheel

# Install project dependencies
pip install -e .
```

## Testing the Setup

Use the updated prerequisite checker to verify everything is working:

```bash
# Run all checks
./scripts/system-checks/check_prereqs.sh all

# Run only Python dependencies check
./scripts/system-checks/check_prereqs.sh python-deps

# Test the Python dependencies check function
./scripts/system-checks/test_python_deps.sh
```

## Troubleshooting

### Common Issues

1. **libvirt-dev not found**
   - Ensure you're using a supported Ubuntu/Debian version
   - Check if the package exists: `apt-cache search libvirt-dev`

2. **Permission denied on /dev/kvm**
   - Add user to kvm group: `sudo usermod -aG kvm $(whoami)`
   - Log out and back in for changes to take effect

3. **Python packages fail to build**
   - Ensure `build-essential` is installed
   - Check Python version compatibility (requires Python 3.10+)

4. **Virtual environment creation fails**
   - Install `python3-venv`: `sudo apt-get install python3-venv`

### Debugging Commands

```bash
# Check system packages
dpkg -l | grep -E "(libvirt|python3)"

# Check pkg-config
pkg-config --list-all | grep libvirt
```

## Dependencies Overview

### System Dependencies

- **libvirt-dev**: Development headers and libraries for libvirt
- **pkg-config**: Tool for managing compile and link flags
- **build-essential**: C/C++ compiler and build tools
- **python3-dev**: Python development headers

### Python Dependencies

- **libvirt-python**: Python bindings for libvirt (requires libvirt-dev)
- **typer**: CLI framework
- **rich**: Terminal formatting
- **jsonschema**: JSON schema validation
- **PyYAML**: YAML parsing
- **jinja2**: Template engine

## Next Steps

After resolving the libvirt issue:

1. Run the full prerequisite check: `./scripts/system-checks/check_prereqs.sh all`
2. Set up the Python virtual environment
3. Install the project dependencies
4. Test the AI-HOW CLI: `ai-how --help`

## References

- [libvirt Python Bindings Documentation](https://libvirt.org/python.html)
- **TODO**: **Ubuntu libvirt Package** - Find correct packages.ubuntu.com URL (currently returns 504 error)
- [Python Virtual Environments](https://docs.python.org/3/library/venv.html)
