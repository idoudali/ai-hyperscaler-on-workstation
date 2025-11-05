# Tutorial: Kubernetes Basics on AI-HOW Cloud Cluster

**Audience:** Researchers and developers using the AI-HOW cloud cluster
**Prerequisites:** Access to the cloud cluster
**Time:** 30-45 minutes
**Difficulty:** Beginner

## Table of Contents

1. [Introduction](#introduction)
2. [Accessing Kubernetes](#accessing-kubernetes)
3. [Cluster Status and Health](#cluster-status-and-health)
4. [Basic Kubernetes Concepts](#basic-kubernetes-concepts)
5. [Working with Pods](#working-with-pods)
6. [Working with Deployments](#working-with-deployments)
7. [Services and Networking](#services-and-networking)
8. [Storage with PersistentVolumes](#storage-with-persistentvolumes)
9. [Namespaces and Resource Isolation](#namespaces-and-resource-isolation)
10. [GPU Resources](#gpu-resources)
11. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
12. [Best Practices](#best-practices)
13. [Common Tasks](#common-tasks)

## Introduction

### What is Kubernetes?

Kubernetes (K8s) is a container orchestration platform that automates deployment, scaling, and management of
containerized applications. On the AI-HOW cloud cluster, Kubernetes provides:

**Before you begin:** Make sure you have kubectl configured locally. See the
[Managing Multiple Kubernetes Configs](../../kubeconfig-management.md) guide for
setup instructions.

- **Container orchestration** - Automatic scheduling and management
- **GPU sharing** - MIG GPU resources for ML workloads
- **Service discovery** - Automatic networking and load balancing
- **Self-healing** - Automatic restart of failed containers
- **Rolling updates** - Zero-downtime deployments
- **Resource management** - CPU, memory, and GPU allocation

### Kubernetes vs Traditional VMs

| Aspect | Traditional VMs | Kubernetes |
|--------|----------------|------------|
| **Resource Unit** | Virtual Machine | Container (Pod) |
| **Startup Time** | Minutes | Seconds |
| **Resource Overhead** | High (full OS) | Low (shared kernel) |
| **Density** | 10-20 VMs per host | 100+ Pods per node |
| **Isolation** | Strong (hypervisor) | Process-level |
| **GPU Sharing** | 1 GPU = 1 VM | MIG allows multiple Pods per GPU |

### When to Use Kubernetes

**Use Kubernetes for:**

- ✅ Microservices and distributed applications
- ✅ ML training jobs with GPU requirements
- ✅ Web services and APIs
- ✅ Batch processing and ETL pipelines
- ✅ Applications needing high availability

**Use SLURM for:**

- ✅ Traditional HPC workloads
- ✅ MPI parallel jobs
- ✅ Long-running simulations
- ✅ Full GPU allocation per job

## Accessing Kubernetes

There are two ways to access your Kubernetes cluster:

1. **Local Access** (recommended) - Use kubectl from your local machine
2. **Cluster-Side Access** - SSH to a cluster node and use kubectl there

### Local Access (Recommended)

This is the preferred method for day-to-day Kubernetes management. You run `kubectl` commands from your local machine.

#### Prerequisites

1. **kubectl installed locally** - See [kubeconfig management guide](../../kubeconfig-management.md) for installation instructions
2. **Cluster deployed** - The cluster must be deployed via Ansible playbooks
3. **Kubeconfig available** - After deployment, kubeconfig files are saved in `output/cluster-state/kubeconfigs/`

#### Step 1: Set Up Local kubectl (One-Time Setup)

If you haven't installed kubectl yet:

**Linux:**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**macOS:**

```bash
brew install kubectl
# Or download binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Windows:**

```powershell
choco install kubernetes-cli
```

#### Step 2: Configure kubectl to Use Your Cluster

From the project root directory:

```bash
# List available clusters
./scripts/manage-kubeconfig.sh list

# Switch to your cluster (e.g., cloud-cluster)
./scripts/manage-kubeconfig.sh use cloud-cluster

# Or manually set KUBECONFIG
export KUBECONFIG=$(pwd)/output/cluster-state/kubeconfigs/cloud-cluster.kubeconfig
```

**See [Managing Multiple Kubernetes Configs](../../kubeconfig-management.md) for detailed kubeconfig management.**

#### Step 3: Verify Local Access

```bash
# Test cluster connectivity
kubectl cluster-info

# Output:
# Kubernetes control plane is running at https://<control-plane-ip>:6443
# CoreDNS is running at https://...

# List nodes
kubectl get nodes

# Output:
# NAME                STATUS   ROLES           AGE   VERSION
# cloud-control-01    Ready    control-plane   30d   v1.28.x
# cloud-worker-01     Ready    worker          30d   v1.28.x
```

#### Step 4: Check Your Access Level

```bash
# View your user context
kubectl config view

# Check what you can do
kubectl auth can-i --list
```

**You're now ready to manage the cluster from your local machine!**

### Cluster-Side Access (Alternative)

Sometimes you may need to access the cluster directly from a node (e.g., for
troubleshooting, node maintenance, or when local access isn't available).

#### When to Use Cluster-Side Access

- ✅ Troubleshooting cluster nodes
- ✅ Checking node-level logs
- ✅ Network debugging
- ✅ Local access not available

**Note:** For day-to-day operations, prefer local access for better security and convenience.

#### Step 1: Connect to Control Plane Node

```bash
# SSH to the cloud cluster control plane
ssh user@cloud-control-01

# Verify you're on the control plane
hostname
# Output: cloud-control-01
```

#### Step 2: Verify kubectl is Available

```bash
# Check kubectl version
kubectl version --client

# Output:
# Client Version: v1.28.x
# Kustomize Version: v5.x.x
```

On cluster nodes, kubectl is typically installed automatically during deployment.

#### Step 3: Test Cluster Access

```bash
# Test cluster connectivity
kubectl cluster-info

# Output:
# Kubernetes control plane is running at https://127.0.0.1:6443
# (Note: On nodes, API server is at localhost)
```

#### Step 4: Check Your Access Level

```bash
# View your user context
kubectl config view

# Check what you can do
kubectl auth can-i --list
```

### Configuration File Locations

**Local Access:**

- Default: `~/.kube/config` (when using `manage-kubeconfig.sh set-default`)
- Custom: `output/cluster-state/kubeconfigs/{cluster-name}.kubeconfig`
- Set via: `export KUBECONFIG=/path/to/kubeconfig`

**Cluster-Side Access:**

- Default: `~/.kube/config` (on the node)
- System config: `/etc/kubernetes/admin.conf` (on control plane nodes)

### Choosing Access Method

| Scenario | Recommended Method |
|----------|-------------------|
| Day-to-day management | Local access |
| Deployment and updates | Local access |
| Troubleshooting nodes | Cluster-side access |
| Checking node health | Cluster-side access |
| Network debugging | Cluster-side access |
| CI/CD pipelines | Local access (with kubeconfig) |

## Cluster Status and Health

### View Cluster Nodes

```bash
# List all nodes
kubectl get nodes

# Output:
# NAME                STATUS   ROLES           AGE   VERSION
# cloud-control-01    Ready    control-plane   30d   v1.28.x
# cloud-worker-01     Ready    worker          30d   v1.28.x
# cloud-worker-02     Ready    worker          30d   v1.28.x
# cloud-gpu-01        Ready    worker          30d   v1.28.x
# cloud-gpu-02        Ready    worker          30d   v1.28.x
```

### View Node Details

```bash
# Detailed node information
kubectl describe node cloud-gpu-01

# Key information to look for:
# - Status: Ready/NotReady
# - CPU/Memory capacity and allocatable
# - GPU resources (nvidia.com/gpu.shared)
# - Taints and tolerations
# - Running pods
```

### Check Node Resources

```bash
# View resource usage across all nodes
kubectl top nodes

# Output:
# NAME               CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# cloud-control-01   248m         6%     4Gi             25%
# cloud-worker-01    1500m        37%    8Gi             50%
# cloud-gpu-01       3000m        75%    60Gi            75%

# Note: Requires metrics-server to be installed
```

### Check Cluster Components

```bash
# View all system pods
kubectl get pods -n kube-system

# Key components to check:
# - kube-apiserver
# - kube-controller-manager
# - kube-scheduler
# - kube-proxy
# - coredns
# - calico (or other CNI)

# Check component health
kubectl get componentstatuses
```

### View Cluster Events

```bash
# Recent cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events --all-namespaces --watch

# Filter by namespace
kubectl get events -n mlops --sort-by='.lastTimestamp'
```

### Check API Server Health

```bash
# API server health endpoint
kubectl get --raw /healthz

# Detailed health check
kubectl get --raw /readyz?verbose

# Liveness check
kubectl get --raw /livez?verbose
```

## Basic Kubernetes Concepts

### Kubernetes Object Hierarchy

```text
Cluster
├── Namespaces (logical separation)
│   ├── Pods (smallest deployable unit)
│   │   └── Containers (Docker containers)
│   ├── Deployments (manage Pods)
│   ├── Services (networking)
│   ├── ConfigMaps (configuration)
│   ├── Secrets (sensitive data)
│   └── PersistentVolumeClaims (storage)
└── Nodes (physical/virtual machines)
    └── Resources (CPU, Memory, GPU)
```

### Core Objects

#### 1. **Pod**

The smallest deployable unit. Usually contains one container (sometimes multiple tightly coupled containers).

#### 2. **Deployment**

Manages a set of identical Pods. Handles scaling, updates, and rollbacks.

#### 3. **Service**

Exposes Pods on the network. Provides stable IP and DNS name.

#### 4. **PersistentVolumeClaim (PVC)**

Requests storage resources. Mounts volumes into Pods.

#### 5. **ConfigMap**

Stores non-sensitive configuration data.

#### 6. **Secret**

Stores sensitive data (passwords, keys, tokens).

### Namespaces

Namespaces provide logical separation within a cluster:

```bash
# List all namespaces
kubectl get namespaces

# Common namespaces:
# - default: Default namespace for user workloads
# - kube-system: System components
# - kube-public: Public resources
# - mlops: MLOps stack (MinIO, PostgreSQL, MLflow)
# - argocd: GitOps deployment system
```

## Working with Pods

### What is a Pod?

A Pod is the smallest deployable unit in Kubernetes. It represents a running process and can contain one or more
containers that share:

- Network namespace (same IP address)
- Storage volumes
- Configuration

### Create a Simple Pod

```bash
# Create a simple nginx pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
EOF

# Output: pod/my-first-pod created
```

### View Pods

```bash
# List pods in default namespace
kubectl get pods

# List all pods in all namespaces
kubectl get pods --all-namespaces

# Wide output (more details)
kubectl get pods -o wide

# Output:
# NAME           READY   STATUS    RESTARTS   AGE   IP            NODE
# my-first-pod   1/1     Running   0          30s   10.244.1.10   cloud-worker-01
```

### Get Pod Details

```bash
# Detailed pod information
kubectl describe pod my-first-pod

# Key information:
# - Status: Running/Pending/Failed/CrashLoopBackOff
# - Events: Recent pod events
# - Containers: Container status
# - Volumes: Mounted volumes
# - Node: Which node it's running on
```

### View Pod Logs

```bash
# View logs from pod
kubectl logs my-first-pod

# Follow logs in real-time
kubectl logs -f my-first-pod

# Previous container logs (if restarted)
kubectl logs my-first-pod --previous

# Logs from specific container (multi-container pod)
kubectl logs my-first-pod -c nginx
```

### Execute Commands in Pod

```bash
# Get a shell in the pod
kubectl exec -it my-first-pod -- /bin/bash

# Run a single command
kubectl exec my-first-pod -- ls -la /usr/share/nginx/html

# Run command in specific container
kubectl exec -it my-first-pod -c nginx -- /bin/bash
```

### Delete a Pod

```bash
# Delete pod
kubectl delete pod my-first-pod

# Force delete (if stuck)
kubectl delete pod my-first-pod --force --grace-period=0
```

### Pod with Resource Limits

```bash
# Create pod with resource requests and limits
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx:latest
    resources:
      requests:
        cpu: "250m"       # 0.25 CPU cores
        memory: "512Mi"   # 512 megabytes
      limits:
        cpu: "1000m"      # 1 CPU core
        memory: "2Gi"     # 2 gigabytes
EOF
```

**Resource Units:**

- **CPU:** 1000m (millicores) = 1 CPU core
- **Memory:** Ki, Mi, Gi (binary) or K, M, G (decimal)

## Working with Deployments

### What is a Deployment?

A Deployment manages a set of identical Pods. It provides:

- **Declarative updates** - Describe desired state
- **Scaling** - Easily increase/decrease replicas
- **Rolling updates** - Zero-downtime deployments
- **Rollback** - Revert to previous versions
- **Self-healing** - Automatic Pod replacement

### Create a Deployment

```bash
# Create nginx deployment with 3 replicas
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
EOF

# Output: deployment.apps/nginx-deployment created
```

### View Deployments

```bash
# List deployments
kubectl get deployments

# Output:
# NAME               READY   UP-TO-DATE   AVAILABLE   AGE
# nginx-deployment   3/3     3            3           1m

# Detailed information
kubectl describe deployment nginx-deployment

# View deployment in YAML format
kubectl get deployment nginx-deployment -o yaml
```

### Scale a Deployment

```bash
# Scale to 5 replicas
kubectl scale deployment nginx-deployment --replicas=5

# Verify scaling
kubectl get deployment nginx-deployment

# Auto-scale based on CPU (requires metrics-server)
kubectl autoscale deployment nginx-deployment --min=3 --max=10 --cpu-percent=80
```

### Update a Deployment

```bash
# Update image version
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# Edit deployment directly
kubectl edit deployment nginx-deployment

# Apply updated YAML file
kubectl apply -f nginx-deployment.yaml

# View rollout status
kubectl rollout status deployment/nginx-deployment
```

### View Rollout History

```bash
# View rollout history
kubectl rollout history deployment/nginx-deployment

# View specific revision
kubectl rollout history deployment/nginx-deployment --revision=2
```

### Rollback a Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Verify rollback
kubectl rollout status deployment/nginx-deployment
```

### Delete a Deployment

```bash
# Delete deployment (also deletes all pods)
kubectl delete deployment nginx-deployment

# Verify deletion
kubectl get deployment nginx-deployment
# Output: No resources found
```

## Services and Networking

### What is a Service?

A Service provides stable networking for Pods:

- **Stable IP address** - Doesn't change when Pods restart
- **DNS name** - `<service-name>.<namespace>.svc.cluster.local`
- **Load balancing** - Distributes traffic across Pods
- **Service discovery** - Automatic DNS registration

### Service Types

| Type | Description | Use Case |
|------|-------------|----------|
| **ClusterIP** | Internal cluster IP (default) | Internal services |
| **NodePort** | Exposes on each node's IP | External access (dev) |
| **LoadBalancer** | Cloud load balancer | Production external access |
| **ExternalName** | DNS CNAME record | External services |

### Create a ClusterIP Service

```bash
# Create service for nginx deployment
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

# Output: service/nginx-service created
```

### View Services

```bash
# List services
kubectl get services

# Output:
# NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-service   ClusterIP   10.96.100.50    <none>        80/TCP    1m

# Detailed information
kubectl describe service nginx-service

# View endpoints (Pod IPs)
kubectl get endpoints nginx-service
```

### Test Service Connectivity

```bash
# Create test pod
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- sh

# Inside the pod:
curl http://nginx-service
curl http://nginx-service.default.svc.cluster.local

# Exit test pod (it will be deleted automatically due to --rm)
exit
```

### Create NodePort Service

```bash
# Expose deployment with NodePort
kubectl expose deployment nginx-deployment --type=NodePort --port=80

# Get assigned NodePort
kubectl get service nginx-deployment

# Output:
# NAME               TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
# nginx-deployment   NodePort   10.96.50.100   <none>        80:30123/TCP   1m

# Access from outside cluster:
# http://<node-ip>:30123
```

### Port Forwarding (Development)

```bash
# Forward local port to service
kubectl port-forward service/nginx-service 8080:80

# Now access via:
# http://localhost:8080

# Forward to specific pod
kubectl port-forward pod/nginx-deployment-abc123 8080:80
```

## Storage with PersistentVolumes

### Storage Concepts

```text
StorageClass (defines storage type)
    ↓
PersistentVolume (actual storage)
    ↓
PersistentVolumeClaim (request for storage)
    ↓
Pod (mounts PVC)
```

### View Storage Classes

```bash
# List available storage classes
kubectl get storageclasses

# Output (cloud cluster):
# NAME         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path   rancher.io/local-path   Delete          WaitForFirstConsumer
```

### Create PersistentVolumeClaim

```bash
# Request 10Gi of storage
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
EOF

# Output: persistentvolumeclaim/my-data-pvc created
```

### View PVCs

```bash
# List PVCs
kubectl get pvc

# Output:
# NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES
# my-data-pvc   Bound    pvc-abc123-def456-ghi789                  10Gi       RWO

# Detailed information
kubectl describe pvc my-data-pvc
```

### Use PVC in Pod

```bash
# Create pod with mounted volume
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:
  - name: app
    image: nginx:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data-pvc
EOF
```

### Test Storage

```bash
# Write data to volume
kubectl exec pod-with-storage -- sh -c "echo 'Hello from PVC!' > /data/test.txt"

# Delete and recreate pod
kubectl delete pod pod-with-storage
kubectl apply -f pod-with-storage.yaml

# Verify data persists
kubectl exec pod-with-storage -- cat /data/test.txt
# Output: Hello from PVC!
```

## Namespaces and Resource Isolation

### View Namespaces

```bash
# List all namespaces
kubectl get namespaces

# Output:
# NAME              STATUS   AGE
# default           Active   30d
# kube-system       Active   30d
# kube-public       Active   30d
# mlops             Active   15d
# argocd            Active   10d
```

### Create Namespace

```bash
# Create namespace
kubectl create namespace my-project

# Or with YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: my-project
  labels:
    env: dev
    team: ml-team
EOF
```

### Work with Namespaces

```bash
# List resources in specific namespace
kubectl get pods -n my-project

# Set default namespace for current context
kubectl config set-context --current --namespace=my-project

# Verify current namespace
kubectl config view --minify | grep namespace:

# Create resources in namespace
kubectl run nginx --image=nginx -n my-project
```

### Resource Quotas

```bash
# Limit resources per namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-project-quota
  namespace: my-project
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    requests.nvidia.com/gpu: "2"
    persistentvolumeclaims: "10"
    pods: "50"
EOF

# View quota
kubectl describe resourcequota my-project-quota -n my-project
```

### Limit Ranges

```bash
# Set default and maximum resources
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: my-project-limits
  namespace: my-project
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
    max:
      cpu: "2000m"
      memory: "4Gi"
    type: Container
EOF
```

## GPU Resources

### View GPU Nodes

```bash
# List nodes with GPU labels
kubectl get nodes -l node-role.kubernetes.io/gpu=true

# View GPU capacity
kubectl describe node cloud-gpu-01 | grep -A5 "Capacity:"

# Output:
# Capacity:
#   nvidia.com/gpu:         7
#   nvidia.com/gpu.shared:  70
```

### Understanding MIG GPUs

The cloud cluster uses NVIDIA MIG (Multi-Instance GPU) for GPU sharing:

- **Physical GPUs:** 2x A100 80GB per GPU node
- **MIG Slices:** Each A100 divided into 7 slices (1g.10gb)
- **Resource:** `nvidia.com/gpu.shared: 10` = 1 MIG slice

### Request GPU in Pod

```bash
# Pod with single MIG GPU slice
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-pod
spec:
  containers:
  - name: cuda-app
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      requests:
        nvidia.com/gpu.shared: "10"  # 1 MIG slice
      limits:
        nvidia.com/gpu.shared: "10"
  nodeSelector:
    node-role.kubernetes.io/gpu: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Equal
    value: "true"
    effect: NoSchedule
EOF
```

### View GPU Logs

```bash
# View nvidia-smi output
kubectl logs gpu-test-pod

# Expected output:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 525.x.xx       Driver Version: 525.x.xx       CUDA Version: 12.0|
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# ...
```

### ML Training Job with GPU

```bash
# PyTorch training job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorch-training
spec:
  template:
    spec:
      containers:
      - name: trainer
        image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
        command:
          - python
          - -c
          - |
            import torch
            print(f"PyTorch version: {torch.__version__}")
            print(f"CUDA available: {torch.cuda.is_available()}")
            print(f"CUDA device count: {torch.cuda.device_count()}")
            if torch.cuda.is_available():
                print(f"CUDA device name: {torch.cuda.get_device_name(0)}")
        resources:
          requests:
            nvidia.com/gpu.shared: "10"
          limits:
            nvidia.com/gpu.shared: "10"
      restartPolicy: Never
      nodeSelector:
        node-role.kubernetes.io/gpu: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Equal
        value: "true"
        effect: NoSchedule
  backoffLimit: 3
EOF

# Check job status
kubectl get job pytorch-training

# View logs
kubectl logs job/pytorch-training
```

## Monitoring and Troubleshooting

### Check Pod Status

```bash
# List all pods with their status
kubectl get pods --all-namespaces

# Common status values:
# - Running: Pod is running
# - Pending: Waiting for resources/scheduling
# - CrashLoopBackOff: Container keeps crashing
# - ImagePullBackOff: Cannot pull container image
# - Error: Container exited with error
# - Completed: Job finished successfully
```

### Debug Pending Pods

```bash
# Describe pod to see why it's pending
kubectl describe pod <pod-name>

# Common reasons:
# - Insufficient resources (CPU/Memory/GPU)
# - No nodes match node selector
# - PVC not bound
# - Image pull errors

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>
```

### Debug CrashLoopBackOff

```bash
# View logs from crashed container
kubectl logs <pod-name> --previous

# Get container exit code
kubectl describe pod <pod-name> | grep "Exit Code"

# Check resource limits
kubectl describe pod <pod-name> | grep -A10 "Limits:"

# Common causes:
# - Application error/exception
# - Out of memory (OOMKilled)
# - Missing configuration
# - Failed liveness/readiness probe
```

### View Resource Usage

```bash
# Pod resource usage
kubectl top pod <pod-name>

# All pods in namespace
kubectl top pods -n mlops

# Node resource usage
kubectl top nodes

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory
```

### Network Troubleshooting

```bash
# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Test service connectivity
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- curl http://nginx-service

# View service endpoints
kubectl get endpoints <service-name>

# Check network policies
kubectl get networkpolicies -A
```

### Storage Troubleshooting

```bash
# Check PVC status
kubectl get pvc

# Describe PVC for binding issues
kubectl describe pvc <pvc-name>

# View PV details
kubectl get pv

# Check storage class
kubectl describe storageclass local-path
```

## Best Practices

### 1. Always Set Resource Requests and Limits

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

**Why:** Ensures fair scheduling and prevents resource starvation.

### 2. Use Labels for Organization

```yaml
metadata:
  labels:
    app: myapp
    version: v1.0
    environment: prod
    team: ml-team
```

**Why:** Makes filtering and selection easier.

### 3. Use Namespaces for Isolation

```bash
# Create project-specific namespace
kubectl create namespace ml-project-1

# Deploy resources in namespace
kubectl apply -f deployment.yaml -n ml-project-1
```

**Why:** Provides logical separation and resource quotas.

### 4. Use Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

**Why:** Enables automatic recovery and prevents traffic to unhealthy pods.

### 5. Use ConfigMaps and Secrets

```bash
# Store configuration in ConfigMap
kubectl create configmap app-config --from-file=config.yaml

# Store secrets securely
kubectl create secret generic app-secrets --from-literal=password=SecurePass123
```

**Why:** Separates configuration from code.

### 6. Tag Images with Versions

```yaml
image: myapp:v1.2.3  # ✅ Good
image: myapp:latest  # ❌ Bad
```

**Why:** Ensures reproducible deployments.

### 7. Use Deployments, Not Bare Pods

```bash
# ❌ Bad
kubectl run myapp --image=myapp:v1

# ✅ Good
kubectl create deployment myapp --image=myapp:v1
```

**Why:** Deployments provide self-healing, scaling, and updates.

### 8. Clean Up Resources

```bash
# Delete old jobs
kubectl delete job <job-name>

# Delete completed pods
kubectl delete pod --field-selector=status.phase==Succeeded

# Delete all resources with label
kubectl delete all -l app=myapp
```

**Why:** Prevents cluster clutter and resource waste.

## Common Tasks

### Task 1: Deploy a Simple Web Application

```bash
# 1. Create deployment
kubectl create deployment webapp --image=nginx:latest --replicas=3

# 2. Expose as service
kubectl expose deployment webapp --type=ClusterIP --port=80

# 3. Test
kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl http://webapp

# 4. Scale
kubectl scale deployment webapp --replicas=5

# 5. Update image
kubectl set image deployment/webapp nginx=nginx:1.26

# 6. View rollout status
kubectl rollout status deployment/webapp

# 7. Clean up
kubectl delete deployment webapp
kubectl delete service webapp
```

### Task 2: Run a Batch Job

```bash
# Create a job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  template:
    spec:
      containers:
      - name: processor
        image: python:3.11
        command:
          - python
          - -c
          - |
            import time
            print("Processing data...")
            time.sleep(10)
            print("Done!")
      restartPolicy: Never
  backoffLimit: 3
EOF

# Watch job
kubectl get job data-processing --watch

# View logs
kubectl logs job/data-processing

# Delete job
kubectl delete job data-processing
```

### Task 3: Create a CronJob

```bash
# Run job every hour
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-backup
spec:
  schedule: "0 * * * *"  # Every hour
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: alpine:latest
            command:
              - /bin/sh
              - -c
              - echo "Running backup at \$(date)"
          restartPolicy: Never
EOF

# View cronjobs
kubectl get cronjobs

# View jobs created by cronjob
kubectl get jobs

# Delete cronjob
kubectl delete cronjob hourly-backup
```

### Task 4: Debug a Failing Pod

```bash
# 1. Check pod status
kubectl get pods

# 2. Describe pod
kubectl describe pod <pod-name>

# 3. Check logs
kubectl logs <pod-name>

# 4. Check previous logs (if crashed)
kubectl logs <pod-name> --previous

# 5. Get a shell (if possible)
kubectl exec -it <pod-name> -- /bin/bash

# 6. Check events
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>

# 7. Delete and recreate
kubectl delete pod <pod-name>
```

### Task 5: Copy Files To/From Pod

```bash
# Copy file to pod
kubectl cp /local/file.txt <pod-name>:/path/in/pod/

# Copy file from pod
kubectl cp <pod-name>:/path/in/pod/file.txt /local/destination/

# Copy from specific container
kubectl cp <pod-name>:/path/file.txt /local/ -c <container-name>
```

## Next Steps

### Learn More

1. **Managing Multiple Clusters:** [Managing Multiple Kubernetes Configs](../../kubeconfig-management.md)
How to manage kubeconfigs locally
2. **Kubernetes Official Docs:** https://kubernetes.io/docs/
3. **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
4. **MLOps on Kubernetes:** Coming soon

### Practice Exercises

1. Deploy a multi-tier application (frontend + backend + database)
2. Set up horizontal pod autoscaling
3. Create a deployment with rolling updates and rollback
4. Run a distributed ML training job with multiple GPUs
5. Set up ingress for external access

### Advanced Topics

- **Helm:** Package manager for Kubernetes
- **Kustomize:** Configuration management
- **ArgoCD:** GitOps continuous delivery
- **Istio:** Service mesh
- **Prometheus/Grafana:** Monitoring
- **Cert-Manager:** TLS certificates

## Quick Reference

### Essential Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Pods
kubectl get pods
kubectl describe pod <name>
kubectl logs <name>
kubectl exec -it <name> -- /bin/bash

# Deployments
kubectl get deployments
kubectl scale deployment <name> --replicas=5
kubectl rollout status deployment/<name>

# Services
kubectl get services
kubectl expose deployment <name> --port=80

# Storage
kubectl get pvc
kubectl get pv

# Namespaces
kubectl get namespaces
kubectl config set-context --current --namespace=<name>

# Help
kubectl --help
kubectl <command> --help
kubectl explain <resource>
```

### Resource Types Abbreviations

```bash
kubectl get po    # pods
kubectl get deploy # deployments
kubectl get svc   # services
kubectl get pvc   # persistentvolumeclaims
kubectl get pv    # persistentvolumes
kubectl get cm    # configmaps
kubectl get ns    # namespaces
kubectl get no    # nodes
```

## Conclusion

You've learned the basics of working with Kubernetes on the AI-HOW cloud cluster:

✅ How to access the cluster and verify connectivity
✅ Understanding cluster status and health monitoring
✅ Working with Pods, Deployments, and Services
✅ Managing storage with PersistentVolumes
✅ Using namespaces for resource isolation
✅ Requesting and using GPU resources
✅ Troubleshooting common issues
✅ Following best practices

**For questions or issues, contact the cluster administrator.**

---

**Last Updated:** 2025-10-31
**Version:** 1.0
**Maintainer:** AI-HOW Platform Team
