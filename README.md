EIRA-project

This repository is a scaffold to orchestrate the EIRA frontend and backend, run locally with Docker Compose, and deploy to Google Cloud via Terraform and Kubernetes.

Referenced repos:
- Frontend (Flutter Web): https://github.com/BOCK-HEALTH/EiraUIFlutter.git
- Backend (Node/Dart + Postgres): https://github.com/BOCK-HEALTH/EiraFlutterBackend.git

Directory layout
- eira-frontend/                      Dockerfile, .dockerignore for frontend image
- eira-backend/                       Dockerfile, .dockerignore for backend image
- eira-test/                          Local compose for frontend+backend+postgres
  - docker-compose.yml
  - .env.example
- gcp-migration/
  - terraform/                        VPC, Artifact Registry, GKE Autopilot, Cloud SQL
    - main.tf
    - variables.tf
    - outputs.tf
    - terraform.tfvars.example
    - README.md
  - k8s/                              Kubernetes manifests
    - namespace.yaml
    - config/frontend-configmap.yaml
    - config/backend-configmap.yaml
    - secrets/postgres-secret.yaml
    - backend-deployment.yaml
    - backend-service.yaml
    - frontend-deployment.yaml
    - frontend-service.yaml
    - ingress.yaml
    - kustomization.yaml (optional)

Prerequisites
- Docker and Docker Compose
- Terraform >= 1.6
- gcloud CLI, kubectl
- A Google Cloud project with billing enabled

Quick start (local)
1. Copy environment example and adjust values:
   cp eira-test/.env.example eira-test/.env
2. Build and run all services:
   docker compose --project-name eira -f eira-test/docker-compose.yml up --build
3. Access:
   - Frontend: http://localhost:8081
   - Backend API: http://localhost:8080 (or via frontend at /api)

Build & push images (GCP Artifact Registry)
1. Authenticate Docker to Artifact Registry:
   gcloud auth configure-docker <REGION>-docker.pkg.dev
2. Build and tag images:
   docker build -t <REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REPO>/frontend:latest ./eira-frontend
   docker build -t <REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REPO>/backend:latest ./eira-backend
3. Push:
   docker push <REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REPO>/frontend:latest
   docker push <REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REPO>/backend:latest

Terraform (GCP)
1. cd gcp-migration/terraform
2. Copy and edit variables:
   cp terraform.tfvars.example terraform.tfvars
3. Init and apply:
   terraform init
   terraform apply -var-file=terraform.tfvars

Kubernetes deploy
1. Ensure kubectl is pointed to the created GKE cluster (see terraform outputs)
2. Apply manifests:
   kubectl apply -f gcp-migration/k8s/namespace.yaml
   kubectl apply -n eira -f gcp-migration/k8s/
3. Get the external IP of the frontend service:
   kubectl get svc -n eira frontend-service

DNS (MilesWeb)
- Create an A record for your domain (e.g. www.eiradev.com) pointing to the external IP of `frontend-service`.

Security notes
- Do not commit any real secrets. Use Kubernetes Secrets, Secret Manager, or CI/CD secrets.
- Use Workload Identity to access Cloud SQL from GKE.

Sources
- Frontend repo: https://github.com/BOCK-HEALTH/EiraUIFlutter.git
- Backend repo: https://github.com/BOCK-HEALTH/EiraFlutterBackend.git


