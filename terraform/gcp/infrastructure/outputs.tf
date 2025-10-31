output "vpc_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = google_compute_subnetwork.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = google_compute_subnetwork.private.id
}

output "vpc_connector_id" {
  description = "VPC Access Connector ID"
  value       = google_vpc_access_connector.connector.id
}

output "vpc_connector_name" {
  description = "VPC Access Connector name"
  value       = google_vpc_access_connector.connector.name
}

output "db_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "db_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
}

output "db_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

# Artifact Registry outputs
output "gen_backend_repository" {
  description = "Generator backend Artifact Registry repository"
  value       = google_artifact_registry_repository.gen_backend.name
}

output "gen_frontend_repository" {
  description = "Generator frontend Artifact Registry repository"
  value       = google_artifact_registry_repository.gen_frontend.name
}

output "admin_backend_repository" {
  description = "Admin backend Artifact Registry repository"
  value       = google_artifact_registry_repository.admin_backend.name
}

output "admin_frontend_repository" {
  description = "Admin frontend Artifact Registry repository"
  value       = google_artifact_registry_repository.admin_frontend.name
}

# Storage outputs
output "documents_bucket_name" {
  description = "Cloud Storage bucket for documents"
  value       = google_storage_bucket.documents.name
}

output "documents_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.documents.url
}

# Secret Manager outputs
output "cp_gen_secrets_id" {
  description = "Combined secrets Secret Manager ID"
  value       = google_secret_manager_secret.cp_gen_secrets.secret_id
}

output "llm_api_key_secret_id" {
  description = "LLM API Key Secret Manager ID"
  value       = google_secret_manager_secret.llm_api_key.secret_id
}

output "db_password_secret_id" {
  description = "DB Password Secret Manager ID"
  value       = google_secret_manager_secret.db_password.secret_id
}
