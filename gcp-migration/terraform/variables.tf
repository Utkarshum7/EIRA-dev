variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "artifact_repo" {
  type        = string
  description = "Artifact Registry repository ID"
  default     = "eira-images"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary CIDR for the subnet"
  default     = "10.10.0.0/24"
}

variable "pods_cidr" {
  type        = string
  description = "Secondary range for pods"
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  type        = string
  description = "Secondary range for services"
  default     = "10.30.0.0/20"
}

variable "sql_tier" {
  type        = string
  description = "Cloud SQL machine tier"
  default     = "db-custom-1-3840"
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "eiradb"
}

variable "db_user" {
  type        = string
  description = "Database user"
  default     = "eira"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}


