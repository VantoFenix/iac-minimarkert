# =============================================================================
# VARIABLES: Módulo Compute
# =============================================================================

# Variables base — igual que el resto del equipo

variable "proyecto" {
  description = "Nombre del proyecto. Viene de infra/variables.tf"
  type        = string
}

variable "ambiente" {
  description = "Ambiente de despliegue (produccion/dev). Viene de infra/variables.tf"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde se despliega."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Variables de red — vienen del módulo network 
# En infra/main.tf pasará: module.network.vpc_id, etc.
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID de la VPC principal. Viene de module.network.vpc_id"
  type        = string
}

variable "private_subnets_compute" {
  description = "IDs de las subredes privadas de compute (Subredes 3 y 4). Viene de module.network.private_subnets_compute"
  type        = list(string)
}

variable "sg_alb_id" {
  description = "ID del Security Group del ALB. Viene del módulo network."
  type        = string
}

variable "sg_ec2_id" {
  description = "ID del Security Group de EC2. Viene del módulo network."
  type        = string
}

# -----------------------------------------------------------------------------
# Variables del módulo data 
# -----------------------------------------------------------------------------

variable "ec2_instance_profile_arn" {
  description = "ARN del Instance Profile IAM para EC2. Viene de module.data"
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN del secreto de Aurora en Secrets Manager. Viene de module.data"
  type        = string
}

# -----------------------------------------------------------------------------
# Variables de configuración EC2
# -----------------------------------------------------------------------------

variable "ami_id" {
  description = "AMI de Amazon Linux 2023 con Docker. Cambiar según la región."
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 — us-east-1
}

variable "instance_type" {
  description = "Tipo de instancia EC2. t3.micro en DEV, t3.medium en PROD."
  type        = string
  default     = "t3.micro"
}

# -----------------------------------------------------------------------------
# Variables del Auto Scaling Group
# -----------------------------------------------------------------------------

variable "asg_min_size" {
  description = "Mínimo de instancias siempre corriendo."
  type        = number
  default     = 2  # 2 para alta disponibilidad (una por AZ)
}

variable "asg_max_size" {
  description = "Máximo de instancias permitidas al escalar."
  type        = number
  default     = 6
}

variable "asg_desired_size" {
  description = "Cantidad inicial de instancias."
  type        = number
  default     = 2
}
