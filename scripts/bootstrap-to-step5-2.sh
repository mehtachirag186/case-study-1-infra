#!/bin/bash
set -e

echo "================================================="
echo "Case Study 1 Bootstrap"
echo "Target: Phase 7 – Day 5 (Step 5.2 complete)"
echo "================================================="

### -------- STEP 1: Foundation Infra --------
echo "[1/10] Creating foundation infrastructure..."
cd ~/case-study-1-infra/infra/foundation

terraform init
terraform apply -var-file="cs1.tfvars" -auto-approve

### -------- STEP 2: AKS Credentials --------
echo "[2/10] Fetching AKS credentials..."
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group) \
  --name $(terraform output -raw aks_name) \
  --overwrite-existing

### -------- STEP 3: Install Argo CD --------
echo "[3/10] Installing Argo CD..."

kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to become ready..."
kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

### -------- STEP 4: Platform AppProject --------
echo "[4/10] Creating Platform AppProject..."

cd ~/case-study-1-infra
mkdir -p infra/platform-bootstrap/projects

printf '%s\n' \
'apiVersion: argoproj.io/v1alpha1' \
'kind: AppProject' \
'metadata:' \
'  name: platform' \
'  namespace: argocd' \
'spec:' \
'  description: Platform-owned resources' \
'  sourceRepos:' \
'    - "*"' \
'  destinations:' \
'    - namespace: "*"' \
'      server: https://kubernetes.default.svc' \
'  clusterResourceWhitelist:' \
'    - group: "*"' \
'      kind: "*"' \
> infra/platform-bootstrap/projects/platform-project.yaml

kubectl apply -f infra/platform-bootstrap/projects/platform-project.yaml

### -------- STEP 5: Namespace Manifests --------
echo "[5/10] Creating platform namespace manifests..."

mkdir -p infra/platform-bootstrap/platform/namespaces
mkdir -p infra/platform-bootstrap/platform/applications

# platform-system
printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: platform-system' \
'  labels:' \
'    owner: platform' \
'    purpose: system' \
> infra/platform-bootstrap/platform/namespaces/platform-system.yaml

# team-payments-dev
printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: team-payments-dev' \
'  labels:' \
'    owner: payments' \
'    environment: dev' \
> infra/platform-bootstrap/platform/namespaces/team-payments-dev.yaml

# team-payments-prod
printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: team-payments-prod' \
'  labels:' \
'    owner: payments' \
'    environment: prod' \
> infra/platform-bootstrap/platform/namespaces/team-payments-prod.yaml

### -------- STEP 6: Argo CD Application --------
echo "[6/10] Creating Argo CD Application for namespaces..."

printf '%s\n' \
'apiVersion: argoproj.io/v1alpha1' \
'kind: Application' \
'metadata:' \
'  name: platform-namespaces' \
'  namespace: argocd' \
'spec:' \
'  project: platform' \
'  source:' \
'    repoURL: https://github.com/mehtachirag186/case-study-1-infra.git' \
'    targetRevision: main' \
'    path: infra/platform-bootstrap/platform/namespaces' \
'  destination:' \
'    server: https://kubernetes.default.svc' \
'    namespace: argocd' \
'  syncPolicy:' \
'    automated:' \
'      prune: true' \
'      selfHeal: true' \
'    syncOptions:' \
'      - CreateNamespace=true' \
> infra/platform-bootstrap/platform/applications/platform-namespaces-app.yaml

kubectl apply -f infra/platform-bootstrap/platform/applications/platform-namespaces-app.yaml

### -------- STEP 7: Wait for GitOps Sync --------
echo "[7/10] Waiting for GitOps to create namespaces..."
sleep 30

kubectl get applications -n argocd
kubectl get ns | grep -E 'platform-system|team-payments'

echo "================================================="
echo "BOOTSTRAP COMPLETE"
echo "You are now at:"
echo "Phase 7 – Day 5"
echo "Step 5.2 COMPLETE"
echo "READY FOR STEP 5.3 (RBAC)"
echo "================================================="
