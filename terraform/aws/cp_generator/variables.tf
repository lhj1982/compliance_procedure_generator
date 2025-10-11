variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "vpc_id" {
  description = "Existing VPC ID to use"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs"
  type        = list(string)
}

variable "llm_base_url" {
  description = "LLM Base URL"
  type        = string
  default     = "https://api.openai.com/v1"
}

# Infrastructure resource identifiers (from infrastructure module outputs)
variable "db_instance_identifier" {
  description = "RDS database instance identifier"
  type        = string
}

variable "db_security_group_id" {
  description = "RDS security group ID"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for documents"
  type        = string
}

variable "secret_manager_name" {
  description = "Name of the Secrets Manager"
  type        = string
}

variable "ecr_backend_repository_name" {
  description = "ECR backend repository name"
  type        = string
}

variable "ecr_frontend_repository_name" {
  description = "ECR frontend repository name"
  type        = string
}

variable "gen_alb_dns_name" {
  description = "ALB ID for the cp-gen application"
  type        = string
}
variable "gen_alb_arn" {
  description = "ALB ARN for the cp-gen application"
  type        = string
}
variable "gen_alb_security_group" {
  description = "ALB Security Group for the cp-gen application"
  type        = string
}