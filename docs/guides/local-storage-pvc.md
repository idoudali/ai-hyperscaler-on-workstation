# Local Storage and PVC Guide

This guide explains how to use local storage with PersistentVolumeClaims (PVCs) in your k3s cluster.

## Overview

K3s uses the **local-path-provisioner** for dynamic PVC provisioning. This allows you to create
persistent volumes from local disk storage without manual configuration.

## Storage Architecture

```text
Host Disk (/opt/k3s-storage/)
    ↓
Local Path Provisioner (DaemonSet)
    ↓
StorageClass (local-storage)
    ↓
PersistentVolumeClaim (PVC)
    ↓
Pod Volume Mount
```

## Understanding StorageClass and PVC

### StorageClass

A StorageClass defines the provisioner and parameters for dynamic volume provisioning:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**Key Parameters:**

- `provisioner`: The storage provisioner to use (rancher.io/local-path)
- `volumeBindingMode`: When to bind volumes
  - `WaitForFirstConsumer`: Bind when pod is scheduled (recommended)
  - `Immediate`: Bind immediately
- `reclaimPolicy`: What happens when PVC is deleted
  - `Delete`: Remove volume (default)
  - `Retain`: Keep volume

### PersistentVolumeClaim

A PVC requests storage from a StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 10Gi
```

**Access Modes:**

- `ReadWriteOnce` (RWO): Single pod read/write
- `ReadOnlyMany` (ROX): Multiple pods read-only
- `ReadWriteMany` (RWX): Multiple pods read/write

**Note:** local-path-provisioner only supports `ReadWriteOnce`. For `ReadWriteMany`, you need a shared filesystem (NFS, CephFS).

## Creating PVCs

### Using Example Templates

Pre-configured PVC templates are available:

```bash
# Small PVC (10Gi)
kubectl apply -f k8s-manifests/storage/examples/pvc-small.yaml

# Medium PVC (50Gi)
kubectl apply -f k8s-manifests/storage/examples/pvc-medium.yaml

# Large PVC (100Gi)
kubectl apply -f k8s-manifests/storage/examples/pvc-large.yaml
```

### Creating Custom PVCs

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-custom-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage  # Or omit to use default
  resources:
    requests:
      storage: 25Gi
```

Apply with:

```bash
kubectl apply -f my-pvc.yaml
```

### Checking PVC Status

```bash
# List all PVCs
kubectl get pvc

# Describe specific PVC
kubectl describe pvc my-pvc

# Check if bound
kubectl get pvc my-pvc -o jsonpath='{.status.phase}'
# Should output: Bound
```

## Using PVCs in Pods

### Basic Usage

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-pvc
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
```

### Using in Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 1  # Only 1 replica for ReadWriteOnce
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:latest
        volumeMounts:
        - name: data
          mountPath: /app/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-pvc
```

### Using in StatefulSets

StatefulSets are ideal for stateful applications:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 20Gi
```

## HostPath vs PVC

### When to Use HostPath

Use HostPath for:

- Development/testing
- Direct access to host filesystem
- Shared datasets across pods
- Temporary data

```yaml
volumes:
- name: datasets
  hostPath:
    path: /data/datasets
    type: Directory
```

**Example:** See `k8s-manifests/storage/hostpath-examples.yaml`

### When to Use PVC

Use PVC for:

- Production workloads
- Data persistence across pod restarts
- Dynamic volume provisioning
- Storage abstraction

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc
```

## Storage Examples

### Example 1: Database Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
```

### Example 2: Slurm Database Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: slurm-db-pvc
  namespace: slurm
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 10Gi
```

Used in `k8s-manifests/hpc-slurm/storage.yaml`

### Example 3: Training Data Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: training-job
spec:
  containers:
  - name: trainer
    image: pytorch/pytorch:latest
    command: ["python", "train.py"]
    volumeMounts:
    - name: data
      mountPath: /workspace/data
    resources:
      limits:
        nvidia.com/gpu: 1
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: training-data
```

## Best Practices

### 1. Size Appropriately

- Start small and expand if needed
- Monitor actual usage: `kubectl exec -it <pod> -- df -h /data`

### 2. Use Namespaces

Organize PVCs by namespace:

```bash
kubectl create namespace mlops
kubectl apply -f pvc.yaml -n mlops
```

### 3. Backup Important Data

Local storage is not backed up automatically:

```bash
# Backup PVC data
kubectl exec -it <pod> -- tar czf /tmp/backup.tar.gz /data
kubectl cp <pod>:/tmp/backup.tar.gz ./backup.tar.gz
```

### 4. Clean Up Unused PVCs

```bash
# List all PVCs
kubectl get pvc -A

# Delete unused PVC
kubectl delete pvc my-pvc
```

### 5. Monitor Storage Usage

```bash
# Check PVC usage
kubectl get pvc

# Check actual disk usage in pod
kubectl exec -it <pod> -- df -h /data
```

## Troubleshooting

### PVC Stuck in Pending

1. **Check storage class:**

   ```bash
   kubectl get storageclass
   kubectl describe storageclass local-storage
   ```

2. **Check provisioner:**

   ```bash
   kubectl get pods -n local-path-storage
   kubectl logs -n local-path-storage -l app=local-path-provisioner
   ```

3. **Check node resources:**

   ```bash
   kubectl describe node
   ```

### Volume Not Mounting

1. **Check pod events:**

   ```bash
   kubectl describe pod <pod-name>
   ```

2. **Check PVC status:**

   ```bash
   kubectl describe pvc <pvc-name>
   ```

3. **Verify volume mount:**

   ```bash
   kubectl exec -it <pod> -- ls -la /data
   ```

### Storage Full

1. **Check disk space:**

   ```bash
   df -h /opt/k3s-storage
   ```

2. **Clean up unused PVCs:**

   ```bash
   kubectl get pvc -A
   kubectl delete pvc <unused-pvc>
   ```

3. **Expand PVC (if supported):**

   ```bash
   kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
   ```

## Reference

- [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [StorageClass API](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/storage-class-v1/)
