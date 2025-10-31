output "load_balancer_ip" {
  description = "External IP address of the load balancer - use this to access the application"
  value       = module.cp_generator.load_balancer_ip
}

output "application_url" {
  description = "Application URL"
  value       = "http://${module.cp_generator.load_balancer_ip}"
}

output "frontend_cloud_run_url" {
  description = "Cloud Run frontend service URL (internal)"
  value       = module.cp_generator.frontend_url
}

output "backend_cloud_run_url" {
  description = "Cloud Run backend service URL (internal)"
  value       = module.cp_generator.backend_url
}

output "admin_cloud_run_url" {
  description = "Cloud Run admin service URL (internal)"
  value       = module.cp_generator.admin_url
}

output "bastion_ssh_command" {
  description = "Command to SSH into bastion host"
  value       = module.cp_generator.bastion_ssh_command
}

output "db_connection_info" {
  description = "Database connection information"
  value = {
    instance_name     = module.infrastructure.db_instance_name
    connection_name   = module.infrastructure.db_connection_name
    database_name     = module.infrastructure.db_name
    private_ip        = module.infrastructure.db_private_ip
  }
  sensitive = true
}
