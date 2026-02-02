#!/bin/bash
set -e

echo "================================================="
echo "Case Study 1 Bootstrap"
echo "Target: Phase 7 – Day 6 (First Workload Onboarded)"
echo "================================================="

### -------- STEP 1: Foundation Infra --------
echo "[1/12] Creating foundation infrastructure..."
cd ~/case-study-1-infra/infra/foundation

terraform init
terraform apply -var-file="cs1.tfvars" -auto-approve

### -------- STEP 2: AKS Credentials --------
echo "[2/12] Fetching AKS credentials..."
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group) \
  --name $(terraform output -raw aks_name) \
  --overwrite-existing

### -------- STEP 3: Install Argo CD --------
echo "[3/12] Installing Argo CD..."

kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

cd ~/case-study-1-infra

### -------- STEP 4: Platform AppProject --------
echo "[4/12] Creating Platform AppProject..."

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

### -------- STEP 5: Namespaces via GitOps --------
echo "[5/12] Creating namespace manifests..."

mkdir -p infra/platform-bootstrap/platform/{namespaces,applications,rbac}

printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: platform-system' \
> infra/platform-bootstrap/platform/namespaces/platform-system.yaml

printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: team-payments-dev' \
> infra/platform-bootstrap/platform/namespaces/team-payments-dev.yaml

printf '%s\n' \
'apiVersion: v1' \
'kind: Namespace' \
'metadata:' \
'  name: team-payments-prod' \
> infra/platform-bootstrap/platform/namespaces/team-payments-prod.yaml

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

### -------- STEP 6: RBAC via GitOps --------
echo "[6/12] Creating RBAC manifests..."

printf '%s\n' \
'apiVersion: rbac.authorization.k8s.io/v1' \
'kind: Role' \
'metadata:' \
'  name: payments-dev-edit' \
'  namespace: team-payments-dev' \
'rules:' \
'- apiGroups: ["", "apps"]' \
'  resources: ["pods", "services", "deployments"]' \
'  verbs: ["get", "list", "watch", "create", "update", "delete"]' \
> infra/platform-bootstrap/platform/rbac/payments-dev-role.yaml

printf '%s\n' \
'apiVersion: rbac.authorization.k8s.io/v1' \
'kind: RoleBinding' \
'metadata:' \
'  name: payments-dev-binding' \
'  namespace: team-payments-dev' \
'subjects:' \
'- kind: Group' \
'  name: payments-devs' \
'roleRef:' \
'  kind: Role' \
'  name: payments-dev-edit' \
'  apiGroup: rbac.authorization.k8s.io' \
> infra/platform-bootstrap/platform/rbac/payments-dev-binding.yaml

printf '%s\n' \
'apiVersion: argoproj.io/v1alpha1' \
'kind: Application' \
'metadata:' \
'  name: platform-rbac' \
'  namespace: argocd' \
'spec:' \
'  project: platform' \
'  source:' \
'    repoURL: https://github.com/mehtachirag186/case-study-1-infra.git' \
'    targetRevision: main' \
'    path: infra/platform-bootstrap/platform/rbac' \
'  destination:' \
'    server: https://kubernetes.default.svc' \
'    namespace: argocd' \
'  syncPolicy:' \
'    automated:' \
'      prune: true' \
'      selfHeal: true' \
> infra/platform-bootstrap/platform/applications/platform-rbac-app.yaml

kubectl apply -f infra/platform-bootstrap/platform/applications/platform-rbac-app.yaml

### -------- STEP 7: Payments AppProject --------
echo "[7/12] Creating Payments AppProject..."

printf '%s\n' \
'apiVersion: argoproj.io/v1alpha1' \
'kind: AppProject' \
'metadata:' \
'  name: payments' \
'  namespace: argocd' \
'spec:' \
'  sourceRepos:' \
'    - https://github.com/mehtachirag186/case-study-1-infra.git' \
'  destinations:' \
'    - namespace: team-payments-dev' \
'      server: https://kubernetes.default.svc' \
> infra/platform-bootstrap/projects/payments-project.yaml

kubectl apply -f infra/platform-bootstrap/projects/payments-project.yaml

### -------- STEP 8: Payments Dev App --------
echo "[8/12] Deploying Payments DEV app..."

mkdir -p apps/payments/dev

printf '%s\n' \
'apiVersion: apps/v1' \
'kind: Deployment' \
'metadata:' \
'  name: payments-api' \
'  namespace: team-payments-dev' \
'spec:' \
'  replicas: 1' \
'  selector:' \
'    matchLabels:' \
'      app: payments-api' \
'  template:' \
'    metadata:' \
'      labels:' \
'        app: payments-api' \
'    spec:' \
'      containers:' \
'      - name: app' \
'        image: nginx:alpine' \
> apps/payments/dev/deployment.yaml

printf '%s\n' \
'apiVersion: argoproj.io/v1alpha1' \
'kind: Application' \
'metadata:' \
'  name: payments-dev' \
'  namespace: argocd' \
'spec:' \
'  project: payments' \
'  source:' \
'    repoURL: https://github.com/mehtachirag186/case-study-1-infra.git' \
'    targetRevision: main' \
'    path: apps/payments/dev' \
'  destination:' \
'    server: https://kubernetes.default.svc' \
'    namespace: team-payments-dev' \
'  syncPolicy:' \
'    automated:' \
'      prune: true' \
'      selfHeal: true' \
> apps/payments/dev/application.yaml

kubectl apply -f apps/payments/dev/application.yaml

echo "================================================="
echo "BOOTSTRAP COMPLETE"
echo "You are now at Phase 7 – Day 6"
echo "Payments DEV workload deployed via GitOps"
echo "================================================="
