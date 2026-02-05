#!/bin/bash
set -e

echo "================================================="
echo "Case Study 1 Bootstrap"
echo "Target: Phase 7 – Day 6 (Before Step 6.3)"
echo "================================================="

### -------- STEP 1: Foundation Infra --------
echo "[1/9] Creating foundation infrastructure..."
cd ~/case-study-1-infra/infra/foundation

terraform init
terraform apply -var-file="cs1.tfvars" -auto-approve

### -------- STEP 2: AKS Credentials --------
echo "[2/9] Fetching AKS credentials..."
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group) \
  --name $(terraform output -raw aks_name) \
  --overwrite-existing

cd ~/case-study-1-infra

### -------- STEP 3: Install Argo CD --------
echo "[3/9] Installing Argo CD..."

kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

### -------- STEP 4: Platform AppProject --------
echo "[4/9] Creating platform AppProject..."

kubectl apply -f infra/platform-bootstrap/projects/platform-project.yaml

### -------- STEP 5: Platform GitOps Applications --------
echo "[5/9] Applying platform Applications..."

kubectl apply -f infra/platform-bootstrap/platform/applications/

### -------- STEP 6: Wait for Platform Sync --------
echo "[6/9] Waiting for platform apps to sync..."
sleep 30

### -------- STEP 7: Payments AppProject --------
echo "[7/9] Creating payments AppProject..."

kubectl apply -f infra/platform-bootstrap/projects/payments-project.yaml

### -------- STEP 8: Team Repo Structure --------
echo "[8/9] Ensuring team repo structure exists..."

mkdir -p apps/payments/dev
mkdir -p apps/payments/prod

### -------- STEP 9: Final State Check --------
echo "[9/9] Final sanity check..."

kubectl get appproject -n argocd
kubectl get applications -n argocd
kubectl get ns | grep team-payments || true

echo "================================================="
echo "BOOTSTRAP COMPLETE"
echo "You are now at Phase 7 – Day 6, BEFORE Step 6.3"
echo "payments-dev Application intentionally NOT created"
echo "================================================="
