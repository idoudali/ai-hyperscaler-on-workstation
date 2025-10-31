# Tutorial: How kubectl Works and YAML File Processing

**Audience:** Developers and operators working with Kubernetes
**Prerequisites:** Basic understanding of Kubernetes concepts
**Time:** 15-20 minutes
**Difficulty:** Intermediate

## Table of Contents

1. [Overview](#overview)
2. [How kubectl Processes YAML Files](#how-kubectl-processes-yaml-files)
3. [YAML File Structure](#yaml-file-structure)
4. [How kubectl Commands Work](#how-kubectl-commands-work)
5. [YAML File Organization](#yaml-file-organization)
6. [How Kustomize Works](#how-kustomize-works)
7. [References](#references)

## Overview

`kubectl` is the command-line tool for interacting with Kubernetes clusters. It acts as a
client that communicates with the Kubernetes API server.

**📚 Official Documentation:** [kubectl Overview](https://kubernetes.io/docs/reference/kubectl/overview/)

### Key Concepts

- **kubectl** is a client that sends HTTP requests to the Kubernetes API server
- **YAML files** are parsed and converted into Kubernetes API objects
- **API server** validates, stores resources in etcd, and triggers controllers
- **Controllers** watch for changes and create actual resources (Pods, Services, etc.)

**📚 Official Documentation:**

- [Kubernetes API Concepts](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)

## How kubectl Processes YAML Files

### Step-by-Step Process

1. **Read YAML File** → kubectl reads the YAML manifest file(s)
2. **Parse YAML** → Converts YAML syntax into Kubernetes API objects (Go structs)
3. **Validate** → Checks required fields, types, and constraints
4. **Send to API Server** → Sends HTTP request to Kubernetes API server
5. **API Server Processes** → API server validates, stores in etcd, triggers controllers
6. **Controllers Act** → Kubernetes controllers (Deployment, Service, etc.) create resources

### Example Flow

```bash
kubectl apply -f deployment.yaml
    ↓
1. kubectl reads deployment.yaml
    ↓
2. Parses YAML → Creates Deployment object
    ↓
3. Validates structure (apiVersion, kind, metadata, spec)
    ↓
4. Sends HTTP POST to: https://<api-server>/apis/apps/v1/namespaces/default/deployments
    ↓
5. API server validates and stores in etcd
    ↓
6. Deployment controller creates ReplicaSet
    ↓
7. ReplicaSet controller creates Pods
    ↓
8. Scheduler assigns Pods to nodes
```

### What Happens at Each Step

**Step 1: File Reading**

- kubectl reads the YAML file from disk
- Supports multiple files: `kubectl apply -f file1.yaml -f file2.yaml`
- Supports directories: `kubectl apply -f ./manifests/`
- Supports stdin: `cat file.yaml | kubectl apply -f -`

**Step 2: YAML Parsing**

- YAML parser converts text into Go structs
- Validates YAML syntax (indentation, brackets, etc.)
- Handles multiple documents separated by `---`

**Step 3: Client-Side Validation**

- Checks required fields (apiVersion, kind, metadata.name)
- Validates field types (strings, integers, booleans)
- Checks namespace exists (if specified)
- Validates resource names (DNS subdomain format)

**Step 4: API Request**

- Constructs HTTP request with authentication
- Sends to appropriate API endpoint based on `apiVersion` and `kind`
- Includes request body with the parsed object

**Step 5: Server-Side Processing**

- API server validates the request
- Checks authorization (RBAC)
- Validates against OpenAPI schema
- Stores in etcd (cluster's database)
- Triggers admission controllers (webhooks, policies)

**Step 6: Controller Actions**

- Controllers watch etcd for changes
- Deployment controller creates ReplicaSet
- ReplicaSet controller creates Pods
- Service controller creates endpoints
- Scheduler assigns Pods to nodes

**📚 Official Documentation:**

- [Kubernetes Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Kubernetes Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)

## YAML File Structure

Every Kubernetes YAML file follows this structure:

```yaml
apiVersion: v1              # API version (v1, apps/v1, batch/v1, etc.)
kind: Pod                   # Resource type (Pod, Deployment, Service, etc.)
metadata:                    # Object metadata
  name: my-pod              # Resource name
  namespace: default        # Namespace (optional)
  labels:                   # Labels for selection
    app: myapp
spec:                       # Desired state specification
  containers:               # Container definitions
  - name: nginx
    image: nginx:latest
```

### Key Fields Explained

#### apiVersion

Determines which API group and version to use:

- **Core API**: `v1` (Pods, Services, ConfigMaps, Secrets, Namespaces)
- **Apps API**: `apps/v1` (Deployments, StatefulSets, DaemonSets)
- **Batch API**: `batch/v1` (Jobs, CronJobs)
- **Extensions**: `networking.k8s.io/v1` (Ingress), `rbac.authorization.k8s.io/v1` (Roles)

**📚 Official Documentation:** [API Groups](https://kubernetes.io/docs/reference/using-api/api-overview/#api-groups)

#### kind

The type of resource being defined:

- **Workloads**: Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob
- **Services**: Service, Ingress
- **Config**: ConfigMap, Secret
- **Storage**: PersistentVolume, PersistentVolumeClaim
- **RBAC**: Role, RoleBinding, ClusterRole, ClusterRoleBinding

**📚 Official Documentation:** [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)

#### metadata

Identity and metadata for the resource:

- **name**: Unique name within namespace (required)
- **namespace**: Logical grouping (optional, defaults to `default`)
- **labels**: Key-value pairs for selection and organization
- **annotations**: Additional metadata (not used for selection)

#### spec

Desired state specification - what you want the resource to look like:

- **Pods**: Container images, volumes, resource limits
- **Deployments**: Replicas, pod template, update strategy
- **Services**: Selector, ports, type (ClusterIP, NodePort, LoadBalancer)
- **ConfigMaps**: Key-value pairs or file contents

#### status

Current state (managed by Kubernetes, read-only):

- Automatically populated by Kubernetes
- Shows actual state vs desired state (spec)
- Updated by controllers and kubelet

## How kubectl Commands Work

### Common Commands and Their Internal Process

| Command | What It Does Internally |
|---------|------------------------|
| `kubectl apply -f file.yaml` | Reads YAML → Parses → Validates → Sends HTTP POST/PUT to API → Creates/Updates resource |
| `kubectl get pods` | Sends HTTP GET to `/api/v1/namespaces/default/pods` → API queries etcd → Returns Pod list |
| `kubectl delete pod <name>` | Sends HTTP DELETE to `/api/v1/namespaces/default/pods/<name>` → API removes from etcd → Pod terminates |
| `kubectl describe pod <name>` | Sends multiple GET requests → Aggregates info from Pod, Events, Nodes → Displays formatted details |
| `kubectl logs pod/<name>` | Sends GET to `/api/v1/namespaces/default/pods/<name>/log` → kubelet returns container logs |
| `kubectl exec -it pod/<name> -- /bin/bash` | Establishes WebSocket connection → Streams stdin/stdout → Executes command in container |

### kubectl Configuration

kubectl reads configuration from `~/.kube/config`:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: my-cluster
    cluster:
      server: https://api-server:6443
      certificate-authority-data: <base64-cert>
contexts:
  - name: my-context
    context:
      cluster: my-cluster
      user: my-user
      namespace: default
current-context: my-context
users:
  - name: my-user
    user:
      client-certificate-data: <base64-cert>
      client-key-data: <base64-key>
```

**Configuration Flow:**

1. kubectl reads `~/.kube/config` (or `$KUBECONFIG`)
2. Selects current context
3. Uses cluster endpoint and user credentials
4. Sends authenticated requests to API server

**📚 Official Documentation:** [Organize Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

## YAML File Organization

### Single File (Multiple Resources)

You can define multiple resources in one file using `---` separator:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:latest
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
```

**Pros:** Simple, all related resources together
**Cons:** Hard to manage large applications, difficult to reuse

### Multiple Files (Recommended)

Organize resources into separate files:

```text
myapp/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── secret.yaml
```

**Apply all files:**

```bash
kubectl apply -f myapp/
```

**Pros:** Better organization, easier to maintain, reusable components
**Cons:** Need to apply multiple files

### Kustomize Directory

Use Kustomize for advanced configuration management:

```text
base/
├── kustomization.yaml    # Lists all resources
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

**kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

namespace: mlops
commonLabels:
  app: minio
  version: v1.0
```

**Apply with Kustomize:**

```bash
kubectl apply -k base/
```

**Pros:** Template-free configuration management, overlays for environments, DRY principle
**Cons:** Additional tool to learn

## How Kustomize Works

Kustomize processes YAML files before kubectl sends them to the API server. It's built into kubectl (since v1.14).

### Processing Steps

1. **Reads `kustomization.yaml`** → Lists all resources and transformations
2. **Loads Base Resources** → Reads all YAML files listed in `resources:`
3. **Applies Transformations** → Patches, overlays, name prefixes, labels
4. **Generates Final YAML** → Single combined YAML output
5. **kubectl Applies** → Sends to API server

### Example: Kustomize Processing

**Input (kustomization.yaml):**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

namespace: mlops
commonLabels:
  app: minio
  version: v1.0
```

**When you run `kubectl apply -k .`:**

```bash
# Step 1: Kustomize builds combined YAML
kubectl kustomize . > /tmp/combined.yaml

# Step 2: kubectl applies the combined YAML
kubectl apply -f /tmp/combined.yaml
```

**What Kustomize does:**

1. Reads `deployment.yaml` and `service.yaml`
2. Adds namespace `mlops` to all resources
3. Adds labels `app: minio` and `version: v1.0` to all resources
4. Combines into single YAML output
5. kubectl sends to API server

### Kustomize Features

**1. Resource Management**

- Lists all resources in one place
- Handles dependencies automatically

**2. Namespace Management**

- Sets namespace for all resources
- No need to specify in each file

**3. Label Management**

- Adds common labels to all resources
- Useful for organization and selection

**4. Image Management**

- Updates image tags across resources
- Useful for version updates

**5. Overlays**

- Environment-specific configurations
- Dev, staging, production variants

**Example Overlay:**

```text
base/
├── kustomization.yaml
└── deployment.yaml

overlays/
├── dev/
│   └── kustomization.yaml  # References base, adds dev-specific changes
└── prod/
    └── kustomization.yaml   # References base, adds prod-specific changes
```

## References

### Official Documentation

#### Core Kubernetes Concepts

- **Kubernetes API Concepts:** https://kubernetes.io/docs/concepts/overview/kubernetes-api/
- **Kubernetes Architecture:** https://kubernetes.io/docs/concepts/architecture/
- **Working with Objects:** https://kubernetes.io/docs/concepts/overview/working-with-objects/
- **Kubernetes API Reference:** https://kubernetes.io/docs/reference/kubernetes-api/

#### kubectl Documentation

- **kubectl Overview:** https://kubernetes.io/docs/reference/kubectl/overview/
- **kubectl Commands Reference:** https://kubernetes.io/docs/reference/kubectl/
- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **kubectl Configuration:** https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

#### Kustomize Documentation

- **Kustomize Official Site:** https://kustomize.io/
- **Kustomize Tutorial:** https://kustomize.io/tutorial
- **Kustomize in kubectl:** https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/

### Related Tutorials

- **Kubernetes Basics:** [01-kubernetes-basics.md](01-kubernetes-basics.md) - Practical examples using kubectl and YAML
- **Manual Deployment Guide:** [../../getting-started/manual-k8s-deployment.md](../../getting-started/manual-k8s-deployment.md)
- **k8s-manifests README:** [../../../k8s-manifests/README.md](../../../k8s-manifests/README.md)

### Additional Resources

- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **YAML Syntax:** https://yaml.org/spec/1.2.2/
- **Kubernetes API Conventions:** https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md

---

**Last Updated:** 2025-01-XX
**Version:** 1.0
**Maintainer:** AI-HOW Platform Team
