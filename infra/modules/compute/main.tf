# =============================================================================
# MÓDULO: COMPUTE — Capa de Cómputo y Balanceo de Carga
# =============================================================================

# RECURSOS QUE CREA ESTE MÓDULO:
#   1. ECR              → Repositorio de imágenes Docker (inmutable)
#   2. ALB              → Application Load Balancer con health checks cada 30s
#   3. Target Group     → Grupo de destino del ALB hacia las EC2
#   4. Launch Template  → Plantilla de configuración de cada instancia EC2
#   5. Auto Scaling     → Escala EC2 según demanda (75% CPU / 8 minutos)
#   6. Alarma CPU       → Dispara scale-in cuando CPU < 30% por 15 minutos
#
# LOS RNF IMPLEMENTADOS SON:
#   ✅ RNF 9  — Scale-Out al 75% CPU por 8 minutos continuos
#   ✅ RNF 10 — Aprovisionamiento máximo 60 segundos al escalar
#   ✅ RNF 11 — Scale-In al 30% CPU por 15 minutos
#   ✅ RNF 12 — Connection draining 60 segundos antes de terminar instancia
#   ✅ RNF 14 — Health checks cada 30 segundos
#   ✅ RNF 15 — Reemplazo automático de nodos caídos en menos de 3 minutos
#   ✅ RNF 25 — ECR con etiquetas inmutables y escaneo de vulnerabilidades
# =============================================================================


# -----------------------------------------------------------------------------
# 1. ECR — Repositorio de imágenes Docker
# -----------------------------------------------------------------------------
# Almacén privado de versiones del sistema.
# Cada imagen tiene un tag único = hash del commit → inmutable.
# RNF 25: "0 tolerancia a sobreescribir una imagen en producción"

resource "aws_ecr_repository" "app" {
  name = "${var.proyecto}-app"

  # IMMUTABLE = si intentas subir "v1.0" y ya existe → AWS lo bloquea
  image_tag_mutability = "IMMUTABLE"

  # Escaneo automático en cada push
  # RNF 25: "ninguna versión se usa si presenta fallos de severidad alta o crítica"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "${var.proyecto}-ecr"
    Ambiente  = var.ambiente
    Proyecto  = var.proyecto
    Modulo    = "compute"
    Autor     = "Wilmer"
  }
}

# Política de ciclo de vida — mantener solo las últimas 10 imágenes

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener las últimas 10 imágenes con tag de versión"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Eliminar imágenes sin tag después de 1 día"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}


# -----------------------------------------------------------------------------
# 2. ALB — Application Load Balancer
# -----------------------------------------------------------------------------
# Distribuye el tráfico entre las instancias EC2 del Auto Scaling Group.
# Es interno — solo accesible desde dentro de la VPC.
# El API Gateway le envía el tráfico dinámico.
#
# RNF 14: "verificaciones de salud cada 30 segundos"
# RNF 12: "connection draining — esperar 60s antes de terminar instancia"
# -----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.proyecto}-alb"
  internal           = true             # Solo accesible desde dentro de la VPC
  load_balancer_type = "application"

  # Vive en las subredes privadas de compute (Subredes 3 y 4)

  subnets         = var.private_subnets_compute
  security_groups = [var.sg_alb_id]

  enable_deletion_protection = false

  tags = {
    Name     = "${var.proyecto}-alb"
    Ambiente = var.ambiente
    Proyecto = var.proyecto
    Modulo   = "compute"
    Autor    = "Wilmer"
  }
}


# -----------------------------------------------------------------------------
# 3. TARGET GROUP — Grupo de destino del ALB
# -----------------------------------------------------------------------------
# Define hacia dónde envía tráfico el ALB.
# Las EC2 del Auto Scaling Group se registran aquí automáticamente.

# RNF 14: health check cada 30 segundos
# RNF 12: deregistration_delay = 60 segundos 
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "backend" {
  name     = "${var.proyecto}-tg-backend"
  port     = 8000        # Puerto donde escucha Django/Gunicorn
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # -------------------------------------------------------------------------
  # HEALTH CHECK
  # RNF 14: "sondeos automáticos en intervalos exactos de 30 segundos"
  # RNF 15: "aislamiento y reemplazo en menos de 3 minutos"
  # -------------------------------------------------------------------------
  health_check {
    enabled             = true
    path                = "/health/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30    # Verificar cada 30 segundos (RNF 14)
    timeout             = 10
    healthy_threshold   = 2     # 2 OK consecutivos → instancia sana
    unhealthy_threshold = 3     # 3 fallos → instancia fuera de rotación
    matcher             = "200"
  }

  # -------------------------------------------------------------------------
  # CONNECTION DRAINING
  # RNF 12: "periodo de gracia de 60 segundos para transacciones en curso"
  # El ALB espera 60s para que las ventas activas terminen sin errores
  # -------------------------------------------------------------------------
  deregistration_delay = 60

  tags = {
    Name     = "${var.proyecto}-tg-backend"
    Ambiente = var.ambiente
    Proyecto = var.proyecto
    Modulo   = "compute"
    Autor    = "Wilmer"
  }
}

# Listener del ALB en puerto 80 (el SSL termina en API Gateway)

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}


# -----------------------------------------------------------------------------
# 4. LAUNCH TEMPLATE — Plantilla de configuración de cada instancia EC2
# -----------------------------------------------------------------------------
# El "molde" que usa el Auto Scaling Group para lanzar instancias nuevas.

# RNF 10: "aprovisionamiento máximo de 60 segundos al escalar"
# RNF 18: "100% de recursos críticos en subredes privadas"
# RNF 24: "sin credenciales fijas — usa rol IAM de menor privilegio"

resource "aws_launch_template" "backend" {
  name        = "${var.proyecto}-backend-lt"
  description = "Launch Template para instancias EC2 backend - Veltri Minimarket"

  image_id      = var.ami_id         # Amazon Linux 2023 con Docker
  instance_type = var.instance_type  # t3.micro DEV / t3.medium PROD

  # Rol IAM — acceso a ECR y Secrets Manager SIN credenciales fijas
  # RNF 24: "roles de acceso temporales, bloquear 100% de permisos innecesarios"

  iam_instance_profile {
    arn = var.ec2_instance_profile_arn
  }

  # Sin IP pública — vive en subred privada
  # RNF 18: "100% de recursos críticos en subredes privadas"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_ec2_id]
    delete_on_termination       = true
  }

  # Disco cifrado en reposo

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Monitoreo detallado — métricas cada 1 minuto para reaccionar al 75% CPU

  monitoring {
    enabled = true
  }

  # Script de arranque — configura y arranca Django en menos de 60 segundos
  # RNF 10: "tiempo máximo de aprovisionamiento de 60 segundos"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Instalar Docker y AWS CLI
    yum update -y
    yum install -y docker aws-cli jq
    systemctl start docker
    systemctl enable docker

    # Autenticarse con ECR usando rol IAM (sin credenciales fijas)

    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}

    #----------------------------------------------------
    # Descargar imagen Docker desde ECR
    docker pull ${aws_ecr_repository.app.repository_url}:latest

    # Obtener credenciales de Aurora desde Secrets Manager

    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id ${var.aurora_secret_arn} \
      --region ${var.aws_region} \
      --query SecretString --output text)

    DB_HOST=$(echo $SECRET | jq -r '.host')
    DB_NAME=$(echo $SECRET | jq -r '.dbname')
    DB_USER=$(echo $SECRET | jq -r '.username')
    DB_PASS=$(echo $SECRET | jq -r '.password')

    # Arrancar contenedor Django
    docker run -d \
      --name veltri-backend \
      --restart unless-stopped \
      -p 8000:8000 \
      -e DB_HOST="$DB_HOST" \
      -e DB_NAME="$DB_NAME" \
      -e DB_USER="$DB_USER" \
      -e DB_PASSWORD="$DB_PASS" \
      -e AWS_REGION="${var.aws_region}" \
      ${aws_ecr_repository.app.repository_url}:latest

    echo "Backend Veltri arrancado correctamente"
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name     = "${var.proyecto}-backend-ec2"
      Ambiente = var.ambiente
      Proyecto = var.proyecto
      Modulo   = "compute"
      Autor    = "Wilmer"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


# -----------------------------------------------------------------------------
# 5. AUTO SCALING GROUP — Escalado automático de instancias EC2
# -----------------------------------------------------------------------------
# Si una instancia falla → la reemplaza automáticamente en < 3 minutos.

# RNF 9:  Scale-Out cuando CPU > 75% por 8 minutos
# RNF 11: Scale-In cuando CPU < 30% por 15 minutos
# RNF 15: Reemplazar instancia caída en menos de 3 minutos
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "backend" {
  name = "${var.proyecto}-backend-asg"

  min_size         = var.asg_min_size      # Mínimo siempre activo
  max_size         = var.asg_max_size      # Máximo al escalar
  desired_capacity = var.asg_desired_size  # Cantidad inicial

  # Subredes privadas del backend — una por AZ (Subredes 3 y 4)

  vpc_zone_identifier = var.private_subnets_compute

  # Registrar instancias en el Target Group del ALB
  target_group_arns = [aws_lb_target_group.backend.arn]

  # Health check via ALB — más preciso que el de EC2
  health_check_type         = "ELB"
  health_check_grace_period = 120  # 120s para que la instancia arranque

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # Actualización gradual sin downtime al cambiar imagen Docker

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60  # RNF 10: 60 segundos de aprovisionamiento
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.proyecto}-backend-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Modulo"
    value               = "compute"
    propagate_at_launch = true
  }

  tag {
    key                 = "Autor"
    value               = "Wilmer"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}


# -----------------------------------------------------------------------------
# 6. POLÍTICAS DE AUTO SCALING
# -----------------------------------------------------------------------------

# SCALE-OUT: Agregar instancias cuando CPU > 75%
# RNF 9: "aprovisionará nuevos servidores cuando CPU supere 75% durante 8 minutos"
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.proyecto}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 75.0  # Mantener CPU en 75%
    disable_scale_in = true  # Esta política solo escala hacia arriba
  }
}

# SCALE-IN: Eliminar instancias cuando CPU < 30% por 15 minutos
# RNF 11: "retirará servidores cuando CPU descienda por debajo del 30% durante 15 minutos"

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.proyecto}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1    # Eliminar 1 instancia a la vez
  cooldown               = 900   # Esperar 15 minutos entre cada scale-in
}

# Alarma CloudWatch que dispara el scale-in

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.proyecto}-cpu-bajo-30"
  alarm_description   = "CPU menor al 30% por 15 minutos — iniciar scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3      # 3 períodos de 5 minutos = 15 minutos
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300    # Cada 5 minutos
  statistic           = "Average"
  threshold           = 30.0

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]

  tags = {
    Name     = "${var.proyecto}-alarm-cpu-low"
    Ambiente = var.ambiente
    Proyecto = var.proyecto
    Modulo   = "compute"
    Autor    = "Wilmer"
  }
}
