output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "RDS database username"
  value       = aws_db_instance.postgres.username
}

output "db_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "s3_bucket_name" {
  description = "S3 bucket name for documents"
  value       = aws_s3_bucket.documents.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.documents.arn
}

output "ecr_gen_backend_repository_url" {
  description = "ECR repository URL for gen backend"
  value       = aws_ecr_repository.gen_backend.repository_url
}

output "ecr_gen_frontend_repository_url" {
  description = "ECR repository URL for gen frontend"
  value       = aws_ecr_repository.gen_frontend.repository_url
}

output "ecr_admin_backend_repository_url" {
  description = "ECR repository URL for adminbackend"
  value       = aws_ecr_repository.admin_backend.repository_url
}

output "ecr_admin_frontend_repository_url" {
  description = "ECR repository URL for admin frontend"
  value       = aws_ecr_repository.admin_frontend.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "Public subnet A ID"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "Public subnet B ID"
  value       = aws_subnet.public_b.id
}

output "private_subnet_a_id" {
  description = "Private subnet A ID"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "Private subnet B ID"
  value       = aws_subnet.private_b.id
}

output "cp_gen_secrets_arn" {
  description = "ARN of the combined Secrets Manager secret"
  value       = aws_secretsmanager_secret.cp_gen_secrets.arn
}

output "gen_alb_arn" {
  value = aws_lb.gen_alb.arn
}

output "gen_alb_dns_name" {
  description = "DNS name of the generator Application Load Balancer"
  value = aws_lb.gen_alb.dns_name
}

output "gen_backend_url" {
  description = "Generator Backend API URL"
  value       = "http://${aws_lb.gen_alb.dns_name}/api"
}

output "gen_frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_lb.gen_alb.dns_name}"
}

output "gen_alb_security_group" {
  description = "Security group for the generator Application Load Balancer"
  value       = aws_security_group.gen_alb.id
}