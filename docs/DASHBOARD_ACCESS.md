# Kubernetes Dashboard Access Guide

## Overview

This guide explains how to access the Kubernetes Dashboard deployed on your cluster, following the
[official Kubernetes documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/).

## Architecture

The Kubernetes Dashboard (v7.0.0+) uses **Kong** as a gateway proxy to route requests to backend services:

- **Kong Proxy** (`kubernetes-dashboard-kong-proxy`) - API gateway that routes all traffic
- **Dashboard API** (`kubernetes-dashboard-api`) - Backend API service
- **Dashboard Web** (`kubernetes-dashboard-web`) - Frontend web service
- **Metrics Scraper** (`kubernetes-dashboard-metrics-scraper`) - Metrics collection

**Access Method:** Port-forward to Kong proxy service only. Kong handles internal routing to all backend services.

## Quick Start

### 1. Set KUBECONFIG

```bash
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
```

### 2. Port-Forward to Kong Proxy

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

### 3. Open Dashboard in Browser

```text
https://localhost:8443
```

**Note:** You will see a certificate warning. Click "Advanced" and proceed. This is expected
because the dashboard uses a self-signed certificate.

### 4. Get Authentication Token

In a new terminal:

```bash
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
kubectl -n kubernetes-dashboard create token admin-user
```

Copy the entire token output and paste it into the dashboard login page.

**Token Validity:** 1 hour. Generate a new token when it expires using the same command.

## Troubleshooting

### Cannot Connect to Cluster

**Symptom:** `Error: Cannot connect to cluster` or `connection refused`

**Solution:**

```bash
# Verify kubeconfig path and cluster connectivity
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
kubectl get nodes
```

If `kubectl get nodes` fails, check that your cluster is running and kubeconfig is correctly configured.

### Port Already in Use

**Symptom:** `error: listen tcp :8443: bind: address already in use`

**Solution:**

```bash
# Find and kill the process using the port
lsof -i :8443
kill -9 <PID>

# Or use a different local port
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8444:443
# Then access https://localhost:8444
```

### Certificate Warning in Browser

**Symptom:** Browser shows "Your connection is not private" or "Certificate invalid"

**Solution:** This is expected behavior. The dashboard uses a self-signed certificate.

- Click "Advanced" → "Proceed to localhost (unsafe)"
- Or add an exception for localhost:8443

This is safe for local development. For production, configure proper TLS certificates.

### Kong Proxy Service Not Found

**Symptom:** `Error from server (NotFound): services "kubernetes-dashboard-kong-proxy" not found`

**Solution:**

```bash
# Check if dashboard is deployed
kubectl get pods -n kubernetes-dashboard

# Check all services in namespace
kubectl get svc -n kubernetes-dashboard

# Verify Helm release
helm list -n kubernetes-dashboard
```

If services are missing, redeploy the dashboard using the Ansible playbook.

### Token Creation Fails

**Symptom:** `Error from server (NotFound): serviceaccounts "admin-user" not found`

**Solution:**

The `admin-user` service account is created automatically by the deployment. If it's missing:

```bash
# Create service account manually
kubectl -n kubernetes-dashboard create serviceaccount admin-user

# Create cluster role binding
kubectl create clusterrolebinding admin-user \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user

# Generate token
kubectl -n kubernetes-dashboard create token admin-user
```

### Dashboard Pods Not Running

**Symptom:** Pods show `CrashLoopBackOff`, `ImagePullBackOff`, or `Pending`

**Solution:**

```bash
# Check pod status
kubectl get pods -n kubernetes-dashboard

# Describe problematic pod
kubectl describe pod -n kubernetes-dashboard <pod-name>

# Check logs
kubectl logs -n kubernetes-dashboard <pod-name>
```

Common issues:

- **ImagePullBackOff**: Check internet connectivity or image pull secrets
- **CrashLoopBackOff**: Check pod logs for application errors
- **Pending**: Check node resources (CPU/memory) or scheduling constraints

### DNS Issues in Cluster

**Symptom:** Kong or dashboard services cannot resolve internal DNS names

**Solution:**

```bash
# Verify CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution from a test pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

If DNS is broken, you may need to redeploy the cluster to fix CoreDNS configuration.

## Dashboard Features

Once logged in, you can:

- **Cluster Overview** - View nodes, namespaces, and cluster resources
- **Workload Management** - Manage deployments, pods, replica sets, and jobs
- **Service Discovery** - View and manage services and ingresses
- **Storage** - Manage persistent volumes and persistent volume claims
- **Configuration** - Create and edit ConfigMaps and Secrets
- **Logs** - View real-time logs for any pod
- **Resource Metrics** - Monitor CPU and memory usage
- **RBAC** - Manage roles and role bindings

## Security Considerations

- ⚠️ The `admin-user` service account has **cluster-admin** privileges (full cluster access)
- ⚠️ Only share tokens with trusted users
- ⚠️ Tokens expire after 1 hour - generate new ones as needed
- ⚠️ **For production:** Use more restrictive RBAC roles with specific namespace access
- ⚠️ **For production:** Configure proper TLS certificates instead of self-signed

For production security best practices, see:

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [Kubernetes Dashboard Access Control](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md)

## Additional Resources

- [Kubernetes Dashboard Official Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Kubernetes Dashboard GitHub Repository](https://github.com/kubernetes/dashboard)
- [Dashboard User Guide](https://github.com/kubernetes/dashboard/blob/master/docs/user/README.md)
- [kubectl port-forward Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
