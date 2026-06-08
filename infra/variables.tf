variable "aws_region" {
  description = "Región de AWS donde se desplegarán todos los recursos"
  type        = string
  default     = "eu-east-1"
}

variable "ambiente" {
  description = "Ambiente de despliegue de la infraestructura"
  type        = string
  default     = "produccion"
}

variable "proyecto" {
  description = "Nombre del proyecto para organizar los recursos en AWS"
  type        = string
  default     = "veltri-minimarket"
}