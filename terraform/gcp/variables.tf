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
  default     = "compliance-procedure-gen"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "llm_api_key" {
  description = "LLM API Key (OpenAI or compatible)"
  type        = string
  sensitive   = true
}

variable "llm_base_url" {
  description = "LLM Base URL"
  type        = string
  default     = "https://api.openai.com/v1"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
