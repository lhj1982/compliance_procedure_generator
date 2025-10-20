output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "vpc_network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "public_subnet_name" {
  description = "Public subnet name"
  value       = google_compute_subnetwork.public.name
}

output "private_subnet_name" {
  description = "Private subnet name"
  value       = google_compute_subnetwork.private.name
}

output "vpc_connector_name" {
  description = "VPC Access Connector name"
  value       = google_vpc_access_connector.connector.name
}

output "sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.postgres.name
}

output "sql_instance_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.compliance_admin.name
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket name"
  value       = google_storage_bucket.documents.name
}

output "storage_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.documents.url
}

output "secret_manager_secret_id" {
  description = "Secret Manager secret ID"
  value       = google_secret_manager_secret.cp_gen_secrets.secret_id
}

output "gen_backend_registry" {
  description = "Artifact Registry for generator backend"
  value       = google_artifact_registry_repository.gen_backend.id
}

output "gen_frontend_registry" {
  description = "Artifact Registry for generator frontend"
  value       = google_artifact_registry_repository.gen_frontend.id
}

output "admin_backend_registry" {
  description = "Artifact Registry for admin backend"
  value       = google_artifact_registry_repository.admin_backend.id
}

output "admin_frontend_registry" {
  description = "Artifact Registry for admin frontend"
  value       = google_artifact_registry_repository.admin_frontend.id
}

output "service_account_email" {
  description = "Service account email for Cloud Run"
  value       = google_service_account.cloud_run.email
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}
