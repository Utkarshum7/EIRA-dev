#!/usr/bin/env bash
set -euo pipefail

# ===== Configurable variables =====
PROJECT_ID="project-eira"
REGION="us-central1"
CLUSTER_NAME="eira-autopilot"
AR_LOCATION="us-central1"
AR_REPO="eira-images"
BACKEND_IMAGE="us-central1-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/backend:latest"
FRONTEND_IMAGE="us-central1-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/frontend:latest"
BACKEND_URL="http://backend-service.eira.svc.cluster.local:8080"

# ===== Step 1 & 2: Confirm environment and project structure =====
echo "Environment check:"
uname -a || true
echo "Shell: ${SHELL:-unknown}"
echo "CWD: $(pwd)"
echo "Ensuring we're in ~/projects/eira-dev ..."
cd "${HOME}/projects/eira-dev"

echo "Validating required directories..."
for d in eira-backend eira-frontend gcp-migration/terraform gcp-migration/k8s; do
  [[ -d "$d" ]] || { echo "Missing required directory: $d"; exit 1; }
done
echo "Directory validation OK."

# ===== Step 3: Configure GCP =====
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not installed in WSL. Install the Google Cloud SDK and re-run."; exit 1
fi

echo "Setting gcloud project to ${PROJECT_ID} ..."
gcloud config set project "${PROJECT_ID}"

echo "Enabling required APIs (idempotent)..."
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com

# ===== Step 4: Terraform setup =====
echo "Running Terraform..."
cd gcp-migration/terraform
[[ -f main.tf && -f variables.tf && -f outputs.tf && -f terraform.tfvars ]] || { echo "Missing Terraform files. Ensure main.tf, variables.tf, outputs.tf, terraform.tfvars exist."; exit 1; }
terraform init
terraform apply -auto-approve -var-file="terraform.tfvars"

cd - >/dev/null

# ===== Step 5: Kubernetes setup =====
echo "Fetching GKE credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${REGION}" --project "${PROJECT_ID}"

echo "Applying Kubernetes manifests..."
kubectl apply -f gcp-migration/k8s/namespace.yaml
kubectl apply -n eira -f gcp-migration/k8s/config/
kubectl apply -n eira -f gcp-migration/k8s/secrets/
kubectl apply -n eira -f gcp-migration/k8s/backend-deployment.yaml
kubectl apply -n eira -f gcp-migration/k8s/frontend-deployment.yaml
kubectl apply -n eira -f gcp-migration/k8s/ingress.yaml

# ===== Step 6: Docker & Artifact Registry =====
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found in WSL. Ensure Docker Engine/daemon is accessible (Docker Desktop w/ WSL integration)."; exit 1
fi

echo "Configuring Docker auth for Artifact Registry..."
gcloud auth configure-docker "${AR_LOCATION}-docker.pkg.dev" --quiet

echo "Building and pushing backend image..."
docker build -t "${BACKEND_IMAGE}" ./eira-backend
docker push "${BACKEND_IMAGE}"

echo "Building and pushing frontend image..."
docker build -t "${FRONTEND_IMAGE}" ./eira-frontend
docker push "${FRONTEND_IMAGE}"

# ===== Step 7: Flutter frontend build =====
if command -v flutter >/dev/null 2>&1; then
  echo "Building Flutter web frontend..."
  cd eira-frontend
  flutter pub get
  flutter build web --release --dart-define=BACKEND_URL="${BACKEND_URL}"
  cd - >/dev/null
else
  echo "Flutter not installed. Skipping Flutter build. Install Flutter and re-run this section."
fi

# ===== Step 8: Verify deployment =====
echo "Waiting for pods to become Ready in namespace eira..."
kubectl wait --for=condition=available --timeout=120s deployment --all -n eira || true
kubectl get pods -n eira -o wide

echo "Checking services and ingress..."
kubectl get svc -n eira
kubectl get ingress -n eira
echo "If Ingress shows <pending>, wait a few minutes and re-check: kubectl get ingress -n eira"

echo "All steps executed. Review outputs above for endpoints and statuses."
