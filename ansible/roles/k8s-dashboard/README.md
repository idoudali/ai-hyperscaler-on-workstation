# Kubernetes Dashboard Role

This role installs the Kubernetes Dashboard using Helm, following the official Kubernetes documentation at https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

## Role Structure

```text
k8s-dashboard/
├── defaults/
│   └── main.yml              # Default variables
├── tasks/
│   ├── main.yml              # Entry point - includes all task files
│   ├── install-dashboard.yml # Helm installation tasks
│   ├── validation.yml        # Post-installation validation
│   └── display-access-info.yml # Access instructions
└── README.md
```

## Overview

The Kubernetes Dashboard is a web-based UI for Kubernetes clusters. This role:

- Adds the official Kubernetes Dashboard Helm repository
- Installs Dashboard using Helm
- Validates the deployment
- Provides access instructions

## Variables

### Default Variables (in `defaults/main.yml`):

| Variable | Default | Description |
|----------|---------|-------------|
| `dashboard_namespace` | `kubernetes-dashboard` | Namespace for Dashboard deployment |
| `dashboard_release_name` | `kubernetes-dashboard` | Helm release name |
| `dashboard_chart_repo` | `https://kubernetes.github.io/dashboard/` | Helm chart repository URL |
| `dashboard_chart_name` | `kubernetes-dashboard/kubernetes-dashboard` | Helm chart name (repo/chart) |
| `dashboard_chart_version` | `""` | Chart version (empty for latest) |
| `dashboard_create_namespace` | `true` | Create namespace if it doesn't exist |

## Usage

### In a Playbook:

```yaml
---
- name: Deploy Kubernetes Dashboard
  hosts: localhost
  gather_facts: false
  vars:
    cluster_name: "{{ kubeconfig_cluster_name | default('cloud-cluster') }}"
    kubeconfig_path: "{{ playbook_dir }}/../../output/cluster-state/kubeconfigs/{{ cluster_name }}.kubeconfig"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  tags:
    - dashboard
    - k8s-dashboard
  roles:
    - role: k8s-dashboard
```

### With Custom Variables:

```yaml
---
- name: Deploy Kubernetes Dashboard
  hosts: localhost
  gather_facts: false
  environment:
    KUBECONFIG: "/path/to/kubeconfig"
  roles:
    - role: k8s-dashboard
      vars:
        dashboard_namespace: my-dashboard
        dashboard_release_name: my-dashboard
```

## Prerequisites

1. **Kubernetes cluster** must be deployed and healthy
2. **Kubeconfig** must be available and configured
3. **kubernetes.core collection** must be installed (in `ansible/collections/requirements.yml`)
4. **Helm** must be available (can be installed via `cloud-base-packages` role)

## Installation Process

The role performs the following steps:

1. **Add Helm Repository**: Adds the official Kubernetes Dashboard Helm repository
2. **Update Repository Cache**: Updates Helm repository cache
3. **Install Dashboard**: Installs Dashboard using Helm with namespace creation
4. **Validate Deployment**: Verifies namespace, pods, and services
5. **Display Access Info**: Shows port-forward command and access instructions

## Accessing the Dashboard

After deployment, access the Dashboard using port-forward:

```bash
# Start port-forward
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

# Open in browser
https://localhost:8443
```

### Authentication

Dashboard supports Bearer Token authentication. To create a token for testing, see the official documentation:

https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

**Note:** Sample users in the tutorial have administrative privileges and are for educational purposes only.

## Tags

Available Ansible tags:

- `dashboard` - All Dashboard tasks
- `dashboard-install` - Installation tasks only
- `dashboard-validate` - Validation tasks only
- `dashboard-info` - Access information display only
- `k8s-dashboard` - Alias for `dashboard`

## Example Playbook Usage

```bash
# Deploy Dashboard (via playbook-cloud-runtime.yml)
ansible-playbook -i inventory.ini playbooks/playbook-cloud-runtime.yml --tags dashboard

# Deploy only Dashboard (standalone)
ansible-playbook -i inventory.ini playbooks/deploy-dashboard.yml

# Skip validation
ansible-playbook -i inventory.ini playbooks/playbook-cloud-runtime.yml --tags dashboard --skip-tags dashboard-validate
```

## Verification

After deployment, verify Dashboard:

```bash
# Check namespace
kubectl get namespace kubernetes-dashboard

# Check pods
kubectl get pods -n kubernetes-dashboard

# Check services
kubectl get svc -n kubernetes-dashboard

# Check Helm release
helm list -n kubernetes-dashboard
```

## Troubleshooting

### Dashboard pods not starting

```bash
# Check pod status
kubectl get pods -n kubernetes-dashboard

# Check pod logs
kubectl logs -n kubernetes-dashboard <pod-name>

# Check events
kubectl get events -n kubernetes-dashboard --sort-by='.lastTimestamp'
```

### Port-forward fails

```bash
# Verify service exists
kubectl get svc -n kubernetes-dashboard

# Check service details
kubectl describe svc kubernetes-dashboard-kong-proxy -n kubernetes-dashboard

# Try different port
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8444:443
```

### Helm repository issues

```bash
# List Helm repositories
helm repo list

# Update repository
helm repo update kubernetes-dashboard

# Remove and re-add repository
helm repo remove kubernetes-dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
```

## Dependencies

This role requires:

- `kubernetes.core` collection (>=2.4.0)
- Helm 3.x
- kubectl configured with cluster access
- Python `kubernetes` library (for `kubernetes.core` modules)

## Integration

This role is integrated into `playbook-cloud-runtime.yml` and runs automatically after Kubernetes cluster deployment and kubeconfig retrieval.

## References

- [Kubernetes Dashboard Official Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Kubernetes Dashboard GitHub](https://github.com/kubernetes/dashboard)
- [Kubernetes Dashboard Helm Chart](https://github.com/kubernetes/dashboard/tree/master/charts/kubernetes-dashboard)
- [Ansible kubernetes.core.helm Module](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/helm_module.html)


