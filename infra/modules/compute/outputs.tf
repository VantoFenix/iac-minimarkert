# =============================================================================
# OUTPUTS: Módulo Compute
# =============================================================================

# URL del ECR — GitHub Actions hace docker push aquí

output "ecr_repository_url" {
  description = "URL del repositorio ECR. Configurar en GitHub Actions secrets."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN del repositorio ECR. Necesario para políticas IAM."
  value       = aws_ecr_repository.app.arn
}

# DNS del ALB — el API Gateway reenvía tráfico aquí
output "alb_dns_name" {
  description = "DNS del ALB. El API Gateway usa este valor para reenviar tráfico dinámico al backend."
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del ALB."
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN del Target Group. Las EC2 se registran aquí automáticamente."
  value       = aws_lb_target_group.backend.arn
}

# Nombre del ASG — pipeline CI/CD lo usa para hacer instance refresh

output "asg_name" {
  description = "Nombre del Auto Scaling Group. El pipeline CI/CD actualiza instancias con nueva imagen Docker."
  value       = aws_autoscaling_group.backend.name
}

output "launch_template_id" {
  description = "ID del Launch Template del backend."
  value       = aws_launch_template.backend.id
}
