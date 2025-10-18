output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_backend_service_name" {
  description = "ECS backend service name"
  value       = aws_ecs_service.backend.name
}

output "ecs_frontend_service_name" {
  description = "ECS frontend service name"
  value       = aws_ecs_service.frontend.name
}
