# Container Runtime Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role configures container runtime environments for running containerized workloads
on HPC cluster nodes. It sets up Docker and/or Apptainer (Singularity) depending on deployment
needs.

## Purpose

The container runtime role provides:

- **Docker Installation**: Container engine and orchestration
- **Apptainer Setup**: HPC-focused container runtime (Singularity successor)
- **Registry Access**: Container registry configuration and authentication
- **Resource Limits**: Memory and CPU constraint enforcement
- **Networking**: Container network configuration
- **Storage**: Container storage and volume management
- **Security**: SELinux and AppArmor configuration

## Variables

### Runtime Selection

- `container_runtime_type`: Runtime to install ("docker", "apptainer", or "both", default: "docker")
- `container_install_method`: Installation method ("package", "external", "skip", default: "package")

### Docker Configuration

- `docker_enabled`: Enable Docker (default: true)
- `docker_version`: Docker version (default: latest)
- `docker_storage_driver`: Storage driver (default: overlay2)
- `docker_data_root`: Docker data directory (default: /var/lib/docker)
- `docker_log_driver`: Logging driver (default: json-file)
- `docker_log_max_size`: Max log size (default: 10m)
- `docker_userns_remap`: User namespace remapping (default: false)

### Apptainer Configuration

- `apptainer_enabled`: Enable Apptainer (default: false)
- `apptainer_version`: Apptainer version (default: latest)
- `apptainer_cache_dir`: Cache directory (default: /var/cache/apptainer)
- `apptainer_mount_home`: Mount home directory (default: true)
- `apptainer_allow_suid`: SUID workflows (default: false)

### Registry Configuration

- `container_registries`: List of registries to configure
- `container_registry_insecure`: Allow insecure registries (default: false)
- `container_registry_auth`: Registry authentication credentials

### Resource Limits

- `container_max_memory`: Memory limit (default: unlimited)
- `container_max_cpus`: CPU limit (default: unlimited)
- `container_pids_limit`: PID limit (default: unlimited)

## Usage

### Docker Only

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - container-runtime
  vars:
    container_runtime_type: "docker"
```

### Apptainer Only

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - container-runtime
  vars:
    container_runtime_type: "apptainer"
    apptainer_enabled: true
```

### Both Docker and Apptainer

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - container-runtime
  vars:
    container_runtime_type: "both"
    docker_enabled: true
    apptainer_enabled: true
```

### With Private Registry

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - container-runtime
  vars:
    container_runtime_type: "docker"
    container_registries:
      - "registry.hpc.local:5000"
    container_registry_insecure: true
    container_registry_auth:
      registry.hpc.local:5000:
        username: "deployuser"
        password: "{{ vault_registry_password }}"
```

### With Resource Limits

```yaml
- hosts: hpc_compute
  become: true
  roles:
    - container-runtime
  vars:
    container_runtime_type: "docker"
    container_max_memory: "8GB"
    container_max_cpus: "4"
    docker_log_max_size: "50m"
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- Internet connectivity for downloads
- Optional: SELinux or AppArmor for security

## What This Role Does

1. **Installs Runtime**: Installs Docker, Apptainer, or both
2. **Configures Storage**: Sets up storage drivers and directories
3. **Configures Logging**: Sets up logging configuration
4. **Sets Up Registries**: Configures container registries
5. **Configures Networking**: Sets up network drivers
6. **Enables Security**: Configures SELinux/AppArmor policies
7. **Starts Services**: Enables and starts daemon services
8. **Tests Runtime**: Verifies runtime is functional

## Tags

Available Ansible tags:

- `container_runtime`: All runtime tasks
- `docker`: Docker installation and configuration
- `apptainer`: Apptainer installation and configuration
- `registry`: Registry configuration
- `security`: Security hardening

## Example Playbook

```yaml
---
- name: Deploy Container Runtime
  hosts: hpc_compute
  become: yes
  roles:
    - container-runtime
  vars:
    container_runtime_type: "both"
    docker_enabled: true
    apptainer_enabled: true
    container_registries:
      - "docker.io"
      - "registry.hpc.local"
    docker_storage_driver: "overlay2"
    apptainer_mount_home: true
```

## Service Management

### Docker

```bash
# Check Docker status
systemctl status docker

# Restart Docker
systemctl restart docker

# View Docker logs
journalctl -u docker -f

# Enable auto-start
systemctl enable docker
```

### Apptainer

```bash
# Check Apptainer installation
apptainer --version

# Test Apptainer
apptainer run library://alpine cat /etc/os-release

# View cache
du -sh ~/.cache/apptainer
```

## Verification

After deployment, verify container runtime:

```bash
# Docker verification
docker run hello-world
docker ps
docker info

# Apptainer verification
apptainer pull docker://alpine
apptainer exec alpine cat /etc/os-release

# Check registry access
docker login <registry>
docker pull <registry>/image:tag
```

## Common Operations

### Docker Commands

```bash
# Run container
docker run -it ubuntu bash

# List images
docker images

# List containers
docker ps -a

# Remove image
docker rmi <image>

# Build image
docker build -t myapp:1.0 .
```

### Apptainer Commands

```bash
# Pull image
apptainer pull docker://ubuntu

# Run container
apptainer exec ubuntu bash

# Build SIF from definition
apptainer build myapp.sif Apptainer.def

# Run with GPU
apptainer run --nv myapp.sif
```

## Troubleshooting

### Docker Won't Start

1. Check daemon status: `systemctl status docker`
2. Verify socket: `ls -la /var/run/docker.sock`
3. Check logs: `journalctl -u docker -xe`
4. Verify disk space: `df -h /var/lib/docker`

### Registry Authentication Fails

1. Verify credentials: `docker login <registry>`
2. Check credentials file: `cat ~/.docker/config.json`
3. Verify network: `curl -I https://<registry>`
4. Check registry certificate

### Permission Issues

1. Add user to docker group: `usermod -aG docker <user>`
2. Restart docker: `systemctl restart docker`
3. Log out and back in
4. Test: `docker ps`

### High Memory Usage

1. Check running containers: `docker ps`
2. Inspect container: `docker inspect <container> | grep -i memory`
3. Set memory limits: `docker run -m 1g <image>`
4. Clean up: `docker system prune`

## Security Considerations

### User Namespace Remapping

```yaml
docker_userns_remap: true
docker_userns_remap_user: "dockremap"
```

### Registry Security

```yaml
container_registry_insecure: false  # Require HTTPS
container_registry_ca_cert: "/path/to/ca.crt"
```

### SELinux Policy

```bash
# Check SELinux status
getenforce

# Set SELinux policy for Docker
semanage login -a -s sysadm_r -r s0-mcs.systemHigh dockeradmin
```

## Performance Tuning

### For HPC Workloads

```yaml
docker_storage_driver: "overlay2"
docker_max_concurrent_downloads: 5
docker_max_concurrent_uploads: 5
```

### For I/O Intensive

```yaml
docker_storage_driver: "devicemapper"
docker_storage_opts:
  - "dm.basesize=100GB"
```

## Integration with Other Roles

This role works with:

- **container-registry**: Container image distribution
- **monitoring-stack**: Container metrics monitoring
- **ml-container-images**: ML container provisioning

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../container-registry/README.md](../container-registry/README.md)** - Registry setup
- **[Docker Official Docs](https://docs.docker.com/)** - Docker documentation
- **[Apptainer Docs](https://apptainer.org/docs/)** - Apptainer documentation
