variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "compliance-procedure"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro" # Smallest/cheapest tier
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "compliance_db"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "compliance_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "llm_api_key" {
  description = "LLM API key for backend"
  type        = string
  sensitive   = true
  default     = ""
}

variable "service_account_email" {
  description = "Email of the Cloud Run service account"
  type        = string
}
