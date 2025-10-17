# Container Registry Role

**Status:** TODO  
**Last Updated:** 2025-01-27

## Overview

This Ansible role sets up a container registry for distributing container images across the HPC cluster.

## Purpose

The container registry role provides:

- Container registry server (Harbor/Docker Registry)
- Image storage and distribution
- Authentication and authorization
- Image scanning and security
- Web-based management interface

## Variables

### Required Variables

- `registry_host`: Hostname or IP address for the registry
- `registry_port`: Port number for the registry service
- `registry_data_path`: Path for registry data storage

### Optional Variables

- `registry_auth_enabled`: Enable authentication (default: true)
- `registry_ssl_enabled`: Enable SSL/TLS (default: true)
- `registry_storage_backend`: Storage backend type (default: filesystem)

## Usage

Include this role in your playbook:

```yaml
- hosts: registry_servers
  roles:
    - container-registry
  vars:
    registry_host: "registry.example.com"
    registry_port: 5000
    registry_data_path: "/var/lib/registry"
```

## Dependencies

- Docker or Podman runtime
- SSL certificates (if SSL enabled)
- Storage backend configuration

## Tags

- `registry`: Main registry installation
- `registry_config`: Registry configuration
- `registry_ssl`: SSL/TLS setup
- `registry_auth`: Authentication setup

## Example Playbook

```yaml
- name: Deploy Container Registry
  hosts: registry_servers
  become: yes
  roles:
    - container-registry
  vars:
    registry_host: "harbor.example.com"
    registry_port: 443
    registry_ssl_enabled: true
    registry_auth_enabled: true
```
