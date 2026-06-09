output "aurora_endpoint" {
  description = "Punto de enlace principal de la base de datos Aurora"
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "redis_endpoint" {
  description = "Punto de enlace del clúster de ElastiCache"
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}

output "db_secret_arn" {
  description = "ARN del secreto en Secrets Manager para las credenciales"
  value       = aws_secretsmanager_secret.db_secret.arn
}

output "app_iam_role_name" {
  description = "Nombre del rol IAM para los servidores EC2"
  value       = aws_iam_role.app_execution_role.name
}