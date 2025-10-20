# Cloud Base Packages Role

**Status:** Complete
**Last Updated:** 2025-10-20

## Overview

This Ansible role installs essential packages and utilities for cloud-based infrastructure
deployments. It provides foundational software for both Kubernetes and cloud computing
environments.

## Purpose

The cloud base packages role provides:

- **Cloud Tools**: Cloud CLI and SDK utilities
- **Kubernetes Support**: kubectl, kubelet, and related tools
- **Container Tools**: Container image tools and utilities
- **Networking**: Network utilities and diagnostic tools
- **System Utilities**: Essential system administration tools
- **Development Tools**: Development headers and build utilities

## Variables

### Package Selection

- `install_cloud_tools`: Install cloud CLIs (AWS, Azure, GCP, default: true)
- `install_kubernetes_tools`: Install Kubernetes tools (default: true)
- `install_container_tools`: Install container utilities (default: true)
- `install_network_tools`: Install network utilities (default: true)
- `install_development_tools`: Install dev tools (default: false)

### Cloud Provider Selection

- `cloud_providers`: List of cloud providers ("aws", "azure", "gcp", default: [])
- `aws_cli_version`: AWS CLI version (default: latest)
- `azure_cli_version`: Azure CLI version (default: latest)
- `gcp_sdk_version`: GCP SDK version (default: latest)

### Kubernetes Configuration

- `kubernetes_version`: Kubernetes version (default: latest)
- `kubectl_version`: kubectl version (default: latest)
- `helm_version`: Helm version (default: latest)
- `helm_install`: Install Helm (default: true)

### Container Tools

- `podman_enabled`: Install Podman (default: true)
- `skopeo_enabled`: Install Skopeo (default: true)
- `crictl_enabled`: Install crictl (default: true)

## Usage

### Basic Cloud Setup

```yaml
- hosts: cloud_nodes
  become: true
  roles:
    - cloud-base-packages
```

### AWS Cloud Deployment

```yaml
- hosts: cloud_nodes
  become: true
  roles:
    - cloud-base-packages
  vars:
    cloud_providers:
      - "aws"
    install_kubernetes_tools: true
```

### Kubernetes Cluster Nodes

```yaml
- hosts: k8s_nodes
  become: true
  roles:
    - cloud-base-packages
  vars:
    install_kubernetes_tools: true
    install_container_tools: true
    kubernetes_version: "1.28"
    helm_install: true
```

### Multi-Cloud Environment

```yaml
- hosts: cloud_nodes
  become: true
  roles:
    - cloud-base-packages
  vars:
    cloud_providers:
      - "aws"
      - "azure"
      - "gcp"
    install_kubernetes_tools: true
```

### Development Environment

```yaml
- hosts: cloud_dev
  become: true
  roles:
    - cloud-base-packages
  vars:
    install_development_tools: true
    install_kubernetes_tools: true
    cloud_providers:
      - "aws"
```

## Dependencies

This role requires:

- Debian-based system (Debian 11+)
- Root privileges
- Internet connectivity for downloads
- ~500MB disk space for typical installation

## What This Role Does

1. **Installs Cloud CLIs**: AWS CLI, Azure CLI, GCP SDK
2. **Installs Kubernetes Tools**: kubectl, kubelet, kubeadm, Helm
3. **Installs Container Tools**: Podman, Skopeo, crictl
4. **Installs Network Tools**: curl, wget, netcat, jq, etc.
5. **Installs System Tools**: curl, wget, git, tmux, vim
6. **Configures Path**: Adds tools to system PATH
7. **Verifies Installation**: Tests installed tools

## Tags

Available Ansible tags:

- `cloud_packages`: All cloud packages
- `cloud_tools`: Cloud provider CLIs
- `kubernetes_tools`: Kubernetes tooling
- `container_tools`: Container utilities
- `network_tools`: Network utilities
- `development_tools`: Development tools

## Example Playbook

```yaml
---
- name: Deploy Cloud Base Packages
  hosts: cloud_nodes
  become: yes
  roles:
    - cloud-base-packages
  vars:
    cloud_providers:
      - "aws"
      - "azure"
    install_kubernetes_tools: true
    install_container_tools: true
    kubernetes_version: "1.28"
```

## Verification

After deployment, verify cloud packages:

```bash
# Cloud tools
aws --version
az --version
gcloud --version

# Kubernetes tools
kubectl version --client
helm version
kubeadm version

# Container tools
podman version
skopeo --version
crictl --version

# System tools
curl --version
jq --version
```

## Common Operations

### AWS Configuration

```bash
# Configure AWS credentials
aws configure

# List S3 buckets
aws s3 ls

# Deploy CloudFormation stack
aws cloudformation create-stack --stack-name mystack --template-body file://template.yaml
```

### Kubernetes Operations

```bash
# Get cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Deploy helm chart
helm repo add myrepo https://example.com/charts
helm install myapp myrepo/myapp

# Check pod status
kubectl get pods -A
```

### Container Operations

```bash
# Build container with Podman
podman build -t myapp:1.0 .

# Push to registry
podman push myapp:1.0 registry.example.com/myapp:1.0

# Inspect image layers
skopeo inspect docker://ubuntu:latest
```

## Troubleshooting

### CLI Tool Not Found

1. Verify installation: `which <tool>`
2. Check PATH: `echo $PATH`
3. Reinstall tool: `apt install <package>`
4. Verify package exists: `apt search <package>`

### AWS CLI Issues

1. Check credentials: `cat ~/.aws/credentials`
2. Verify permissions: `aws iam get-user`
3. Check region: `aws configure get region`
4. Test connectivity: `aws s3 ls`

### Kubernetes Connection Issues

1. Verify kubeconfig: `kubectl config view`
2. Test API connectivity: `kubectl cluster-info`
3. Check credentials: `kubectl auth can-i get pods`
4. View events: `kubectl get events -A`

### Container Registry Auth

1. Login to registry: `podman login registry.example.com`
2. Check credentials: `cat ~/.config/containers/auth.json`
3. Verify network: `curl -I https://registry.example.com`

## Cloud Provider Setup

### AWS

```bash
# Install AWS CLI
sudo apt install awscli

# Configure credentials
aws configure

# Verify setup
aws sts get-caller-identity
```

### Azure

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Verify setup
az account show
```

### GCP

```bash
# Install GCP SDK
curl https://sdk.cloud.google.com | bash

# Initialize GCP
gcloud init

# Verify setup
gcloud auth list
```

## Common Tasks

### Update Kubernetes Version

```bash
# Install new version
sudo apt install kubectl=<version>

# Verify
kubectl version --client
```

### Install Additional Helm Plugins

```bash
# Add Helm plugin
helm plugin install <plugin-url>

# List plugins
helm plugin list
```

### Configure Container Registry

```bash
# Create auth file
podman login registry.example.com

# Verify registry access
podman pull registry.example.com/image:tag
```

## Integration with Other Roles

This role works with:

- **container-runtime**: Container runtime deployment
- **container-registry**: Container image distribution
- **monitoring-stack**: Infrastructure monitoring

## See Also

- **[../README.md](../README.md)** - Main Ansible overview
- **[../hpc-base-packages/README.md](../hpc-base-packages/README.md)** - HPC packages
- **[AWS CLI Documentation](https://docs.aws.amazon.com/cli/)** - AWS CLI docs
- **[Kubernetes Documentation](https://kubernetes.io/docs/)** - Kubernetes docs
- **[Helm Documentation](https://helm.sh/docs/)** - Helm docs
