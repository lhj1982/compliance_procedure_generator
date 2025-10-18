variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "app_name" {
  description = "Application name for tagging resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "db_password" {
  description = "Database password for RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "llm_api_key" {
  description = "API key for LLM"
  type        = string
  sensitive   = true
}
