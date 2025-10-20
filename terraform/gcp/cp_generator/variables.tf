variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "compliance-procedure"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "llm_base_url" {
  description = "LLM Base URL"
  type        = string
  default     = "https://api.openai.com/v1"
}

# Infrastructure resource identifiers (from infrastructure module outputs)
variable "vpc_connector_name" {
  description = "VPC Access Connector name"
  type        = string
}

variable "sql_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "storage_bucket_name" {
  description = "Cloud Storage bucket name"
  type        = string
}

variable "secret_manager_secret_id" {
  description = "Secret Manager secret ID"
  type        = string
}

variable "gen_backend_registry_name" {
  description = "Artifact Registry name for generator backend"
  type        = string
}

variable "gen_frontend_registry_name" {
  description = "Artifact Registry name for generator frontend"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Cloud Run (just the account ID part)"
  type        = string
}
