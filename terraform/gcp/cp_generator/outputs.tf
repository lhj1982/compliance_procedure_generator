output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_address.default.address
}

output "frontend_url" {
  description = "Cloud Run frontend service URL"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "backend_url" {
  description = "Cloud Run backend service URL"
  value       = google_cloud_run_v2_service.backend.uri
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
