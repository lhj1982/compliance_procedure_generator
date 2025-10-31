terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Configure backend for state storage
  # Uncomment and configure for production use
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "compliance-procedure"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Infrastructure module
module "infrastructure" {
  source = "./infrastructure"

  project_id  = var.project_id
  region      = var.region
  app_name    = var.app_name
  environment = var.environment
  db_tier     = var.db_tier
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  vpc_cidr    = var.vpc_cidr
  llm_api_key = var.llm_api_key
}

# Compliance Procedure Generator module
module "cp_generator" {
  source = "./cp_generator"

  project_id              = var.project_id
  region                  = var.region
  app_name                = var.app_name
  environment             = var.environment
  vpc_connector_id      = module.infrastructure.vpc_connector_id
  db_connection_name    = module.infrastructure.db_connection_name
  db_name               = module.infrastructure.db_name
  db_user               = var.db_user
  db_password           = var.db_password
  db_private_ip         = module.infrastructure.db_private_ip
  frontend_image        = var.frontend_image
  backend_image         = var.backend_image
  admin_image           = var.admin_image
  llm_api_key           = var.llm_api_key
  public_subnet_name    = module.infrastructure.public_subnet_id
  vpc_name              = module.infrastructure.vpc_name
  app_secrets_id        = module.infrastructure.app_secrets_id
  documents_bucket_name = module.infrastructure.documents_bucket_name

  depends_on = [module.infrastructure]
}
