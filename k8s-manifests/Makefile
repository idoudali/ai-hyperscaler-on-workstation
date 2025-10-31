# Kubernetes Manifests Deployment Makefile
#
# This Makefile provides targets for deploying applications to Kubernetes
# using either GitOps (ArgoCD) or direct kubectl commands.
#
# Usage:
#   make gitops-deploy-mlops-stack  # Deploy via GitOps (recommended)
#   make k8s-deploy-manual          # Deploy directly with kubectl (testing)
#   make gitops-status              # Check deployment status

# Include shared variables from parent directory
PROJECT_ROOT := $(shell pwd)/..
include $(PROJECT_ROOT)/Makefile.vars

# Set default shell to bash
SHELL := /bin/bash

# Default target
.PHONY: all
all: help

#==============================================================================
# GitOps Application Deployment (ArgoCD)
#==============================================================================

# Deploy all MLOps applications via GitOps (App of Apps pattern)
.PHONY: gitops-deploy-mlops-stack
gitops-deploy-mlops-stack:
	@echo "=========================================="
	@echo "Deploying MLOps Stack via GitOps"
	@echo "=========================================="
	@echo "Using App of Apps pattern..."
	@echo ""
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		echo "Please run 'make cloud-cluster-deploy' first to deploy Kubernetes and ArgoCD."; \
		exit 1; \
	fi
	@echo "Using kubeconfig: $(CLOUD_CLUSTER_KUBECONFIG)"
	@echo ""
	@echo "Deploying ArgoCD Application (App of Apps)..."
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl apply -f argocd-apps/mlops-stack-app.yaml
	@echo ""
	@echo "✅ MLOps stack Application created"
	@echo ""
	@echo "ArgoCD will now automatically deploy all child applications:"
	@echo "  - MinIO (object storage)"
	@echo "  - PostgreSQL (database)"
	@echo ""
	@echo "Monitor deployment progress:"
	@echo "  make gitops-status"
	@echo ""
	@echo "Or access ArgoCD UI:"
	@echo "  KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo "  Open: https://localhost:8080"

# Deploy MinIO individually via GitOps
.PHONY: gitops-deploy-minio
gitops-deploy-minio:
	@echo "Deploying MinIO via GitOps..."
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl apply -f argocd-apps/minio-app.yaml
	@echo "✅ MinIO Application created"

# Deploy PostgreSQL individually via GitOps
.PHONY: gitops-deploy-postgresql
gitops-deploy-postgresql:
	@echo "Deploying PostgreSQL via GitOps..."
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl apply -f argocd-apps/postgresql-app.yaml
	@echo "✅ PostgreSQL Application created"

# Deploy all applications individually (not using App of Apps)
.PHONY: gitops-deploy-apps
gitops-deploy-apps: gitops-deploy-minio gitops-deploy-postgresql
	@echo "✅ All applications deployed individually"

# Validate Git repository URLs are configured
.PHONY: gitops-validate
gitops-validate:
	@echo "Validating GitOps configuration..."
	@echo ""
	@echo "Checking for placeholder repository URLs..."
	@if grep -r "your-org/ai-how" argocd-apps/ >/dev/null 2>&1; then \
		echo "❌ Error: Placeholder repository URLs found!"; \
		echo ""; \
		echo "Please update the 'repoURL' in these files:"; \
		grep -l "your-org/ai-how" argocd-apps/*.yaml; \
		echo ""; \
		echo "Update with your actual Git repository URL:"; \
		echo "  sed -i 's|https://github.com/your-org/ai-how|https://github.com/YOUR_ORG/ai-how|g' argocd-apps/*.yaml"; \
		exit 1; \
	else \
		echo "✅ Repository URLs configured"; \
	fi
	@echo ""
	@echo "Checking kubeconfig..."
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "⚠️  Warning: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		echo "Run 'make cloud-cluster-deploy' first."; \
	else \
		echo "✅ Kubeconfig found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
	fi
	@echo ""
	@echo "✅ GitOps validation complete"

# Update repository URLs in all ArgoCD applications
.PHONY: gitops-update-repo-url
gitops-update-repo-url:
	@echo "Updating Git repository URLs in ArgoCD applications..."
	@echo ""
	@if [ -z "$(GIT_REPO_URL)" ]; then \
		echo "❌ Error: GIT_REPO_URL not specified"; \
		echo ""; \
		echo "Usage:"; \
		echo "  make gitops-update-repo-url GIT_REPO_URL=https://github.com/YOUR_ORG/ai-how"; \
		exit 1; \
	fi
	@echo "Updating to: $(GIT_REPO_URL)"
	@sed -i 's|https://github.com/your-org/ai-how|$(GIT_REPO_URL)|g' argocd-apps/*.yaml
	@echo ""
	@echo "✅ Repository URLs updated in:"
	@ls argocd-apps/*.yaml
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review changes: git diff argocd-apps/"
	@echo "  2. Commit: git add argocd-apps/ && git commit -m 'Configure Git repository URLs'"
	@echo "  3. Push: git push"

# Check GitOps application status
.PHONY: gitops-status
gitops-status:
	@echo "=========================================="
	@echo "GitOps Application Status"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo ""
	@echo "ArgoCD Applications:"
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get applications -n argocd -o wide
	@echo ""
	@echo "Deployed Resources (mlops namespace):"
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get all -n mlops
	@echo ""
	@echo "Access ArgoCD UI:"
	@echo "  KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo "  Open: https://localhost:8080"

#==============================================================================
# Direct Kubernetes Manifest Deployment (Without GitOps)
#==============================================================================

# Deploy MinIO directly with kubectl (without ArgoCD)
.PHONY: k8s-deploy-minio-manual
k8s-deploy-minio-manual:
	@echo "=========================================="
	@echo "Deploying MinIO Directly (Manual)"
	@echo "=========================================="
	@echo "⚠️  Note: This bypasses GitOps. For production, use 'make gitops-deploy-mlops-stack'"
	@echo ""
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Deploying MinIO from base/mlops/minio..."
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl apply -k base/mlops/minio
	@echo ""
	@echo "✅ MinIO deployed"
	@echo ""
	@echo "Check status:"
	@echo "  KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get all -n mlops -l app=minio"

# Deploy PostgreSQL directly with kubectl (without ArgoCD)
.PHONY: k8s-deploy-postgresql-manual
k8s-deploy-postgresql-manual:
	@echo "=========================================="
	@echo "Deploying PostgreSQL Directly (Manual)"
	@echo "=========================================="
	@echo "⚠️  Note: This bypasses GitOps. For production, use 'make gitops-deploy-mlops-stack'"
	@echo ""
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Deploying PostgreSQL from base/mlops/postgresql..."
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl apply -k base/mlops/postgresql
	@echo ""
	@echo "✅ PostgreSQL deployed"
	@echo ""
	@echo "Check status:"
	@echo "  KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get all -n mlops -l app.kubernetes.io/name=postgresql"

# Deploy all applications manually (bypasses GitOps)
.PHONY: k8s-deploy-manual
k8s-deploy-manual: k8s-deploy-minio-manual k8s-deploy-postgresql-manual
	@echo ""
	@echo "=========================================="
	@echo "✅ All Applications Deployed Manually"
	@echo "=========================================="
	@echo ""
	@echo "⚠️  Note: These resources are not managed by GitOps/ArgoCD."
	@echo ""
	@echo "For production, consider:"
	@echo "  1. Delete manual deployments:"
	@echo "     KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl delete -k base/mlops/minio"
	@echo "     KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl delete -k base/mlops/postgresql"
	@echo ""
	@echo "  2. Deploy via GitOps:"
	@echo "     make gitops-deploy-mlops-stack"

# Validate Kubernetes manifests with kustomize build
.PHONY: k8s-validate-manifests
k8s-validate-manifests:
	@echo "Validating Kubernetes manifests..."
	@echo ""
	@echo "Building MinIO manifests with kustomize..."
	@kubectl kustomize base/mlops/minio > /tmp/minio-manifests.yaml
	@echo "✅ MinIO manifests valid"
	@echo ""
	@echo "Building PostgreSQL manifests with kustomize..."
	@kubectl kustomize base/mlops/postgresql > /tmp/postgresql-manifests.yaml
	@echo "✅ PostgreSQL manifests valid"
	@echo ""
	@echo "✅ All manifests validated successfully"
	@echo ""
	@echo "Preview generated manifests:"
	@echo "  cat /tmp/minio-manifests.yaml"
	@echo "  cat /tmp/postgresql-manifests.yaml"

#==============================================================================
# Port Forwarding Helpers
#==============================================================================

# Port-forward to Kubernetes Dashboard
.PHONY: port-forward-dashboard
port-forward-dashboard:
	@echo "=========================================="
	@echo "Kubernetes Dashboard Port Forwarding"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		echo "Please run 'make cloud-cluster-deploy' first."; \
		exit 1; \
	fi
	@echo "Checking Dashboard service..."
	@if ! KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get svc kubernetes-dashboard-kong-proxy -n kubernetes-dashboard >/dev/null 2>&1; then \
		echo "❌ Error: Kubernetes Dashboard service not found."; \
		echo "Please ensure the Dashboard is deployed: cd .. && make cloud-cluster-deploy"; \
		exit 1; \
	fi
	@echo "✅ Dashboard service found"
	@echo ""
	@echo "Starting port-forward to Kubernetes Dashboard..."
	@echo "  Local port: 8443"
	@echo "  Remote port: 443"
	@echo ""
	@echo "📝 Access Instructions:"
	@echo "  1. Open in browser: https://localhost:8443"
	@echo "  2. You may see a certificate warning - click 'Advanced' and proceed"
	@echo "  3. Get authentication token (in another terminal):"
	@echo "     KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n kubernetes-dashboard create token admin-user"
	@echo "  4. Copy the token and paste it into the Dashboard login page"
	@echo ""
	@echo "⚠️  Note: Keep this terminal open. Press Ctrl+C to stop port-forwarding."
	@echo ""
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

# Get Kubernetes Dashboard authentication token
.PHONY: dashboard-token
dashboard-token:
	@echo "=========================================="
	@echo "Kubernetes Dashboard Authentication Token"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Generating authentication token..."
	@echo ""
	@TOKEN=$$(KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n kubernetes-dashboard create token admin-user --duration=1h 2>&1); \
		if [ $$? -ne 0 ]; then \
			echo "❌ Failed to generate token:"; \
			echo "$$TOKEN"; \
			echo ""; \
			echo "Run 'make dashboard-verify' to diagnose the issue."; \
			exit 1; \
		fi; \
		echo "$$TOKEN"
	@echo ""
	@echo "✅ Token generated (valid for 1 hour)"
	@echo ""
	@echo "📝 Usage:"
	@echo "  1. Copy the token above (entire output)"
	@echo "  2. Open Dashboard: https://localhost:8443"
	@echo "  3. Select 'Token' authentication method"
	@echo "  4. Paste token into login page"
	@echo "  5. Run 'make dashboard-token' again when token expires"
	@echo ""
	@echo "⚠️  Important: Make sure port-forward is running:"
	@echo "   Run 'make port-forward-dashboard' in another terminal"

# Port-forward to ArgoCD
.PHONY: port-forward-argocd
port-forward-argocd:
	@echo "=========================================="
	@echo "ArgoCD Port Forwarding"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		echo "Please run 'make cloud-cluster-deploy' first."; \
		exit 1; \
	fi
	@echo "Checking ArgoCD service..."
	@if ! KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then \
		echo "❌ Error: ArgoCD service not found."; \
		echo "Please ensure ArgoCD is deployed: cd .. && make cloud-cluster-deploy"; \
		exit 1; \
	fi
	@echo "✅ ArgoCD service found"
	@echo ""
	@echo "Starting port-forward to ArgoCD..."
	@echo "  Local port: 8080"
	@echo "  Remote port: 443"
	@echo ""
	@echo "📝 Access Instructions:"
	@echo "  1. Open in browser: https://localhost:8080"
	@echo "  2. You may see a certificate warning - click 'Advanced' and proceed"
	@echo "  3. Get ArgoCD admin password (in another terminal):"
	@echo "     KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@echo "  4. Login with username: admin"
	@echo "  5. Use the password from step 3"
	@echo ""
	@echo "⚠️  Note: Keep this terminal open. Press Ctrl+C to stop port-forwarding."
	@echo ""
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n argocd port-forward svc/argocd-server 8080:443

# Get ArgoCD admin password
.PHONY: argocd-password
argocd-password:
	@echo "=========================================="
	@echo "ArgoCD Admin Password"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Retrieving ArgoCD admin password..."
	@echo ""
	@if ! KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then \
		echo "❌ Error: ArgoCD admin secret not found."; \
		echo "ArgoCD may not be fully deployed yet."; \
		exit 1; \
	fi
	@echo "Username: admin"
	@echo "Password:"
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
	@echo ""
	@echo ""
	@echo "✅ Password retrieved"
	@echo ""
	@echo "📝 Usage:"
	@echo "  1. Open ArgoCD: https://localhost:8080"
	@echo "  2. Login with username: admin"
	@echo "  3. Use the password above"

# Get MinIO admin credentials
.PHONY: minio-credentials
minio-credentials:
	@echo "=========================================="
	@echo "MinIO Admin Credentials"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Retrieving MinIO credentials..."
	@echo ""
	@if ! KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops get secret minio-credentials >/dev/null 2>&1; then \
		echo "❌ Error: MinIO secret not found."; \
		echo "Please deploy MinIO first: make k8s-deploy-minio-manual or make gitops-deploy-minio"; \
		exit 1; \
	fi
	@echo "Access Key (Username):"
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops get secret minio-credentials -o jsonpath='{.data.accesskey}' | base64 -d
	@echo ""
	@echo ""
	@echo "Secret Key (Password):"
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops get secret minio-credentials -o jsonpath='{.data.secretkey}' | base64 -d
	@echo ""
	@echo ""
	@echo "✅ Credentials retrieved"
	@echo ""
	@echo "📝 Usage:"
	@echo "  1. Access MinIO Console: http://localhost:9001"
	@echo "  2. Login with Access Key and Secret Key above"
	@echo "  3. Or use MinIO API: http://localhost:9000"
	@echo ""
	@echo "💡 Tip: Run 'make port-forward-minio' to access MinIO Console"

# Port-forward to MinIO (API and Console)
.PHONY: port-forward-minio
port-forward-minio:
	@echo "=========================================="
	@echo "MinIO Port Forwarding"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		echo "Please run 'make cloud-cluster-deploy' first."; \
		exit 1; \
	fi
	@echo "Checking MinIO service..."
	@if ! KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl get svc minio -n mlops >/dev/null 2>&1; then \
		echo "❌ Error: MinIO service not found."; \
		echo "Please deploy MinIO first: make k8s-deploy-minio-manual or make gitops-deploy-minio"; \
		exit 1; \
	fi
	@echo "✅ MinIO service found"
	@echo ""
	@echo "Starting port-forward to MinIO..."
	@echo "  MinIO API (port 9000): http://localhost:9000"
	@echo "  MinIO Console (port 9001): http://localhost:9001"
	@echo ""
	@echo "📝 Access Instructions:"
	@echo "  1. MinIO Console: http://localhost:9001"
	@echo "  2. Get credentials (in another terminal):"
	@echo "     make minio-credentials"
	@echo "  3. Login with Access Key and Secret Key from step 2"
	@echo "  4. MinIO API: http://localhost:9000"
	@echo ""
	@echo "⚠️  Note: Keep this terminal open. Press Ctrl+C to stop port-forwarding."
	@echo ""
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops port-forward svc/minio 9000:9000 9001:9001

# Port-forward to MinIO API only
.PHONY: port-forward-minio-api
port-forward-minio-api:
	@echo "=========================================="
	@echo "MinIO API Port Forwarding"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Starting port-forward to MinIO API..."
	@echo "  MinIO API: http://localhost:9000"
	@echo ""
	@echo "⚠️  Note: Keep this terminal open. Press Ctrl+C to stop port-forwarding."
	@echo ""
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops port-forward svc/minio 9000:9000

# Port-forward to MinIO Console only
.PHONY: port-forward-minio-console
port-forward-minio-console:
	@echo "=========================================="
	@echo "MinIO Console Port Forwarding"
	@echo "=========================================="
	@if [ ! -f "$(CLOUD_CLUSTER_KUBECONFIG)" ]; then \
		echo "❌ Error: Kubeconfig not found: $(CLOUD_CLUSTER_KUBECONFIG)"; \
		exit 1; \
	fi
	@echo "Starting port-forward to MinIO Console..."
	@echo "  MinIO Console: http://localhost:9001"
	@echo ""
	@echo "📝 Get credentials: make minio-credentials"
	@echo ""
	@echo "⚠️  Note: Keep this terminal open. Press Ctrl+C to stop port-forwarding."
	@echo ""
	@KUBECONFIG=$(CLOUD_CLUSTER_KUBECONFIG) kubectl -n mlops port-forward svc/minio 9001:9001

#==============================================================================
# Help
#==============================================================================
.PHONY: help
help:
	@echo "Kubernetes Manifests Deployment Makefile"
	@echo "----------------------------------------"
	@echo ""
	@echo "GitOps Application Deployment (Recommended for Production):"
	@echo "  make gitops-deploy-mlops-stack - Deploy all MLOps apps via GitOps (App of Apps)."
	@echo "  make gitops-deploy-minio       - Deploy MinIO individually via GitOps."
	@echo "  make gitops-deploy-postgresql  - Deploy PostgreSQL individually via GitOps."
	@echo "  make gitops-deploy-apps        - Deploy all apps individually (not App of Apps)."
	@echo "  make gitops-validate           - Validate GitOps configuration (repo URLs, etc)."
	@echo "  make gitops-status             - Check ArgoCD application status."
	@echo "  make gitops-update-repo-url    - Update Git repo URL (use GIT_REPO_URL=...)."
	@echo ""
	@echo "Manual Kubernetes Deployment (Testing/Development Only):"
	@echo "  make k8s-deploy-manual         - Deploy all apps directly with kubectl."
	@echo "  make k8s-deploy-minio-manual   - Deploy MinIO directly (no ArgoCD)."
	@echo "  make k8s-deploy-postgresql-manual - Deploy PostgreSQL directly (no ArgoCD)."
	@echo "  make k8s-validate-manifests    - Validate manifests with kustomize build."
	@echo ""
	@echo "Port Forwarding (Access Web UIs):"
	@echo "  make port-forward-dashboard    - Port-forward to Kubernetes Dashboard (https://localhost:8443)."
	@echo "  make port-forward-argocd       - Port-forward to ArgoCD (https://localhost:8080)."
	@echo "  make port-forward-minio        - Port-forward to MinIO API and Console (http://localhost:9000,9001)."
	@echo "  make port-forward-minio-api    - Port-forward to MinIO API only (http://localhost:9000)."
	@echo "  make port-forward-minio-console - Port-forward to MinIO Console only (http://localhost:9001)."
	@echo ""
	@echo "Authentication Helpers:"
	@echo "  make dashboard-token           - Get Kubernetes Dashboard authentication token."
	@echo "  make argocd-password           - Get ArgoCD admin password."
	@echo "  make minio-credentials         - Get MinIO admin credentials (Access Key and Secret Key)."
	@echo ""
	@echo "Configuration Variables:"
	@echo "  CLOUD_CLUSTER_KUBECONFIG  - Path to kubeconfig (default: $(CLOUD_CLUSTER_KUBECONFIG))"
	@echo "  GIT_REPO_URL              - Git repository URL for ArgoCD applications"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Kubernetes cluster deployed: cd .. && make cloud-cluster-deploy"
	@echo "  - ArgoCD installed (done automatically by cloud-cluster-deploy)"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Deploy Kubernetes: cd .. && make cloud-cluster-deploy"
	@echo "  2. Update Git repo: make gitops-update-repo-url GIT_REPO_URL=https://github.com/YOUR_ORG/ai-how"
	@echo "  3. Deploy apps: make gitops-deploy-mlops-stack"
	@echo "  4. Check status: make gitops-status"
	@echo "  5. Access UIs: make port-forward-dashboard (or port-forward-argocd, port-forward-minio)"
	@echo ""
	@echo "Documentation:"
	@echo "  - GitOps Guide: ../docs/getting-started/quickstart-gitops.md"
	@echo "  - Manual Deployment: ../docs/getting-started/manual-k8s-deployment.md"
	@echo "  - Manifests README: ./README.md"
	@echo "  - Dashboard Access: ../docs/DASHBOARD_ACCESS.md"
