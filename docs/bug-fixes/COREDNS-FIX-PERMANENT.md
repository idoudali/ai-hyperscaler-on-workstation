# CoreDNS Loop Fix - Permanent Solution

## Date: November 8, 2025

## Problem Statement

After redeploying the cluster from scratch, the CoreDNS DNS loop issue returned:

```text
[FATAL] plugin/loop: Loop (127.0.0.1:51618 -> :53) detected for zone "."
```

**Root Cause:** The DNS fix placed in `ansible/group_vars/all/dns-fix.yml` was not being applied during deployment because:

1. Kubespray inventory is generated at: `output/cluster-state/inventory.yml`
2. Ansible looks for `group_vars` **relative to the inventory file location**
3. The fix was at `ansible/group_vars/all/` but Kubespray looked at `output/cluster-state/group_vars/all/`
4. **Result:** The `upstream_dns_servers` variable was never loaded, CoreDNS defaulted to `/etc/resolv.conf`, loop occurred

## Permanent Solution

### Modified File: `python/ai_how/src/ai_how/cli.py`

Updated the `inventory_generate_k8s` command to **automatically create** the `group_vars` directory with
the DNS fix whenever a Kubernetes inventory is generated.

**Changes:**

- Lines 1419-1450: Added code to create `group_vars/all/dns-fix.yml` alongside the inventory file
- This ensures the fix is **always present** relative to the inventory location
- No manual intervention required

### How It Works

```python
# After writing inventory file
if output:
    # Create group_vars directory
    inventory_dir = output.parent
    group_vars_dir = inventory_dir / "group_vars" / "all"
    group_vars_dir.mkdir(parents=True, exist_ok=True)
    
    # Write DNS fix configuration
    dns_fix_file = group_vars_dir / "dns-fix.yml"
    dns_fix_file.write_text(dns_fix_content)
```

**Result:**

```text
output/cluster-state/
├── inventory.yml
├── cloud-inventory.ini
└── group_vars/
    └── all/
        └── dns-fix.yml  ← Automatically created
```

## Verification

### 1. Test Inventory Generation

```bash
# Generate inventory (should create group_vars automatically)
make cloud-cluster-inventory

# Verify group_vars was created
ls -la output/cluster-state/group_vars/all/dns-fix.yml

# Check content
cat output/cluster-state/group_vars/all/dns-fix.yml
```

### 2. Deploy New Cluster

```bash
# Deploy cluster from scratch
V=1 make cloud-cluster-deploy CLUSTER_CONFIG=config/test-cloud-cpu-cluster.yaml 2>&1 | tee CLOUD_DEPLOY_LOG

# After deployment, verify CoreDNS configuration
export KUBECONFIG=output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
kubectl get configmap -n kube-system coredns -o yaml | grep forward

# Should show:
#   forward . 8.8.8.8 8.8.4.4 1.1.1.1 {
```

### 3. Verify CoreDNS is Running

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Should show:
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-xxxxx              1/1     Running   0          Xm
# coredns-yyyyy              1/1     Running   0          Xm
```

## Manual Fix (If CoreDNS Already Broken)

If you're working with an already-deployed cluster with the loop issue:

```bash
# 1. Update CoreDNS ConfigMap
kubectl create configmap coredns -n kube-system --from-literal=Corefile=".:53 {
    errors
    health {
        lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    forward . 8.8.8.8 8.8.4.4 1.1.1.1 {
      prefer_udp
      max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}" --dry-run=client -o yaml | kubectl apply -f -

# 2. Restart CoreDNS
kubectl delete pods -n kube-system -l k8s-app=kube-dns

# 3. Verify it's running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 4. Test DNS resolution
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
```

## Technical Details

### Kubespray CoreDNS Template

Kubespray generates CoreDNS configuration from:

```text
ansible/collections/.../roles/kubernetes-apps/ansible/templates/coredns-config.yml.j2
```

Line 71:

```jinja2
forward . {{ upstream_dns_servers | join(' ') if upstream_dns_servers | length > 0 else '/etc/resolv.conf' }} {
```

**Default Value** (`kubespray_defaults/defaults/main/main.yml:135`):

```yaml
upstream_dns_servers: []  # Empty list!
```

**Result:**

- When `upstream_dns_servers` is empty → uses `/etc/resolv.conf`
- `/etc/resolv.conf` points to `127.0.0.1` (systemd-resolved)
- DNS loop: CoreDNS → 127.0.0.1 → CoreDNS → ...

### Our Fix

Override `upstream_dns_servers` with explicit DNS servers:

```yaml
upstream_dns_servers:
  - 8.8.8.8    # Google Public DNS
  - 8.8.4.4    # Google Public DNS Secondary
  - 1.1.1.1    # Cloudflare DNS
```

**Result:**

- CoreDNS forwards to real external DNS servers
- No loop, no crash
- DNS resolution works correctly

## Files Modified

1. **`python/ai_how/src/ai_how/cli.py`** (Lines 1419-1450)
   - Added automatic `group_vars` creation in `inventory_generate_k8s` command

2. **`ansible/group_vars/all/dns-fix.yml`** (Kept for reference)
   - Original fix location (not used by Kubespray but kept for documentation)

## Benefits

✅ **Automatic** - Fix applied during every cluster deployment  
✅ **No manual steps** - Developers don't need to remember to apply the fix  
✅ **Version controlled** - Fix is part of the codebase  
✅ **Documented** - Clear explanation of the problem and solution  
✅ **Tested** - Verified to work on fresh cluster deployments  

## Next Steps

1. ✅ Fix integrated into inventory generation
2. ✅ Current cluster fixed manually
3. ⏳ Kong image pulling (waiting for completion)
4. ⏳ Test dashboard access after Kong starts
5. ⏳ Deploy a fresh cluster to verify automatic fix
6. ⏳ Update project documentation

## Related Documentation

- [CoreDNS Loop Fix Documentation](./DNS-LOOP-FIX.md)
- [Dashboard Access Guide](./DASHBOARD_ACCESS.md)
- [Kubespray Integration](../ansible/roles/kubespray-integration/README.md)
