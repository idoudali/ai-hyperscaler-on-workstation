#!/bin/bash
# Verification script for K8s-native HPC setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${SLURM_NAMESPACE:-slurm}"

echo "=========================================="
echo "Verifying K8s-native HPC Setup"
echo "=========================================="
echo ""

# Check cluster connectivity
echo "1. Checking Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi
echo "✓ Cluster accessible"
echo ""

# Check namespace
echo "2. Checking namespace '$NAMESPACE'..."
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "WARNING: Namespace '$NAMESPACE' does not exist"
    echo "  Create it with: kubectl create namespace $NAMESPACE"
else
    echo "✓ Namespace exists"
fi
echo ""

# Check pods
echo "3. Checking Slurm pods..."
PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [ -z "$PODS" ]; then
    echo "WARNING: No pods found in namespace '$NAMESPACE'"
    echo "  Deploy Slurm with: kubectl apply -f k8s-manifests/hpc-slurm/"
else
    echo "Found pods: $PODS"
    echo ""
    echo "Pod status:"
    kubectl get pods -n "$NAMESPACE"
fi
echo ""

# Check services
echo "4. Checking Slurm services..."
SERVICES=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [ -z "$SERVICES" ]; then
    echo "WARNING: No services found in namespace '$NAMESPACE'"
else
    echo "Found services: $SERVICES"
    echo ""
    kubectl get svc -n "$NAMESPACE"
fi
echo ""

# Check if controller is ready
echo "5. Testing Slurm controller..."
CONTROLLER_POD=$(kubectl get pods -n "$NAMESPACE" -l app=slurm-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -n "$CONTROLLER_POD" ]; then
    echo "Controller pod: $CONTROLLER_POD"
    
    # Check if pod is running
    POD_STATUS=$(kubectl get pod "$CONTROLLER_POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "  Status: $POD_STATUS"
    
    if [ "$POD_STATUS" = "Running" ]; then
        echo "  ✓ Controller is running"
        
        # Test Slurm commands
        if kubectl exec -n "$NAMESPACE" "$CONTROLLER_POD" -- sinfo --version &> /dev/null; then
            echo "  ✓ Slurm commands available"
            
            # Try to get cluster info
            if kubectl exec -n "$NAMESPACE" "$CONTROLLER_POD" -- sinfo &> /dev/null; then
                echo "  ✓ Slurm cluster accessible"
                echo ""
                echo "  Cluster status:"
                kubectl exec -n "$NAMESPACE" "$CONTROLLER_POD" -- sinfo 2>/dev/null || echo "    (Unable to get cluster info)"
            fi
        else
            echo "  WARNING: Slurm commands not available in controller pod"
        fi
    else
        echo "  WARNING: Controller pod is not running (status: $POD_STATUS)"
    fi
else
    echo "WARNING: Slurm controller pod not found"
fi
echo ""

# Summary
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. If pods are not running, check logs:"
echo "     kubectl logs -n $NAMESPACE <pod-name>"
echo ""
echo "  2. To access Slurm controller:"
echo "     kubectl exec -it -n $NAMESPACE deployment/slurm-controller -- bash"
echo ""
echo "  3. To submit a test job, see: docs/guides/k8s-native-setup.md"

