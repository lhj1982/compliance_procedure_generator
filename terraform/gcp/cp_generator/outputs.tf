# Backend Service Outputs
output "backend_service_name" {
  description = "Name of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.name
}

output "backend_service_uri" {
  description = "URI of the backend Cloud Run service (internal)"
  value       = google_cloud_run_v2_service.backend.uri
  sensitive   = true
}

# Frontend Service Outputs
output "frontend_service_name" {
  description = "Name of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.name
}

output "frontend_service_uri" {
  description = "URI of the frontend Cloud Run service (public)"
  value       = google_cloud_run_v2_service.frontend.uri
}

# Bastion Outputs
output "bastion_instance_name" {
  description = "Name of the bastion instance"
  value       = google_compute_instance.bastion.name
}

output "bastion_instance_zone" {
  description = "Zone where the bastion instance is deployed"
  value       = google_compute_instance.bastion.zone
}

output "connect_to_bastion" {
  description = "Command to connect to bastion instance via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${google_compute_instance.bastion.zone} --tunnel-through-iap"
}
