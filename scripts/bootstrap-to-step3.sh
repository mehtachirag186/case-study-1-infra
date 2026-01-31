#!/bin/bash
set -e

echo "=============================================="
echo "Case Study 1 – Bootstrap up to Phase 7 Day 4"
echo "Stopping BEFORE Step 4 (Platform AppProject)"
echo "=============================================="

### 1. Foundation Infra
cd ~/case-study-1-infra/infra/foundation

echo "[1/5] Terraform init..."
terraform init

echo "[2/5] Terraform apply (foundation)..."
terraform apply -var-file="cs1.tfvars" -auto-approve

### 2. AKS Access
echo "[3/5] Fetching AKS credentials..."
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group) \
  --name $(terraform output -raw aks_name) \
  --overwrite-existing

### 3. Install Argo CD (GitOps Control Plane)
echo "[4/5] Installing Argo CD..."
kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

### 4. Verification Only
echo "[5/5] Verifying Argo CD pods..."
kubectl get pods -n argocd

echo "=============================================="
echo "BOOTSTRAP COMPLETE"
echo "You are now at:"
echo "Phase 7 – Day 4"
echo "READY TO START STEP 4 – Platform AppProject"
echo "=============================================="
