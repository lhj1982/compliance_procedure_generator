output "frontend_url" {
  description = "Public URL for the frontend service (use this to access the application)"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "backend_url" {
  description = "Internal backend service URL (only accessible from GCP Cloud Run services and bastion)"
  value       = google_cloud_run_v2_service.backend.uri
}

output "config_update_command" {
  description = "Command to update frontend config.js with backend URL"
  value       = <<-EOT
    # Update config.js with backend URL before building frontend image:
    sed -i.bak 's|BACKEND_URL_PLACEHOLDER|${google_cloud_run_v2_service.backend.uri}|g' ../../frontend/static/config.js

    # Or manually update frontend/static/config.js:
    # Change: BACKEND_URL: "BACKEND_URL_PLACEHOLDER"
    # To:     BACKEND_URL: "${google_cloud_run_v2_service.backend.uri}"
  EOT
}

output "bastion_instance_name" {
  description = "Bastion host instance name"
  value       = google_compute_instance.bastion.name
}

output "bastion_zone" {
  description = "Bastion host zone"
  value       = google_compute_instance.bastion.zone
}

output "bastion_ssh_command" {
  description = "Command to SSH into bastion via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${google_compute_instance.bastion.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "db_proxy_command" {
  description = "Command to start Cloud SQL proxy on bastion"
  value       = "cloud_sql_proxy -instances=${var.db_connection_name}=tcp:5432"
}

output "test_backend_command" {
  description = "Command to test backend from bastion (run this after SSHing to bastion)"
  value       = "curl ${google_cloud_run_v2_service.backend.uri}/health"
}
