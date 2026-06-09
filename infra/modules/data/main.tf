# 1. GESTIÓN DE SECRETOS (AWS Secrets Manager)
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name        = "veltri-db-credentials-${var.environment}"
  description = "Credenciales para la base de datos Aurora"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
  })
}

# GRUPOS DE SEGURIDAD Y SUBREDES
resource "aws_db_subnet_group" "data_subnet_group" {
  name       = "veltri-data-subnets"
  subnet_ids = var.private_subnets_data
}

resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name       = "veltri-cache-subnets"
  subnet_ids = var.private_subnets_data
}

resource "aws_security_group" "data_sg" {
  name        = "veltri-data-sg"
  description = "Reglas de firewall para DB y Cache"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# 2. BASE DE DATOS (Amazon Aurora Multi-AZ)
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "veltri-aurora-cluster"
  engine                  = "aurora-mysql"
  database_name           = "veltriminimarket"
  master_username         = "admin"
  master_password         = random_password.db_password.result
  db_subnet_group_name    = aws_db_subnet_group.data_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.data_sg.id]
  skip_final_snapshot     = true
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 2
  identifier         = "veltri-aurora-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.aurora_cluster.engine
}

# 3. CACHÉ EN MEMORIA (Amazon ElastiCache)
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id          = "veltri-redis"
  description                   = "Persistencia independiente de sesiones"
  node_type                     = "cache.t3.micro"
  port                          = 6379
  subnet_group_name             = aws_elasticache_subnet_group.cache_subnet_group.name
  security_group_ids            = [aws_security_group.data_sg.id]
  automatic_failover_enabled    = true
  num_cache_clusters            = 2
}

# 4. ROLES DE ACCESO (AWS IAM)
resource "aws_iam_role" "app_execution_role" {
  name = "veltri_app_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.app_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}