variable "vpc_id" {
  description = "ID de la VPC principal"
  type        = string
}

variable "private_subnets_data" {
  description = "Subredes privadas 5 y 6 para aislar la base de datos"
  type        = list(string)
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "prod"
}