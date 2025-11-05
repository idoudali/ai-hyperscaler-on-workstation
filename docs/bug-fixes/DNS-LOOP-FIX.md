# CoreDNS Loop Detection Fix

## Problem

During cluster deployment, CoreDNS crashes with the following error:

```text
[FATAL] plugin/loop: Loop (127.0.0.1:51618 -> :53) detected for zone "."
```

This happens because CoreDNS forwards DNS queries to `/etc/resolv.conf`, which points back to `127.0.0.1`
(systemd-resolved), creating an infinite loop.

## Root Cause

1. **Kubespray Default**: The `upstream_dns_servers` variable defaults to an empty list `[]`
2. **CoreDNS Template**: When `upstream_dns_servers` is empty, CoreDNS is configured to forward to `/etc/resolv.conf`
3. **systemd-resolved**: On modern Linux systems, `/etc/resolv.conf` points to `127.0.0.1` (systemd-resolved stub resolver)
4. **DNS Loop**: CoreDNS → /etc/resolv.conf → 127.0.0.1 → CoreDNS (infinite loop)

**Location in code:**

```text
ansible/collections/.../roles/kubernetes-apps/ansible/templates/coredns-config.yml.j2:71
forward . {{ upstream_dns_servers | join(' ') if upstream_dns_servers | length > 0 else '/etc/resolv.conf' }} {
```

## Solution

Configure explicit upstream DNS servers in Kubespray so CoreDNS forwards to real external DNS servers.

### Implementation

**File:** `ansible/group_vars/all/dns-fix.yml`

```yaml
---
# Upstream DNS servers for CoreDNS
# These are used by CoreDNS to resolve external DNS queries
upstream_dns_servers:
  - 8.8.8.8    # Google Public DNS
  - 8.8.4.4    # Google Public DNS Secondary
  - 1.1.1.1    # Cloudflare DNS
```

This configuration is automatically picked up by Kubespray during cluster deployment.

## Verification

After deploying the cluster, verify CoreDNS is running:

```bash
export KUBECONFIG=output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig

# Check CoreDNS pod status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Should show:
# NAME                      READY   STATUS    RESTARTS   AGE
# coredns-xxx-yyy          1/1     Running   0          5m
# coredns-xxx-zzz          1/1     Running   0          5m

# Verify CoreDNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# Look for:
# forward . 8.8.8.8 8.8.4.4 1.1.1.1 {
#   prefer_udp
#   max_concurrent 1000
# }
```

## Test DNS Resolution

```bash
# Test internal cluster DNS
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default

# Should show:
# Server:    169.254.25.10
# Address 1: 169.254.25.10
# Name:      kubernetes.default
# Address 1: 10.233.0.1 kubernetes.default.svc.cluster.local
```

## Impact on Existing Clusters

If you have an existing cluster with the DNS loop issue, you have two options:

### Option 1: Manual Fix (Quick)

Apply the fix immediately without redeploying:

```bash
export KUBECONFIG=output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig

# Apply the fixed ConfigMap
kubectl apply -f fix-coredns-loop.yaml

# Restart CoreDNS pods
kubectl delete pods -n kube-system -l k8s-app=kube-dns

# Wait for pods to restart
kubectl get pods -n kube-system -l k8s-app=kube-dns -w
```

### Option 2: Redeploy Cluster (Permanent)

Redeploy the cluster with the fix in place:

```bash
# The fix is now in ansible/group_vars/all/dns-fix.yml
# Simply redeploy:
V=1 make cloud-cluster-deploy CLUSTER_CONFIG=config/test-cloud-cpu-cluster.yaml 2>&1 | tee CLOUD_DEPLOY_LOG
```

The new cluster will have CoreDNS properly configured from the start.

## Related Components

### Kubernetes Dashboard

This fix is **critical** for the Kubernetes Dashboard to work correctly. Kong (the Dashboard's API gateway)
requires working DNS to resolve internal service names:

- `kubernetes-dashboard-api.kubernetes-dashboard.svc.cluster.local`
- `kubernetes-dashboard-web.kubernetes-dashboard.svc.cluster.local`

Without this fix, accessing the Dashboard results in:

```text
Error: name resolution failed
request_id: 79e9201daa62ae3fc1a27a4b1b842d77
```

## References

- **Kubespray CoreDNS Template:** `ansible/collections/.../kubernetes-apps/ansible/templates/coredns-config.yml.j2`
- **Kubespray Defaults:** `ansible/collections/.../kubespray_defaults/defaults/main/main.yml`
- **CoreDNS Loop Plugin:** https://coredns.io/plugins/loop/#troubleshooting
- **GitHub Issue:** https://github.com/kubernetes/kubernetes/issues/36222

## Prevention

This fix is now **permanently integrated** into the project:

✅ `ansible/group_vars/all/dns-fix.yml` - Configures upstream DNS servers  
✅ Automatically applied during cluster deployment  
✅ No manual intervention required for new clusters  
✅ Documented in this file for troubleshooting existing clusters

## Summary

- **Problem:** CoreDNS crashes due to DNS forwarding loop
- **Cause:** Empty `upstream_dns_servers` causes fallback to `/etc/resolv.conf`
- **Fix:** Configure explicit upstream DNS servers (8.8.8.8, 8.8.4.4, 1.1.1.1)
- **Status:** ✅ Fixed at Ansible level, automatically applied during deployment
- **Impact:** Critical for cluster DNS and Kubernetes Dashboard functionality
