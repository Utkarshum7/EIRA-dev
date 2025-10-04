Terraform for EIRA (GCP)

This module provisions:
- VPC and subnet with secondary ranges for GKE
- Artifact Registry (Docker)
- GKE Autopilot cluster with Workload Identity
- Cloud SQL (Postgres) with private IP

Usage
1. Copy variables file:
   cp terraform.tfvars.example terraform.tfvars
2. Edit values (project_id, db_password, etc.)
3. Initialize and apply:
   terraform init
   terraform apply -var-file=terraform.tfvars

Outputs
- gke_cluster_name
- artifact_registry_url
- cloudsql_connection_name
- network_names

Next steps
- Configure kubectl to connect to GKE:
  gcloud container clusters get-credentials eira-autopilot --region <REGION> --project <GCP_PROJECT_ID>
- Apply Kubernetes manifests under ../k8s


