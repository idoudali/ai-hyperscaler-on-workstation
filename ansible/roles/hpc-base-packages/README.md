# HPC Base Packages Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role installs essential HPC software packages and development tools required for
high-performance computing environments. It provides the foundational packages needed for MPI
applications, scientific computing, and cluster management.

## Purpose

The HPC base packages role provides:

- **Development Tools**: Compilers, build utilities, and debuggers
- **MPI Libraries**: OpenMPI and/or MPICH for parallel computing
- **Scientific Libraries**: BLAS, LAPACK, and related numerical libraries
- **Performance Tools**: Profilers and performance monitoring utilities
- **System Utilities**: SSH, tmux, htop for system management
- **Documentation**: Development headers and documentation

## Variables

### Package Selection

- `install_compilers`: Install GCC, Clang compilers (default: true)
- `install_mpi`: Install OpenMPI libraries (default: true)
- `install_scientific_libs`: Install BLAS, LAPACK (default: true)
- `install_development_tools`: Install build tools (default: true)
- `install_performance_tools`: Install profilers (default: true)

### Compiler Options

- `compiler_version`: GCC version (e.g., "9", "10", "11", default: system default)
- `enable_fortran`: Install Fortran compiler (default: true)
- `enable_openmp`: Enable OpenMP support (default: true)

### MPI Configuration

- `mpi_implementation`: MPI library ("openmpi" or "mpich", default: "openmpi")
- `mpi_version`: MPI version to install (default: latest available)

### Scientific Libraries

- `install_blas`: Install BLAS libraries (default: true)
- `install_lapack`: Install LAPACK libraries (default: true)
- `install_hdf5`: Install HDF5 library (default: false)
- `install_netcdf`: Install NetCDF library (default: false)

## Usage

### Basic Installation

```yaml
- hosts: hpc_nodes
  become: true
  roles:
    - hpc-base-packages
```

This installs default HPC packages including compilers, MPI, and scientific libraries.

### Minimal Installation

```yaml
- hosts: hpc_nodes
  become: true
  roles:
    - hpc-base-packages
  vars:
    install_mpi: false
    install_scientific_libs: false
```

### Full Scientific Stack

```yaml
- hosts: hpc_nodes
  become: true
  roles:
    - hpc-base-packages
  vars:
    install_compilers: true
    install_mpi: true
    install_scientific_libs: true
    install_performance_tools: true
    install_hdf5: true
    install_netcdf: true
```

### Specific Compiler Version

```yaml
- hosts: hpc_nodes
  become: true
  roles:
    - hpc-base-packages
  vars:
    compiler_version: "11"
    enable_fortran: true
```

### With MPICH Instead of OpenMPI

```yaml
- hosts: hpc_nodes
  become: true
  roles:
    - hpc-base-packages
  vars:
    mpi_implementation: "mpich"
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- Internet connectivity for package downloads
- ~2GB disk space for typical installation

## What This Role Does

1. **Updates Package Manager**: Refreshes package lists
2. **Installs Compilers**: GCC, Clang, Fortran compiler
3. **Installs Development Tools**: Make, CMake, autotools, git
4. **Installs MPI Library**: OpenMPI or MPICH with development headers
5. **Installs Scientific Libraries**: BLAS, LAPACK, linear algebra packages
6. **Installs Performance Tools**: Perf, profiling utilities
7. **Installs System Tools**: tmux, htop, vim, openssh-client
8. **Sets Up Environment**: Configures module system if available
9. **Creates Symbolic Links**: For compatibility with common patterns

## Installed Packages

### Compilers and Build Tools

- `build-essential` - Basic build tools (gcc, g++, make)
- `gfortran` - Fortran compiler
- `cmake` - CMake build system
- `autoconf`, `automake` - Build automation tools
- `git` - Version control
- `curl`, `wget` - Download utilities
- `pkg-config` - Library configuration tool

### MPI Libraries

**OpenMPI (default):**

- `libopenmpi-dev` - Development headers
- `openmpi-bin` - OpenMPI binaries and tools

**MPICH (if selected):**

- `libmpich-dev` - Development headers
- `mpich` - MPICH binaries

### Scientific Libraries

- `libblas-dev` - Basic Linear Algebra Subprograms
- `liblapack-dev` - Linear Algebra Package
- `libopenblas-dev` - Optimized BLAS library
- `libgsl-dev` - GNU Scientific Library (optional)

### Performance Tools

- `linux-tools-generic` - Kernel performance tools (perf)
- `valgrind` - Memory debugging and profiling
- `gdb` - GNU debugger
- `strace` - System call tracing

### System Utilities

- `openssh-client` - SSH client for remote access
- `tmux` - Terminal multiplexer for long-running tasks
- `htop` - Interactive process monitor
- `vim`, `nano` - Text editors
- `curl`, `wget` - Data transfer utilities

## Tags

Available Ansible tags:

- `hpc_packages`: All package installation
- `compilers`: Compiler installation only
- `mpi`: MPI library installation
- `scientific_libs`: Scientific libraries
- `performance_tools`: Performance tools
- `system_tools`: System utilities

### Using Tags

```bash
# Install only compilers
ansible-playbook playbook.yml --tags compilers

# Install everything except performance tools
ansible-playbook playbook.yml --skip-tags performance_tools
```

## Example Playbook

```yaml
---
- name: Install HPC Base Packages
  hosts: hpc_nodes
  become: yes
  roles:
    - hpc-base-packages
  vars:
    compiler_version: "11"
    install_mpi: true
    mpi_implementation: "openmpi"
    install_scientific_libs: true
    install_hdf5: true
    install_netcdf: true
```

## Verification

After installation, verify the HPC packages:

```bash
# Check compiler
gcc --version
gfortran --version

# Check MPI
mpicc --version
mpif90 --version

# Check scientific libraries
pkg-config --cflags --libs blas
pkg-config --cflags --libs lapack

# Test MPI installation
mpirun --version

# View installed HPC packages
dpkg -l | grep -E "gcc|gfortran|mpi|blas|lapack"
```

## Common Tasks After Installation

### Compile a Simple MPI Program

```bash
# Create test program
cat > hello_mpi.c << 'EOF'
#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    printf("Hello from rank %d of %d\n", rank, size);
    MPI_Finalize();
    return 0;
}
EOF

# Compile with MPI
mpicc -o hello_mpi hello_mpi.c

# Run on 4 processes
mpirun -np 4 ./hello_mpi
```

### Check Scientific Library Versions

```bash
# BLAS/LAPACK version
apt-cache policy libblas-dev liblapack-dev

# OpenMPI version
ompi_info | head -20
```

### Load Environment Variables

Most installations don't require environment variables but you may add them:

```bash
# For OpenMPI
export PATH=$PATH:/usr/lib64/openmpi/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/openmpi/lib
```

## Troubleshooting

### Compilation Errors

1. Verify compilers installed: `gcc --version`
2. Check for missing headers: `ls /usr/include/mpi.h`
3. Examine build logs for specific errors
4. Install additional development headers if needed

### MPI Communication Issues

1. Verify MPI installation: `mpirun --version`
2. Test on localhost first: `mpirun -H localhost -np 2 program`
3. Check firewall rules for MPI ports
4. Ensure consistent MPI on all nodes

### Library Linking Problems

1. Verify library installation: `ldconfig -p | grep blas`
2. Use `pkg-config` to find correct flags: `pkg-config --cflags --libs blas`
3. Check library paths: `echo $LD_LIBRARY_PATH`
4. Manually specify library paths if needed: `gcc -L/usr/lib -lblas ...`

### Performance Issues

1. Verify optimized libraries installed (OpenBLAS vs reference BLAS)
2. Check CPU affinity settings
3. Monitor memory usage during compilation
4. Consider using ccache for faster rebuilds

## Performance Optimization

### Enable CPU Optimizations

```bash
# Compile with optimization flags
CFLAGS="-O3 -march=native" ./configure
make
```

### Use Optimized BLAS

The role installs OpenBLAS by default which is optimized. For additional optimization:

```bash
# Check current BLAS version
update-alternatives --list libblas.so
```

### Parallel Build

Most builds support parallel jobs:

```bash
# Compile using 8 cores
make -j8
```

## Integration with Other Roles

This role is typically deployed before:

- **slurm-controller/slurm-compute**: SLURM scheduler setup
- **nvidia-gpu-drivers**: GPU support for CUDA
- **monitoring-stack**: Performance monitoring

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../nvidia-gpu-drivers/README.md](../nvidia-gpu-drivers/README.md)** - GPU driver installation
- **[../../docs/architecture/](../../docs/architecture/)** - HPC architecture
- **[GCC Documentation](https://gcc.gnu.org/)** - Compiler documentation
- **[Open MPI Documentation](https://www.open-mpi.org/)** - MPI documentation
