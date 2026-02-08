#!/bin/bash
set -e

echo "================================================="
echo "Case Study 1 Bootstrap"
echo "Target: Phase 7 – Day 7 (DEV + PROD running)"
echo "================================================="

ROOT=~/case-study-1-infra

# -------------------------------
# STEP 1: Foundation Infra
# -------------------------------
echo "[1/9] Creating foundation infrastructure..."
cd $ROOT/infra/foundation

terraform init
terraform apply -var-file="cs1.tfvars" -auto-approve

# -------------------------------
# STEP 2: AKS Credentials
# -------------------------------
echo "[2/9] Fetching AKS credentials..."
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group) \
  --name $(terraform output -raw aks_name) \
  --overwrite-existing

cd $ROOT

# -------------------------------
# STEP 3: Install Argo CD (server-side apply)
# -------------------------------
echo "[3/9] Installing Argo CD..."

kubectl create namespace argocd || true

kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server..."
kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

# -------------------------------
# STEP 4: Platform AppProject
# -------------------------------
echo "[4/9] Applying platform AppProject..."
kubectl apply -f infra/platform-bootstrap/projects/platform-project.yaml

# -------------------------------
# STEP 5: Platform Applications
# -------------------------------
echo "[5/9] Applying platform GitOps applications..."
kubectl apply -f infra/platform-bootstrap/platform/applications/

echo "Waiting for platform apps to sync..."
sleep 30

# -------------------------------
# STEP 6: Payments AppProject
# -------------------------------
echo "[6/9] Applying payments AppProject..."
kubectl apply -f infra/platform-bootstrap/projects/payments-project.yaml

# -------------------------------
# STEP 7: Team Applications (DEV + PROD)
# -------------------------------
echo "[7/9] Applying team Argo CD applications..."
kubectl apply -f apps/payments/applications/

echo "Waiting for team apps to sync..."
sleep 30

# -------------------------------
# STEP 8: Final Verification
# -------------------------------
echo "[8/9] Verifying Argo CD applications..."
kubectl get applications -n argocd

echo "[9/9] Verifying workloads..."
kubectl get pods -n team-payments-dev
kubectl get pods -n team-payments-prod

echo "================================================="
echo "BOOTSTRAP COMPLETE"
echo "State: DEV and PROD running via GitOps"
echo "Ready for Day 8 (Drift Simulation)"
echo "================================================="
