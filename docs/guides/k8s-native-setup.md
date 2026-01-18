# Kubernetes Native Setup Guide (No VMs)

This guide details how to set up a local Kubernetes environment on a workstation without using Virtual Machines, satisfying the requirement for a lightweight, container-based development environment.

## 1. Local Kubernetes Installation

We will use **Kind (Kubernetes in Docker)**. Kind runs Kubernetes nodes as Docker containers, avoiding the overhead of full VMs (like KVM/VirtualBox).

### Prerequisites
- Linux Workstation (or WSL2 on Windows)
- Docker Engine installed and running

### Step 1: Install Docker (if not present)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add your user to the docker group (avoids using sudo for docker commands)
sudo usermod -aG docker $USER
newgrp docker
```

### Step 2: Install kubectl

`kubectl` is the command-line tool for interacting with Kubernetes.

```bash
# Download the latest release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Verify checksum (optional but recommended)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

### Step 3: Install Kind

```bash
# Download binary
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind --version
```

### Step 4: Create the Cluster

We will create a cluster config to map ports if necessary (e.g., for accessing services).

Create a file named `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    listenAddress: "0.0.0.0" # Example port mapping
- role: worker
- role: worker
```

Create the cluster:

```bash
kind create cluster --config kind-config.yaml --name ai-hyperscaler
```

Verify the cluster:

```bash
kubectl cluster-info --context kind-ai-hyperscaler
kubectl get nodes
```

---

## 2. Options Analysis: Cloud Environment Simulation

To simulate a "Hyperscaler" environment (distinct from the underlying infrastructure) on this single cluster, we evaluated two options:

### Option A: Namespaces
- **Description**: Use simple K8s namespaces (`cloud-tenant-a`, `cloud-tenant-b`).
- **Pros**: Zero overhead, native K8s tooling.
- **Cons**: Weak isolation. CRDs (Custom Resource Definitions) are global. If a tenant installs a CRD, it affects the whole cluster.
- **Verdict**: Insufficient for simulating a true "Cloud" environment where tenants might need admin privileges or custom CRDs.

### Option B: vCluster (Virtual Clusters)
- **Description**: Runs a full Kubernetes control plane *inside* a Pod within the host cluster.
- **Pros**:
  - **Hard Isolation**: Tenants have their own API server.
  - **Admin Access**: Tenants can be "Cluster Admin" of their vCluster without compromising the host.
  - **No VMs**: Still runs as standard Pods.
- **Cons**: Slight resource overhead for the API server pod.
- **Verdict**: **Selected**. This best simulates the "Cloud" experience where we vend a K8s cluster to a user.

## 3. Storage Strategy

For this workstation setup, we will use **HostPath** or **Local Path Provisioner** (default in Kind).

- **Slurm State**: We need persistence for the Slurm Database and State (so jobs aren't lost on restart).
- **Implementation**: We will use Kubernetes `PersistentVolume` (PV) and `PersistentVolumeClaim` (PVC) mapping to a local directory on the Kind nodes (which are mounted from the host).

### Example Storage Class (Default in Kind)
Kind comes with `standard` storage class:
```bash
kubectl get sc
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  1h
```

We will use this default class for dynamic provisioning.

---

## 4. Slurm Deployment Options

There are two approaches to running Slurm on Kubernetes:

### Option A: Static Deployment (Manual)

Deploy Slurm components (Controller, Database, Compute Nodes) as standard Kubernetes Deployments/StatefulSets. This gives you full control but requires manual management.

**Use Case**: Simple clusters, learning, or when you need full control over configuration.

See the [Static Slurm Deployment](#static-slurm-deployment) section below.

### Option B: Slinky (SchedMD's Official Solution) - **Recommended**

[Slinky](https://www.schedmd.com/slinky/why-slinky/) is SchedMD's official toolkit for running Slurm inside Kubernetes. It provides:

- **Slurm Operator**: Automatically manages Slurm node scaling within Kubernetes
- **Dynamic Autoscaling**: Automatically adds/removes Slurm nodes based on workload
- **Resource Optimization**: Intelligent scheduling and resource allocation
- **Unified Infrastructure**: Run both Slurm and Kubernetes workloads on the same nodes

**Use Case**: Production environments, dynamic scaling needs, or when you want official support.

See the [Slinky Deployment](#slinky-deployment) section below.

---

## 5. Slinky Deployment

Slinky is SchedMD's official solution for integrating Slurm with Kubernetes. It uses a Kubernetes operator to manage Slurm components, providing dynamic autoscaling and better resource optimization.

### Prerequisites

- Kubernetes cluster (Kind cluster from Section 1)
- `kubectl` configured to access your cluster
- Helm 3.x (for installing the operator)

### Step 1: Install Helm

```bash
# Download and install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

### Step 2: Install the Slurm Operator

Slinky uses a Slurm Operator that manages Slurm nodes as Kubernetes pods.

```bash
# Add SchedMD Helm repository (if available publicly)
# Note: Slinky may require commercial license - check with SchedMD
helm repo add schedmd https://charts.schedmd.com
helm repo update

# Create namespace for Slurm
kubectl create namespace slurm

# Install Slurm Operator
helm install slurm-operator schedmd/slurm-operator \
    --namespace slurm \
    --set operator.image.tag=latest
```

**Note**: Slinky is available to select SchedMD customers with commercial support. You may need to:

1. Contact SchedMD: `sales@schedmd.com` or visit the [Slinky GitHub page](https://github.com/SchedMD/slinky)
2. Obtain access credentials or Helm repository URLs
3. Configure authentication if required

### Step 3: Deploy Slurm Controller

The Slurm Operator manages a custom resource `SlurmCluster`:

```yaml
# k8s-manifests/hpc-slurm/slinky-cluster.yaml
apiVersion: slurm.schedmd.com/v1
kind: SlurmCluster
metadata:
  name: slurm-cluster
  namespace: slurm
spec:
  # Controller configuration
  controller:
    replicas: 1
    image: slurm:24.11.0  # Use your Slurm container image
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  
  # Compute node configuration
  compute:
    image: slurm:24.11.0  # Use your Slurm container image
    minReplicas: 1
    maxReplicas: 10
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
  
  # Database configuration (for accounting)
  database:
    enabled: true
    image: mariadb:10.11
    storage:
      size: 10Gi
      storageClassName: standard
  
  # Storage configuration
  storage:
    slurmState:
      size: 5Gi
      storageClassName: standard
```

Apply the cluster configuration:

```bash
kubectl apply -f k8s-manifests/hpc-slurm/slinky-cluster.yaml
```

### Step 4: Verify Slurm Cluster

```bash
# Check SlurmCluster resource
kubectl get slurmcluster -n slurm

# Check pods
kubectl get pods -n slurm

# Check services
kubectl get svc -n slurm

# Check operator logs
kubectl logs -n slurm -l app=slurm-operator
```

### Step 5: Access Slurm

Once deployed, you can access Slurm by port-forwarding to the controller:

```bash
# Port-forward to Slurm controller
kubectl port-forward -n slurm svc/slurm-controller 6817:6817 6818:6818

# In another terminal, access Slurm
kubectl exec -it -n slurm deployment/slurm-controller -- sinfo
kubectl exec -it -n slurm deployment/slurm-controller -- squeue
```

### Step 6: Submit a Test Job

```bash
# Create a simple job script
cat > /tmp/test-job.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=/tmp/job-%j.out
echo "Hello from Slurm in Kubernetes!"
hostname
date
EOF

# Submit job (copy script into controller pod first)
kubectl cp /tmp/test-job.sh slurm/slurm-controller-0:/tmp/test-job.sh
kubectl exec -it -n slurm deployment/slurm-controller -- sbatch /tmp/test-job.sh
```

### Benefits of Slinky

According to [SchedMD's Slinky documentation](https://www.schedmd.com/slinky/why-slinky/), Slinky provides:

- **Dynamic Autoscaling**: Automatically scales compute nodes based on job queue
- **Resource Optimization**: Intelligent scheduling across Kubernetes and Slurm
- **Unified Infrastructure**: Run both Slurm and Kubernetes workloads together
- **Consistent Deployment**: Container images ensure reproducible environments
- **Flexibility**: Custom Slurm images with your dependencies

### Additional Resources

- [Slinky Documentation](https://www.schedmd.com/slinky/why-slinky/)
- [Contact SchedMD](mailto:sales@schedmd.com) for commercial support and access
- [Slinky GitHub Repository](https://github.com/SchedMD/slinky) (check for public releases)

---

## 6. Static Slurm Deployment

If you prefer a static deployment without the operator, you can manually create Kubernetes resources for Slurm components. This approach gives you full control but requires more manual configuration.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Kind)                   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌──────────────┐                  │
│  │   MariaDB    │◄───┤  slurmdbd    │                  │
│  │ (StatefulSet)│    │(Deployment)  │                  │
│  └──────────────┘    └──────┬───────┘                  │
│                             │                            │
│                      ┌──────▼───────┐                   │
│                      │ slurmctld    │                   │
│                      │(Deployment)  │                   │
│                      └──────┬───────┘                   │
│                             │                            │
│         ┌───────────────────┼───────────────────┐      │
│         │                   │                   │       │
│  ┌──────▼──────┐   ┌───────▼──────┐  ┌────────▼─────┐│
│  │ slurmd-0    │   │ slurmd-1     │  │ slurmd-2     ││
│  │(StatefulSet)│   │(StatefulSet) │  │(StatefulSet) ││
│  └─────────────┘   └──────────────┘  └──────────────┘│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Prerequisites

- Slurm container images built (see Container Build section)
- MUNGE key as Kubernetes Secret
- Persistent storage for database and state

### Step 1: Create MUNGE Key Secret

Slurm requires a shared MUNGE key across all components for authentication.

```bash
# Generate MUNGE key (if you don't have one)
docker run --rm -v $(pwd)/tmp:/tmp ubuntu:22.04 bash -c "
    apt-get update && apt-get install -y munge && 
    /usr/sbin/create-munge-key -f && 
    cp /etc/munge/munge.key /tmp/munge.key
"

# Create Kubernetes secret from the key
kubectl create secret generic slurm-munge-key \
    --from-file=munge.key=tmp/munge.key \
    --namespace=slurm
```

### Step 2: Create Persistent Volumes

Create storage for MariaDB and Slurm state:

```yaml
# k8s-manifests/hpc-slurm/storage.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: slurm-db-pvc
  namespace: slurm
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: slurm-state-pvc
  namespace: slurm
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
```

### Step 3: Deploy MariaDB

```yaml
# k8s-manifests/hpc-slurm/mariadb-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: slurm-mariadb
  namespace: slurm
spec:
  selector:
    app: slurm-mariadb
  ports:
    - port: 3306
      targetPort: 3306
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: slurm-mariadb
  namespace: slurm
spec:
  serviceName: slurm-mariadb
  replicas: 1
  selector:
    matchLabels:
      app: slurm-mariadb
  template:
    metadata:
      labels:
        app: slurm-mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.11
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword"
        - name: MYSQL_DATABASE
          value: "slurm_acct_db"
        - name: MYSQL_USER
          value: "slurm"
        - name: MYSQL_PASSWORD
          value: "slurm"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 10Gi
```

### Step 4: Deploy Slurm Components

Create deployments for `slurmdbd`, `slurmctld`, and `slurmd`. These will use the container images you build (see Container Build section).

See the [K8s Manifests](#k8s-manifests) section for complete deployment files.

---

## 7. Container Build and Deployment

### Building Slurm Container Images

The Slurm container images need to be built and loaded into your Kind cluster:

```bash
# Build the base Slurm image
docker build -t slurm-base:latest containers/images/slurm-base/Docker/

# Load into Kind cluster
kind load docker-image slurm-base:latest --name ai-hyperscaler
```

**Note**: The container expects Slurm packages to be available at `/tmp/slurm-packages` in the container. You can:

1. **Copy packages into image** (modify Dockerfile to COPY packages)
2. **Mount packages as volume** (recommended for development - see manifests)
3. **Use InitContainer** to download packages

### Generating MUNGE Key

Slurm requires a shared MUNGE key for authentication:

```bash
# Generate MUNGE key
./scripts/generate-munge-key.sh

# Create Kubernetes secret
kubectl create secret generic slurm-munge-key \
    --from-file=munge.key=build/shared/munge/munge.key \
    --namespace=slurm
```

### Deploying Static Slurm

```bash
# Create namespace
kubectl apply -f k8s-manifests/hpc-slurm/namespace.yaml

# Create secrets (update with your values)
kubectl apply -f k8s-manifests/hpc-slurm/secrets.yaml

# Create storage
kubectl apply -f k8s-manifests/hpc-slurm/storage.yaml

# Deploy components (order matters!)
kubectl apply -f k8s-manifests/hpc-slurm/mariadb-deployment.yaml
kubectl apply -f k8s-manifests/hpc-slurm/slurmdbd-deployment.yaml
kubectl apply -f k8s-manifests/hpc-slurm/slurmctld-deployment.yaml
kubectl apply -f k8s-manifests/hpc-slurm/slurmd-statefulset.yaml
```

### Verifying Deployment

```bash
# Run verification script
./scripts/verify-k8s-hpc.sh

# Or manually check
kubectl get pods -n slurm
kubectl get svc -n slurm

# Access Slurm controller
kubectl exec -it -n slurm deployment/slurm-controller -- sinfo
kubectl exec -it -n slurm deployment/slurm-controller -- squeue
```

---

## 8. vCluster Setup for Cloud Environment

vCluster provides true multi-tenancy by running virtual Kubernetes clusters inside pods. This simulates a "Cloud" environment where each tenant gets their own cluster.

### Prerequisites

- Kubernetes cluster running (Kind cluster from Section 1)
- `vcluster` CLI installed

### Step 1: Install vCluster CLI

```bash
# Download and install vcluster CLI
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin/

# Verify
vcluster version
```

### Step 2: Install vCluster Operator

The vCluster operator manages virtual clusters in your host cluster:

```bash
# Install vcluster operator via Helm
helm repo add loft-sh https://charts.loft.sh
helm repo update

# Install operator
helm install vcluster-operator loft-sh/vcluster-operator \
    --namespace vcluster-operator \
    --create-namespace \
    --set operator.env.LOG_LEVEL=debug
```

### Step 3: Create Virtual Cluster

Create a virtual cluster for "Cloud" tenants:

```bash
# Create namespace for virtual cluster
kubectl create namespace cloud-tenant-1

# Create virtual cluster
vcluster create cloud-cluster-1 \
    --namespace cloud-tenant-1 \
    --kubernetes-version 1.28 \
    --expose-local
```

This creates a virtual cluster accessible at `https://cloud-cluster-1.vcluster.tenant-1.svc.cluster.local`.

### Step 4: Access Virtual Cluster

```bash
# Get kubeconfig for virtual cluster
vcluster connect cloud-cluster-1 --namespace cloud-tenant-1

# This will:
# 1. Port-forward to the virtual cluster API server
# 2. Merge kubeconfig with virtual cluster context
# 3. Switch kubectl context to virtual cluster

# Verify you're in the virtual cluster
kubectl get nodes  # Should show nodes from host cluster
kubectl get namespace  # Should show only default namespace (isolated view)
```

### Step 5: Deploy ArgoCD in Virtual Cluster

Once in the virtual cluster, you can deploy applications as if it's a real cluster:

```bash
# Deploy ArgoCD in virtual cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD (in virtual cluster context)
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### Benefits of vCluster Approach

- **True Isolation**: Each tenant has their own API server and control plane
- **Admin Access**: Tenants can be cluster admins in their vCluster without affecting host
- **Resource Efficiency**: Still uses host cluster nodes (no VMs)
- **Familiar Experience**: Tenants interact with a normal Kubernetes cluster

---

## 9. Next Steps

1. **Choose Your Deployment Method**: Decide between Slinky (recommended) or static deployment
2. **Build Container Images**: Create Slurm container images (see Section 7)
3. **Deploy to Cluster**: Apply Kubernetes manifests
4. **Verify Setup**: Run `./scripts/verify-k8s-hpc.sh`
5. **Configure Cloud Environment**: Set up vCluster for multi-tenancy (see Section 8)
6. **Submit Test Jobs**: Test Slurm job submission and execution

## Additional Resources

- **Slinky Documentation**: https://www.schedmd.com/slinky/why-slinky/
- **vCluster Documentation**: https://www.vcluster.com/docs
- **Kind Documentation**: https://kind.sigs.k8s.io/docs/user/quick-start/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

