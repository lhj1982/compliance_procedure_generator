variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_connector_id" {
  description = "VPC Access Connector ID"
  type        = string
}

variable "db_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_private_ip" {
  description = "Cloud SQL private IP address"
  type        = string
}

variable "frontend_image" {
  description = "Docker image for frontend"
  type        = string
  default     = "gcr.io/PROJECT_ID/compliance-frontend:latest"
}

variable "backend_image" {
  description = "Docker image for backend"
  type        = string
  default     = "gcr.io/PROJECT_ID/compliance-backend:latest"
}

variable "admin_image" {
  description = "Docker image for admin"
  type        = string
  default     = "gcr.io/PROJECT_ID/compliance-admin:latest"
}

variable "llm_base_url" {
  description = "LLM Base URL"
  type        = string
  default     = "https://api.openai.com/v1"
}
#variable "llm_api_key" {
#  description = "LLM API key for backend"
#  type        = string
#  sensitive   = true
#}

variable "bastion_allowed_ips" {
  description = "List of IP addresses allowed to access bastion"
  type        = list(string)
  default     = []
}

variable "public_subnet_name" {
  description = "Public subnet name for bastion"
  type        = string
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "app_secrets_id" {
  description = "Secret Manager secret ID containing application secrets (JSON with llm_api_key and db_password)"
  type        = string
}

variable "documents_bucket_name" {
  description = "Cloud Storage bucket name for documents"
  type        = string
}
