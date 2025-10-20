output "backend_service_name" {
  description = "Backend Cloud Run service name"
  value       = google_cloud_run_v2_service.backend.name
}

output "backend_service_uri" {
  description = "Backend Cloud Run service URI"
  value       = google_cloud_run_v2_service.backend.uri
}

output "frontend_service_name" {
  description = "Frontend Cloud Run service name"
  value       = google_cloud_run_v2_service.frontend.name
}

output "frontend_service_uri" {
  description = "Frontend Cloud Run service URI"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "frontend_load_balancer_ip" {
  description = "Frontend Load Balancer IP address"
  value       = google_compute_forwarding_rule.frontend.ip_address
}

output "frontend_url" {
  description = "Frontend public URL"
  value       = "http://${google_compute_forwarding_rule.frontend.ip_address}"
}
